package v1

import (
	"backend/internal/db"
	"net/http"

	"github.com/gin-gonic/gin"
)

func GetDecks(c *gin.Context) {
	userID := c.Query("user_id")
	rows, err := db.DB.Query(`
	SELECT id, title, description, is_public
	FROM decks
	WHERE user_id=$1 AND is_deleted=false
	`, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()
	var decks []map[string]interface{}
	for rows.Next() {
		var id, title, desc string
		var isPublic bool
		rows.Scan(&id, &title, &desc, &isPublic)
		decks = append(decks, gin.H{
			"id":          id,
			"title":       title,
			"description": desc,
			"is_public":   isPublic,
		})
	}
	c.JSON(http.StatusOK, decks)
}
