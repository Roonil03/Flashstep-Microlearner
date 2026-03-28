package v1

import (
	"backend/internal/db"
	"net/http"

	"github.com/gin-gonic/gin"
)

func GetDecks(c *gin.Context) {
	userID := c.GetString("user_id")
	rows, err := db.DB.Query(`
	SELECT id, user_id, title, description, is_public, created_at, updated_at, version, is_deleted
	FROM decks
	WHERE user_id=$1
	AND is_deleted=false
	ORDER BY updated_at DESC, created_at DESC, id DESC
	`, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()
	var decks []gin.H
	for rows.Next() {
		var id, title, desc string
		var isPublic bool
		var updatedAt interface{}
		var version int
		rows.Scan(&id, &title, &desc, &isPublic, &updatedAt, &version)
		decks = append(decks, gin.H{
			"id":          id,
			"title":       title,
			"description": desc,
			"is_public":   isPublic,
			"updated_at":  updatedAt,
			"version":     version,
		})
	}
	c.JSON(http.StatusOK, decks)
}
