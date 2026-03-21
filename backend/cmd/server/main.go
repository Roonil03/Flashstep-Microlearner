package main

import (
	"log"
	"time"

	"github.com/gin-gonic/gin"

	v1 "backend/api/v1"
	"backend/internal/config"
	"backend/internal/db"
	"backend/internal/handlers"
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
	userRepo := repositories.NewUserRepository(conn)
	authService := services.NewAuthService(userRepo, cfg.JWTSecret, time.Duration(cfg.JWTExpiryMinute)*time.Minute)
	authHandler := handlers.NewAuthHandler(authService)
	router := gin.Default()
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})
	api := router.Group("/api/v1")
	{
		api.POST("/auth/register", authHandler.Register)
		api.POST("/auth/login", authHandler.Login)
		protected := api.Group("")
		protected.Use(middleware.Auth(cfg.JWTSecret))
		protected.GET("/me", authHandler.Me)
		{
			protected.POST("/decks", v1.CreateDeck)
			protected.GET("/decks", v1.GetDecks)
			protected.PUT("/decks/:id", v1.UpdateDeck)
			protected.DELETE("/decks/:id", v1.DeleteDeck)

			protected.POST("/cards", v1.CreateCard)
			protected.GET("/decks/:deck_id/cards", v1.GetDeckCards)
			protected.PUT("/cards/:id", v1.UpdateCard)
			protected.DELETE("/cards/:id", v1.DeleteCard)

			protected.POST("/sync/upload", v1.SyncUpload)
			protected.GET("/sync/download", v1.SyncDownload)
		}
	}
	log.Printf("server listening on :%s", cfg.Port)
	if err := router.Run(":" + cfg.Port); err != nil {
		log.Fatal(err)
	}
}
