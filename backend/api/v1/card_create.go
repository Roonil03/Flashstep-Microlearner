package v1

import (
	"backend/internal/db"
	"database/sql"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type CreateCardRequest struct {
	DeckID string `json:"deck_id"`
	Front  string `json:"front"`
	Back   string `json:"back"`
}

func CreateCard(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(strings.TrimSpace(userIDStr))
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user id in auth context"})
		return
	}

	var req CreateCardRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	deckID, err := uuid.Parse(strings.TrimSpace(req.DeckID))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "deck_id must be a valid UUID"})
		return
	}

	req.Front = strings.TrimSpace(req.Front)
	req.Back = strings.TrimSpace(req.Back)

	if req.Front == "" || req.Back == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "front and back are required"})
		return
	}

	ctx := c.Request.Context()
	tx, err := db.DB.BeginTx(ctx, nil)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	defer tx.Rollback()
	var lockedID uuid.UUID
	err = tx.QueryRowContext(ctx, `SELECT id FROM decks WHERE id=$1 AND user_id=$2 AND is_deleted=false FOR UPDATE`, deckID, userID).Scan(&lockedID)
	if err == sql.ErrNoRows {
		c.JSON(403, gin.H{"error": "invalid deck"})
		return
	}
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	var cardCount int
	err = tx.QueryRowContext(ctx, `
		SELECT COUNT(*)
		FROM cards
		WHERE deck_id=$1 AND is_deleted=false
	`, deckID).Scan(&cardCount)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if cardCount >= maxCardsPerDeck {
		c.JSON(http.StatusBadRequest, gin.H{"error": "a deck can contain at most 50 cards"})
		return
	}

	id := uuid.New()
	_, err = tx.ExecContext(ctx, `
		INSERT INTO cards (
			id, deck_id, front, back, state,
			interval, ease_factor, repetition_count,
			due_timestamp, last_reviewed_at,
			created_at, updated_at, version, is_deleted
		)
		VALUES ($1,$2,$3,$4,'new',0,2.5,0,NOW(),NULL,NOW(),NOW(),1,false)
	`, id, deckID, req.Front, req.Back)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if err := tx.Commit(); err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"id": id.String()})
}
