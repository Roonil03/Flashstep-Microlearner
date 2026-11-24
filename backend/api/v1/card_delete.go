package v1

import (
	"backend/internal/db"
	"backend/internal/httperror"
	"net/http"

	"github.com/gin-gonic/gin"
)

func DeleteCard(c *gin.Context) {
	userID := c.GetString("user_id")
	id, ok := contentParam(c, "id", "card id")
	if !ok {
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
		UPDATE cards
		SET is_deleted=true,
		    updated_at=NOW(),
		    version=version+1
		WHERE id=$1
		  AND is_deleted=false
		  AND deck_id IN (
			SELECT id
			FROM decks
			WHERE user_id=$2
		  )
	`
	res, err := tx.ExecContext(ctx, query, id, userID)
	if err != nil {
		httperror.Internal(c, err)
		return
	}

	rows, _ := res.RowsAffected()
	if rows == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "card not found"})
		return
	}
	if err = tx.Commit(); err != nil {
		httperror.Internal(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "deleted"})
}
