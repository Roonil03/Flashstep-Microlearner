package v1

import (
	"backend/internal/db"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func GetDecks(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user id in auth context"})
		return
	}

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

	decks := make([]gin.H, 0)
	for rows.Next() {
		var id, ownerID uuid.UUID
		var title string
		var description *string
		var isPublic bool
		var createdAt, updatedAt time.Time
		var version int
		var isDeleted bool

		if err := rows.Scan(
			&id,
			&ownerID,
			&title,
			&description,
			&isPublic,
			&createdAt,
			&updatedAt,
			&version,
			&isDeleted,
		); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		decks = append(decks, gin.H{
			"id":          id.String(),
			"user_id":     ownerID.String(),
			"title":       title,
			"description": description,
			"is_public":   isPublic,
			"created_at":  createdAt.UTC().Format(time.RFC3339),
			"updated_at":  updatedAt.UTC().Format(time.RFC3339),
			"version":     version,
			"is_deleted":  isDeleted,
		})
	}

	if err := rows.Err(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, decks)
}
