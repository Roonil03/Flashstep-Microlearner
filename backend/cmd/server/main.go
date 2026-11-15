package main

import (
	"context"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	v1 "backend/api/v1"
	"backend/internal/config"
	"backend/internal/db"
	"backend/internal/handlers"
	"backend/internal/maintenance"
	"backend/internal/middleware"
	"backend/internal/repositories"
	"backend/internal/services"
)

func main() {
	cfg := config.Load()
	conn, err := db.Connect(cfg)
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()
	schemaCtx, cancelSchema := context.WithTimeout(context.Background(), 5*time.Second)
	err = db.CheckSchema(schemaCtx, conn)
	cancelSchema()
	if err != nil {
		log.Fatal(err)
	}
	maintenance.StartDeletedUserCleanup(conn)
	maintenance.StartBugReportCleanup(conn)
	maintenance.StartAnalyticsAggregation(conn)
	userRepo := repositories.NewUserRepository(conn)
	authService := services.NewAuthService(userRepo, cfg.JWTSecret, time.Duration(cfg.JWTExpiryMinute)*time.Minute)
	authHandler := handlers.NewAuthHandler(authService)
	analyticsRepo := repositories.NewAnalyticsRepository(conn)
	analyticsService := services.NewAnalyticsService(analyticsRepo)
	analyticsHandler := handlers.NewAnalyticsHandler(analyticsService)
	userService := services.NewUserService(userRepo)
	userHandler := handlers.NewUserHandler(userService)
	reportHandler := handlers.NewBugReportHandler(conn)
	// router := gin.Default()
	router := gin.New()
	router.Use(middleware.Recovery(), middleware.RequestLimits())
	router.HandleMethodNotAllowed = true
	router.NoRoute(func(c *gin.Context) {
		c.JSON(http.StatusNotFound, gin.H{"error": "The requested endpoint could not be found."})
	})
	router.NoMethod(func(c *gin.Context) {
		c.JSON(http.StatusMethodNotAllowed, gin.H{"error": "This endpoint does not support that request method."})
	})
	if err := router.SetTrustedProxies(cfg.TrustedProxies); err != nil {
		log.Fatal(err)
	}
	router.GET("/health", func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
		defer cancel()
		if err := conn.PingContext(ctx); err != nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"status": "unavailable"})
			return
		}
		c.JSON(200, gin.H{"status": "ok"})
	})
	api := router.Group("/api/v1")
	api.Use(middleware.RateLimit(6000, time.Minute))
	{
		authLimit := middleware.RateLimit(120, time.Minute)
		api.POST("/auth/register", authLimit, authHandler.Register)
		api.POST("/auth/login", authLimit, authHandler.Login)
		protected := api.Group("")
		protected.Use(middleware.Auth(cfg.JWTSecret))
		protected.Use(middleware.RateLimit(1200, time.Minute))
		protected.Use(middleware.RequireActiveUser(conn))
		protected.GET("/me", authHandler.Me)
		protected.POST("/bug-reports", reportHandler.Create)
		{
			protected.POST("/decks", v1.CreateDeck)
			protected.GET("/decks", v1.GetDecks)
			protected.GET("/decks/public", v1.GetPublicDecks)
			protected.POST("/decks/:id/download", v1.DownloadPublicDeck)
			protected.PUT("/decks/:id", v1.UpdateDeck)
			protected.DELETE("/decks/:id", v1.DeleteDeck)

			protected.POST("/cards", v1.CreateCard)
			protected.GET("/decks/:deck_id/cards", v1.GetDeckCards)
			protected.PUT("/cards/:id", v1.UpdateCard)
			protected.DELETE("/cards/:id", v1.DeleteCard)

			protected.POST("/sync/upload", v1.SyncUpload)
			protected.GET("/sync/download", v1.SyncDownload)
			protected.GET("/sync/manifest", v1.SyncManifest)
			protected.GET("/sync/reviews", v1.SyncReviews)
			protected.GET("/sync/purged", v1.SyncPurged)
			protected.POST("/sync/fetch", v1.SyncFetch)
		}
		{
			protected.GET("/analytics/daily-review-count", analyticsHandler.DailyReviewCount)
			protected.GET("/analytics/average-session-length", analyticsHandler.AverageSessionLength)
			protected.GET("/analytics/accuracy-trends", analyticsHandler.AccuracyTrends)
			protected.GET("/analytics/deck-performance", analyticsHandler.DeckPerformance)
			protected.GET("/analytics/dashboard", analyticsHandler.Dashboard)
		}
		{
			protected.PUT("/auth/change-password", userHandler.ChangePassword)
			protected.PUT("/auth/change-username", authHandler.UpdateUsername)
			protected.DELETE("/auth/delete-account", userHandler.DeleteAccount)
		}
	}
	log.Printf("server listening on :%s", cfg.Port)
	server := &http.Server{
		Addr: ":" + cfg.Port, Handler: router,
		ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 30 * time.Second,
		WriteTimeout: 35 * time.Second, IdleTimeout: 60 * time.Second,
		MaxHeaderBytes: 16 << 10,
	}
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal(err)
	}
}
