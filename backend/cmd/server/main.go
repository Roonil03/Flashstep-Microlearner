package main

import (
	"log"

	"github.com/gin-gonic/gin"
	"github.com/gofiber/fiber/v2"
)

func main() {

	// Gin server
	ginRouter := gin.Default()
	ginRouter.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "Gin OK"})
	})

	// Fiber server
	fiberApp := fiber.New()
	fiberApp.Get("/fiber-health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"status": "Fiber OK"})
	})

	// Run both (different ports)
	go func() {
		log.Println("Gin running on :8080")
		ginRouter.Run(":8080")
	}()

	log.Println("Fiber running on :8081")
	fiberApp.Listen(":8081")
}
