package v1

import (
	"backend/internal/db"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

func DeleteDeck(c *gin.Context) {
	id := c.Param("id")
	query := `
	UPDATE decks
	SET is_deleted = true, updated_at=$1, version=version+1
	WHERE id=$2
	`
	_, err := db.DB.Exec(query, time.Now(), id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "deleted"})
}
