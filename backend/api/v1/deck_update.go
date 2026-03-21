package v1

import (
	"backend/internal/db"
	"net/http"

	"github.com/gin-gonic/gin"
)

type UpdateDeckRequest struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	IsPublic    bool   `json:"is_public"`
	Version     int    `json:"version"`
}

func UpdateDeck(c *gin.Context) {
	userID := c.GetString("user_id")
	id := c.Param("id")
	var req UpdateDeckRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	query := `
	UPDATE decks
	SET title=$1, description=$2, is_public=$3, updated_at=NOW(), version=version+1
	WHERE id=$4 AND version=$5 AND user_id=$6
	`
	res, err := db.DB.Exec(query, req.Title, req.Description, req.IsPublic, id, req.Version, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	rows, _ := res.RowsAffected()
	if rows == 0 {
		c.JSON(http.StatusConflict, gin.H{"error": "version conflict"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "updated"})
}
