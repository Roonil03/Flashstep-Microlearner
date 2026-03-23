package v1

import (
	"backend/internal/db"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

const maxCardsPerDeck = 50

type CreateCardRequest struct {
	DeckID string `json:"deck_id"`
	Front  string `json:"front"`
	Back   string `json:"back"`
}

func CreateCard(c *gin.Context) {
	userID := c.GetString("user_id")
	var req CreateCardRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	req.DeckID = strings.TrimSpace(req.DeckID)
	req.Front = strings.TrimSpace(req.Front)
	req.Back = strings.TrimSpace(req.Back)
	if req.DeckID == "" || req.Front == "" || req.Back == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "deck_id, front and back are required"})
		return
	}
	var exists bool
	err := db.DB.QueryRow(`
		SELECT EXISTS(
			SELECT 1
			FROM decks
			WHERE id=$1 AND user_id=$2 AND is_deleted=false
		)
	`, req.DeckID, userID).Scan(&exists)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if !exists {
		c.JSON(http.StatusForbidden, gin.H{"error": "invalid deck"})
		return
	}
	var cardCount int
	err = db.DB.QueryRow(`
		SELECT COUNT(*)
		FROM cards
		WHERE deck_id=$1 AND is_deleted=false
	`, req.DeckID).Scan(&cardCount)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if cardCount >= maxCardsPerDeck {
		c.JSON(http.StatusBadRequest, gin.H{"error": "a deck can contain at most 50 cards"})
		return
	}
	id := uuid.New().String()
	query := `
		INSERT INTO cards (id, deck_id, front, back, created_at, updated_at)
		VALUES ($1, $2, $3, $4, NOW(), NOW())
	`
	_, err = db.DB.Exec(query, id, req.DeckID, req.Front, req.Back)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"id": id})
}
