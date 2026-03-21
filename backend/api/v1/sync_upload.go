package v1

import (
	"backend/internal/db"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

type SyncUploadPayload struct {
	Decks []map[string]interface{} `json:"decks"`
	Cards []map[string]interface{} `json:"cards"`
}

func SyncUpload(c *gin.Context) {
	userID := c.GetString("user_id")
	var payload SyncUploadPayload
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	tx, err := db.DB.Begin()
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	for _, d := range payload.Decks {
		id := d["id"]
		updatedAtStr, _ := d["updated_at"].(string)
		updatedAt, _ := time.Parse(time.RFC3339, updatedAtStr)
		_, err := tx.Exec(`
		INSERT INTO decks (id, user_id, title, description, is_public, updated_at, version, is_deleted)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		ON CONFLICT (id) DO UPDATE
		SET title=EXCLUDED.title,
		    description=EXCLUDED.description,
		    is_public=EXCLUDED.is_public,
		    updated_at=EXCLUDED.updated_at,
		    version=EXCLUDED.version,
		    is_deleted=EXCLUDED.is_deleted
		WHERE decks.updated_at < EXCLUDED.updated_at
		`,
			id,
			userID,
			d["title"],
			d["description"],
			d["is_public"],
			updatedAt,
			d["version"],
			d["is_deleted"],
		)
		if err != nil {
			tx.Rollback()
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}
	}

	for _, card := range payload.Cards {
		id := card["id"]
		updatedAtStr, _ := card["updated_at"].(string)
		updatedAt, _ := time.Parse(time.RFC3339, updatedAtStr)
		_, err := tx.Exec(`
		INSERT INTO cards (
			id, deck_id, front, back, state,
			interval, ease_factor, repetition_count,
			due_timestamp, last_reviewed_at,
			updated_at, version, is_deleted
		)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
		ON CONFLICT (id) DO UPDATE
		SET front=EXCLUDED.front,
		    back=EXCLUDED.back,
		    state=EXCLUDED.state,
		    interval=EXCLUDED.interval,
		    ease_factor=EXCLUDED.ease_factor,
		    repetition_count=EXCLUDED.repetition_count,
		    due_timestamp=EXCLUDED.due_timestamp,
		    last_reviewed_at=EXCLUDED.last_reviewed_at,
		    updated_at=EXCLUDED.updated_at,
		    version=EXCLUDED.version,
		    is_deleted=EXCLUDED.is_deleted
		WHERE cards.updated_at < EXCLUDED.updated_at
		`,
			id,
			card["deck_id"],
			card["front"],
			card["back"],
			card["state"],
			card["interval"],
			card["ease_factor"],
			card["repetition_count"],
			card["due_timestamp"],
			card["last_reviewed_at"],
			updatedAt,
			card["version"],
			card["is_deleted"],
		)
		if err != nil {
			tx.Rollback()
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}
	}
	tx.Commit()
	c.JSON(http.StatusOK, gin.H{
		"status": "synced",
	})
}
