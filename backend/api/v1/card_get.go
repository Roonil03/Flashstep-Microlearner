package v1

import (
	"backend/internal/db"
	"net/http"

	"github.com/gin-gonic/gin"
)

func GetDeckCards(c *gin.Context) {
	deckID := c.Param("deck_id")
	rows, err := db.DB.Query(`
	SELECT id, front, back, state, due_timestamp
	FROM cards
	WHERE deck_id=$1 AND is_deleted=false
	`, deckID)
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
