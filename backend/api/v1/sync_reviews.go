package v1

import (
	"backend/internal/db"
	"database/sql"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// SyncReviews pages immutable review history for the authenticated account.
func SyncReviews(c *gin.Context) {
	user, ok := syncUser(c)
	if !ok {
		return
	}
	cursor, err := syncCursor(c.Query("cursor"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid cursor"})
		return
	}
	limit := 500
	if value := c.Query("limit"); value != "" {
		limit, err = strconv.Atoi(value)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid limit"})
			return
		}
	}
	limit, ok = syncPageLimit(limit)
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{"error": "limit must be between 1 and 500"})
		return
	}
	rows, err := db.DB.QueryContext(c.Request.Context(), `
SELECT id, user_id, card_id, rating, previous_interval, new_interval,
       reviewed_at, device_id, created_at
FROM review_logs WHERE user_id=$1 AND id>$2 ORDER BY id LIMIT $3`, user, cursor, limit+1)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()
	logs := make([]gin.H, 0)
	var next any
	for rows.Next() {
		var id, owner, card uuid.UUID
		var rating string
		var previous, newInterval sql.NullFloat64
		var reviewedAt, createdAt time.Time
		var device sql.NullString
		if err := rows.Scan(&id, &owner, &card, &rating, &previous, &newInterval, &reviewedAt, &device, &createdAt); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		if len(logs) == limit {
			next = logs[len(logs)-1]["id"]
			break
		}
		var deviceID any
		if device.Valid {
			deviceID = device.String
		}
		logs = append(logs, gin.H{
			"id": id.String(), "user_id": owner.String(), "card_id": card.String(),
			"rating": rating, "previous_interval": previous.Float64,
			"new_interval": newInterval.Float64, "reviewed_at": reviewedAt.UTC(),
			"device_id": deviceID, "created_at": createdAt.UTC(),
		})
	}
	if err := rows.Err(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"review_logs": logs, "next_cursor": next})
}
