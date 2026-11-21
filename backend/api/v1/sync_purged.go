package v1

import (
	"github.com/gin-gonic/gin"
	"strconv"
)

// Compatibility endpoint: main has no durable deletion receipts. Updated
// clients reconcile absence using complete manifest and deck fetch results.
func SyncPurged(c *gin.Context) {
	if _, ok := syncUser(c); !ok {
		return
	}
	cursor := int64(0)
	if value := c.Query("cursor"); value != "" {
		var err error
		cursor, err = strconv.ParseInt(value, 10, 64)
		if err != nil || cursor < 0 {
			c.JSON(400, gin.H{"error": "invalid cursor"})
			return
		}
	}
	c.JSON(200, gin.H{"purged": []any{}, "next_cursor": nil, "checkpoint_cursor": strconv.FormatInt(cursor, 10), "reconciliation_version": 1})
}
