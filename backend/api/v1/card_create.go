package v1

import (
	"backend/internal/db"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type CreateCardRequest struct {
	DeckID string `json:"deck_id"`
	Front  string `json:"front"`
	Back   string `json:"back"`
}

func CreateCard(c *gin.Context) {
	var req CreateCardRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	id := uuid.New().String()
	query := `
	INSERT INTO cards (id, deck_id, front, back)
	VALUES ($1, $2, $3, $4)
	`
	_, err := db.DB.Exec(query, id, req.DeckID, req.Front, req.Back)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"id": id})
}
