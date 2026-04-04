package v1

import (
	"backend/internal/db"
	"net/http"

	"github.com/gin-gonic/gin"
)

func DeleteDeck(c *gin.Context) {
	userID := c.GetString("user_id")
	id := c.Param("id")

	tx, err := db.DB.Begin()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer func() {
		_ = tx.Rollback()
	}()

	res, err := tx.Exec(`
		UPDATE decks
		SET is_deleted=true,
		    updated_at=NOW(),
		    version=version+1
		WHERE id=$1
		  AND user_id=$2
		  AND is_deleted=false
	`, id, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	rows, _ := res.RowsAffected()
	if rows == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "deck not found"})
		return
	}

	if _, err := tx.Exec(`
		UPDATE cards
		SET is_deleted=true,
		    updated_at=NOW(),
		    version=version+1
		WHERE deck_id=$1
		  AND is_deleted=false
	`, id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if err := tx.Commit(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "deleted"})
}
