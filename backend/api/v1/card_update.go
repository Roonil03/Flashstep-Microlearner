package v1

import (
	"backend/internal/db"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

type UpdateCardRequest struct {
	Front   string `json:"front"`
	Back    string `json:"back"`
	Version int    `json:"version"`
}

func UpdateCard(c *gin.Context) {
	userID := c.GetString("user_id")
	id := c.Param("id")

	var req UpdateCardRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	req.Front = strings.TrimSpace(req.Front)
	req.Back = strings.TrimSpace(req.Back)
	if req.Front == "" || req.Back == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "front and back are required"})
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
	res, err := db.DB.Exec(query, req.Front, req.Back, id, req.Version, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	rows, _ := res.RowsAffected()
	if rows == 0 {
		c.JSON(http.StatusConflict, gin.H{"error": "version conflict or card not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "updated"})
}
