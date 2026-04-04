package v1

import (
	"backend/internal/db"
	"net/http"

	"github.com/gin-gonic/gin"
)

func DeleteCard(c *gin.Context) {
	userID := c.GetString("user_id")
	id := c.Param("id")

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
	res, err := db.DB.Exec(query, id, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	rows, _ := res.RowsAffected()
	if rows == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "card not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "deleted"})
}
