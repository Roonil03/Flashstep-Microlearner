package v1

import (
	"backend/internal/db"
	"net/http"

	"github.com/gin-gonic/gin"
)

func GetDeckCards(c *gin.Context) {
	userID := c.GetString("user_id")
	deckID := c.Param("deck_id")
	rows, err := db.DB.Query(`
	SELECT c.id, c.front, c.back, c.state, c.due_timestamp, c.updated_at, c.version
	FROM cards c
	JOIN decks d ON c.deck_id = d.id
	WHERE c.deck_id=$1
	AND c.is_deleted=false
	AND d.is_deleted=false
	AND (d.user_id=$2 OR d.is_public=true)
	`, deckID, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()
	var cards []map[string]interface{}
	for rows.Next() {
		var id, front, back, state string
		var due interface{}
		rows.Scan(&id, &front, &back, &state, &due)
		cards = append(cards, gin.H{
			"id":    id,
			"front": front,
			"back":  back,
			"state": state,
			"due":   due,
		})
	}
	c.JSON(http.StatusOK, cards)
}
