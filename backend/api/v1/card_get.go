package v1

import (
	"backend/internal/db"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

func GetDeckCards(c *gin.Context) {
	userID := c.GetString("user_id")
	deckID := c.Param("deck_id")
	rows, err := db.DB.Query(`
		SELECT c.id, c.deck_id, c.front, c.back, c.state,
		       c.due_timestamp, c.updated_at, c.version, c.is_deleted
		FROM cards c
		JOIN decks d ON c.deck_id = d.id
		WHERE c.deck_id=$1
		  AND c.is_deleted=false
		  AND d.is_deleted=false
		  AND (d.user_id=$2 OR d.is_public=true)
		ORDER BY c.created_at DESC
	`, deckID, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()
	var cards []map[string]interface{}
	for rows.Next() {
		var id, resolvedDeckID, front, back, state string
		var due *time.Time
		var updatedAt time.Time
		var version int
		var isDeleted bool
		if err := rows.Scan(
			&id,
			&resolvedDeckID,
			&front,
			&back,
			&state,
			&due,
			&updatedAt,
			&version,
			&isDeleted,
		); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		cards = append(cards, gin.H{
			"id":            id,
			"deck_id":       resolvedDeckID,
			"front":         front,
			"back":          back,
			"state":         state,
			"due_timestamp": due,
			"updated_at":    updatedAt,
			"version":       version,
			"is_deleted":    isDeleted,
		})
	}
	c.JSON(http.StatusOK, cards)
}
