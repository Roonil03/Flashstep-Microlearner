package v1

import (
	"backend/internal/db"
	"database/sql"
	"github.com/gin-gonic/gin"
	"strings"
	"time"
)

// SyncDownload remains compatible with existing clients.
func SyncDownload(c *gin.Context) {
	user, ok := syncUser(c)
	if !ok {
		return
	}
	since := time.Unix(0, 0).UTC()
	if value := strings.TrimSpace(c.Query("since")); value != "" {
		parsed, err := time.Parse(time.RFC3339Nano, value)
		if err != nil {
			c.JSON(400, gin.H{"error": "invalid since timestamp"})
			return
		}
		since = parsed.UTC()
	}
	ctx := c.Request.Context()
	tx, err := db.DB.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelRepeatableRead, ReadOnly: true})
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	defer tx.Rollback()
	decks, err := readSyncDecks(ctx, tx, `WHERE d.user_id=$1 AND d.updated_at>$2 ORDER BY d.updated_at,d.created_at,d.id`, user, since)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	cards, err := readSyncCards(ctx, tx, `WHERE d.user_id=$1 AND c.updated_at>$2 ORDER BY c.updated_at,c.created_at,c.id`, user, since)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	if err := tx.Commit(); err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	c.JSON(200, gin.H{"decks": decks, "cards": cards})
}
