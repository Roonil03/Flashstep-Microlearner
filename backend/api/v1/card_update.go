package v1

import (
	"backend/internal/db"
	"net/http"

	"github.com/gin-gonic/gin"
)

type UpdateCardRequest struct {
	Front   string `json:"front"`
	Back    string `json:"back"`
	Version int    `json:"version"`
}

func UpdateCard(c *gin.Context) {
	id := c.Param("id")
	var req UpdateCardRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	query := `
	UPDATE cards
	SET front=$1, back=$2, version=version+1
	WHERE id=$3 AND version=$4
	`
	res, err := db.DB.Exec(query, req.Front, req.Back, id, req.Version)
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
