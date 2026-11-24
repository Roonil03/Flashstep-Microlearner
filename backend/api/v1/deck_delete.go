package v1

import (
	"backend/internal/db"
	"backend/internal/httperror"
	"net/http"

	"github.com/gin-gonic/gin"
)

func DeleteDeck(c *gin.Context) {
	userID := c.GetString("user_id")
	id, ok := contentParam(c, "id", "deck id")
	if !ok {
		return
	}

	tx, err := db.DB.BeginTx(c.Request.Context(), nil)
	if err != nil {
		httperror.Internal(c, err)
		return
	}
	defer func() {
		_ = tx.Rollback()
	}()
	if _, err = tx.ExecContext(c.Request.Context(), `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, userID); err != nil {
		httperror.Internal(c, err)
		return
	}

	res, err := tx.ExecContext(c.Request.Context(), `
		UPDATE decks
		SET is_deleted=true,
		    updated_at=NOW(),
		    version=version+1
		WHERE id=$1
		  AND user_id=$2
		  AND is_deleted=false
	`, id, userID)
	if err != nil {
		httperror.Internal(c, err)
		return
	}

	rows, _ := res.RowsAffected()
	if rows == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "deck not found"})
		return
	}

	if _, err := tx.ExecContext(c.Request.Context(), `
		UPDATE cards
		SET is_deleted=true,
		    updated_at=NOW(),
		    version=version+1
		WHERE deck_id=$1
		  AND is_deleted=false
	`, id); err != nil {
		httperror.Internal(c, err)
		return
	}

	if err := tx.Commit(); err != nil {
		httperror.Internal(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "deleted"})
}
