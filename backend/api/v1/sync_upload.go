package v1

import (
	"backend/internal/db"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

type SyncUploadPayload struct {
	Decks []map[string]interface{} `json:"decks"`
	Cards []map[string]interface{} `json:"cards"`
}

func asString(v interface{}) string {
	if v == nil {
		return ""
	}
	switch t := v.(type) {
	case string:
		return t
	default:
		return ""
	}
}

func asBool(v interface{}) bool {
	if v == nil {
		return false
	}
	switch t := v.(type) {
	case bool:
		return t
	default:
		return false
	}
}

func asInt(v interface{}) int {
	if v == nil {
		return 0
	}
	switch t := v.(type) {
	case int:
		return t
	case int32:
		return int(t)
	case int64:
		return int(t)
	case float32:
		return int(t)
	case float64:
		return int(t)
	case string:
		n, _ := strconv.Atoi(t)
		return n
	default:
		return 0
	}
}

func asFloat64(v interface{}) float64 {
	if v == nil {
		return 0
	}
	switch t := v.(type) {
	case float32:
		return float64(t)
	case float64:
		return t
	case int:
		return float64(t)
	case int32:
		return float64(t)
	case int64:
		return float64(t)
	case string:
		n, _ := strconv.ParseFloat(t, 64)
		return n
	default:
		return 0
	}
}

func asTimePtr(v interface{}) *time.Time {
	s := asString(v)
	if s == "" {
		return nil
	}
	parsed, err := time.Parse(time.RFC3339, s)
	if err != nil {
		return nil
	}
	return &parsed
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
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	for _, d := range payload.Decks {
		id := asString(d["id"])
		updatedAtStr := asString(d["updated_at"])
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
			asString(d["title"]),
			asString(d["description"]),
			asBool(d["is_public"]),
			updatedAt,
			asInt(d["version"]),
			asBool(d["is_deleted"]),
		)
		if err != nil {
			_ = tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
	}
	for _, card := range payload.Cards {
		id := asString(card["id"])
		deckID := asString(card["deck_id"])
		updatedAtStr := asString(card["updated_at"])
		updatedAt, _ := time.Parse(time.RFC3339, updatedAtStr)
		isDeleted := asBool(card["is_deleted"])
		var deckExists bool
		err := tx.QueryRow(`
			SELECT EXISTS(
				SELECT 1
				FROM decks
				WHERE id=$1 AND user_id=$2 AND is_deleted=false
			)
		`, deckID, userID).Scan(&deckExists)
		if err != nil {
			_ = tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		if !deckExists {
			_ = tx.Rollback()
			c.JSON(http.StatusForbidden, gin.H{"error": "invalid deck in sync payload"})
			return
		}
		if !isDeleted {
			var cardAlreadyExists bool
			err = tx.QueryRow(`
				SELECT EXISTS(
					SELECT 1
					FROM cards
					WHERE id=$1
				)
			`, id).Scan(&cardAlreadyExists)
			if err != nil {
				_ = tx.Rollback()
				c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
				return
			}
			if !cardAlreadyExists {
				var cardCount int
				err = tx.QueryRow(`
					SELECT COUNT(*)
					FROM cards
					WHERE deck_id=$1 AND is_deleted=false
				`, deckID).Scan(&cardCount)
				if err != nil {
					_ = tx.Rollback()
					c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
					return
				}
				if cardCount >= maxCardsPerDeck {
					_ = tx.Rollback()
					c.JSON(http.StatusBadRequest, gin.H{"error": "a deck can contain at most 50 cards"})
					return
				}
			}
		}
		_, err = tx.Exec(`
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
			deckID,
			asString(card["front"]),
			asString(card["back"]),
			asString(card["state"]),
			asFloat64(card["interval"]),
			asFloat64(card["ease_factor"]),
			asInt(card["repetition_count"]),
			asTimePtr(card["due_timestamp"]),
			asTimePtr(card["last_reviewed_at"]),
			updatedAt,
			asInt(card["version"]),
			isDeleted,
		)
		if err != nil {
			_ = tx.Rollback()
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
	}
	if err := tx.Commit(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"status": "synced",
	})
}
