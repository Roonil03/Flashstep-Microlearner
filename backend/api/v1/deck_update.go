package v1

import (
	"backend/internal/db"
	"backend/internal/httperror"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

type UpdateDeckRequest struct {
	Title       string `json:"title" binding:"max=255"`
	Description string `json:"description"`
	IsPublic    bool   `json:"is_public"`
	Version     int    `json:"version" binding:"required,min=1"`
}

func UpdateDeck(c *gin.Context) {
	userID := c.GetString("user_id")
	id := c.Param("id")

	var req UpdateDeckRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		httperror.InvalidJSON(c, err)
		return
	}

	req.Title = strings.TrimSpace(req.Title)
	req.Description = strings.TrimSpace(req.Description)
	if req.Title == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "title is required"})
		return
	}
	ctx := c.Request.Context()
	tx, err := db.DB.BeginTx(ctx, nil)
	if err != nil {
		httperror.Internal(c, err)
		return
	}
	defer tx.Rollback()
	if _, err = tx.ExecContext(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, userID); err != nil {
		httperror.Internal(c, err)
		return
	}

	query := `
		UPDATE decks
		SET title=$1,
		    description=$2,
		    is_public=$3,
		    updated_at=NOW(),
		    version=version+1
		WHERE id=$4
		  AND version=$5
		  AND user_id=$6
		  AND is_deleted=false
	`
	res, err := tx.ExecContext(ctx, query, req.Title, nullIfEmpty(req.Description), req.IsPublic, id, req.Version, userID)
	if err != nil {
		httperror.Internal(c, err)
		return
	}

	rows, _ := res.RowsAffected()
	if rows == 0 {
		c.JSON(http.StatusConflict, gin.H{"error": "version conflict or deck not found"})
		return
	}
	if err = tx.Commit(); err != nil {
		httperror.Internal(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "updated"})
}
