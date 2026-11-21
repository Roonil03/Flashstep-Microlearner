package v1

import (
	"backend/internal/db"
	"backend/internal/httperror"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

type UpdateCardRequest struct {
	Front   string `json:"front"`
	Back    string `json:"back"`
	Version int    `json:"version" binding:"required,min=1"`
}

func UpdateCard(c *gin.Context) {
	userID := c.GetString("user_id")
	id := c.Param("id")

	var req UpdateCardRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		httperror.InvalidJSON(c, err)
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
		httperror.Internal(c, err)
		return
	}
	defer tx.Rollback()
	// Match sync's account lock before reading or changing a card revision.
	if _, err = tx.ExecContext(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, userID); err != nil {
		httperror.Internal(c, err)
		return
	}

	query := `
		UPDATE cards
		SET front=$1,
		    back=$2,
		    updated_at=NOW(),
		    version=version+1
		WHERE id=$3
		  AND version=$4
		  AND is_deleted=false
		  AND deck_id IN (
			SELECT id
			FROM decks
			WHERE user_id=$5
			  AND is_deleted=false
		  )
	`
	res, err := tx.ExecContext(ctx, query, req.Front, req.Back, id, req.Version, userID)
	if err != nil {
		httperror.Internal(c, err)
		return
	}

	rows, _ := res.RowsAffected()
	if rows == 0 {
		c.JSON(http.StatusConflict, gin.H{"error": "version conflict or card not found"})
		return
	}
	if err = tx.Commit(); err != nil {
		httperror.Internal(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "updated"})
}
