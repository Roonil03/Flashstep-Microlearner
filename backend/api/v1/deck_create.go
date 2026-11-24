package v1

import (
	"backend/internal/db"
	"backend/internal/httperror"
	"backend/internal/httpinput"
	"backend/internal/repositories"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type CreateDeckRequest struct {
	Title       string `json:"title" binding:"max=255"`
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
	if err := httpinput.BindJSON(c, &req); err != nil {
		httperror.InvalidJSON(c, err)
		return
	}

	req.Title = strings.TrimSpace(req.Title)
	req.Description = strings.TrimSpace(req.Description)

	if !httpinput.ValidText(req.Title, req.Description) {
		httperror.InvalidJSON(c, nil)
		return
	}
	if req.Title == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "title is required"})
		return
	}

	id := uuid.New()

	ctx := c.Request.Context()
	tx, err := db.DB.BeginTx(ctx, nil)
	if err != nil {
		httperror.Internal(c, err)
		return
	}
	defer tx.Rollback()
	if _, err = tx.ExecContext(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, userID.String()); err != nil {
		httperror.Internal(c, err)
		return
	}
	if err = repositories.LockContentIDs(ctx, tx, []string{"deck:" + id.String()}); err != nil {
		httperror.Internal(c, err)
		return
	}
	_, err = tx.ExecContext(ctx, `
		INSERT INTO decks (
			id, user_id, title, description, is_public,
			created_at, updated_at, version, is_deleted
		)
		VALUES ($1,$2,$3,$4,$5,NOW(),NOW(),1,false)
	`, id, userID, req.Title, nullIfEmpty(req.Description), req.IsPublic)
	if err != nil {
		httperror.Internal(c, err)
		return
	}

	if err = tx.Commit(); err != nil {
		httperror.Internal(c, err)
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
