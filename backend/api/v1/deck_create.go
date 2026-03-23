package v1

import (
	"backend/internal/db"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type CreateDeckRequest struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	IsPublic    bool   `json:"is_public"`
}

func CreateDeck(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(strings.TrimSpace(userIDStr))
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user id in auth context"})
		return
	}

	var req CreateDeckRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	req.Title = strings.TrimSpace(req.Title)
	req.Description = strings.TrimSpace(req.Description)

	if req.Title == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "title is required"})
		return
	}

	id := uuid.New()

	_, err = db.DB.Exec(`
		INSERT INTO decks (
			id, user_id, title, description, is_public,
			created_at, updated_at, version, is_deleted
		)
		VALUES ($1,$2,$3,$4,$5,NOW(),NOW(),1,false)
	`, id, userID, req.Title, nullIfEmpty(req.Description), req.IsPublic)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"id": id.String()})
}

func nullIfEmpty(s string) any {
	if strings.TrimSpace(s) == "" {
		return nil
	}
	return s
}
