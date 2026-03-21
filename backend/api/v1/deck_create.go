package v1

import (
	"backend/internal/db"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type CreateDeckRequest struct {
	UserID      string `json:"user_id"`
	Title       string `json:"title"`
	Description string `json:"description"`
	IsPublic    bool   `json:"is_public"`
}

func CreateDeck(c *gin.Context) {
	userID := c.GetString("user_id")
	var req CreateDeckRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	id := uuid.New().String()
	query := `
	INSERT INTO decks (id, user_id, title, description, is_public, created_at, updated_at)
	VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
	`
	_, err := db.DB.Exec(query, id, userID, req.Title, req.Description, req.IsPublic)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"id": id})
}
