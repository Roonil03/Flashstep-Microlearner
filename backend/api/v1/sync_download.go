package v1

import (
	"backend/internal/db"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func SyncDownload(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(strings.TrimSpace(userIDStr))
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user id in auth context"})
		return
	}

	sinceParam := strings.TrimSpace(c.Query("since"))
	var since time.Time
	if sinceParam == "" {
		since = time.Unix(0, 0).UTC()
	} else {
		parsed, err := time.Parse(time.RFC3339, sinceParam)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid since timestamp"})
			return
		}
		since = parsed.UTC()
	}

	deckRows, err := db.DB.Query(`
		SELECT id, user_id, title, description, is_public, created_at, updated_at, version, is_deleted
		FROM decks
		WHERE user_id=$1
		  AND updated_at > $2
		ORDER BY updated_at ASC, created_at ASC, id ASC
	`, userID, since)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer deckRows.Close()

	decks := make([]gin.H, 0)
	for deckRows.Next() {
		var id, ownerID uuid.UUID
		var title string
		var description *string
		var isPublic bool
		var createdAt, updatedAt time.Time
		var version int
		var isDeleted bool

		if err := deckRows.Scan(
			&id,
			&ownerID,
			&title,
			&description,
			&isPublic,
			&createdAt,
			&updatedAt,
			&version,
			&isDeleted,
		); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		decks = append(decks, gin.H{
			"id":          id.String(),
			"user_id":     ownerID.String(),
			"title":       title,
			"description": description,
			"is_public":   isPublic,
			"created_at":  createdAt.UTC().Format(time.RFC3339),
			"updated_at":  updatedAt.UTC().Format(time.RFC3339),
			"version":     version,
			"is_deleted":  isDeleted,
		})
	}

	cardRows, err := db.DB.Query(`
		SELECT c.id, c.deck_id, c.front, c.back, c.state,
		       c.interval, c.ease_factor, c.repetition_count,
		       c.due_timestamp, c.last_reviewed_at,
		       c.created_at, c.updated_at, c.version, c.is_deleted
		FROM cards c
		JOIN decks d ON d.id = c.deck_id
		WHERE d.user_id=$1
		  AND c.updated_at > $2
		ORDER BY c.updated_at ASC, c.created_at ASC, c.id ASC
	`, userID, since)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer cardRows.Close()

	cards := make([]gin.H, 0)
	for cardRows.Next() {
		var id, deckID uuid.UUID
		var front, back, state string
		var interval, easeFactor float64
		var repetitionCount int
		var dueTimestamp, lastReviewedAt *time.Time
		var createdAt, updatedAt time.Time
		var version int
		var isDeleted bool

		if err := cardRows.Scan(
			&id,
			&deckID,
			&front,
			&back,
			&state,
			&interval,
			&easeFactor,
			&repetitionCount,
			&dueTimestamp,
			&lastReviewedAt,
			&createdAt,
			&updatedAt,
			&version,
			&isDeleted,
		); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		var dueValue interface{}
		if dueTimestamp != nil {
			dueValue = dueTimestamp.UTC().Format(time.RFC3339)
		} else {
			dueValue = nil
		}

		var reviewedValue interface{}
		if lastReviewedAt != nil {
			reviewedValue = lastReviewedAt.UTC().Format(time.RFC3339)
		} else {
			reviewedValue = nil
		}

		cards = append(cards, gin.H{
			"id":               id.String(),
			"deck_id":          deckID.String(),
			"front":            front,
			"back":             back,
			"state":            state,
			"interval":         interval,
			"ease_factor":      easeFactor,
			"repetition_count": repetitionCount,
			"due_timestamp":    dueValue,
			"last_reviewed_at": reviewedValue,
			"created_at":       createdAt.UTC().Format(time.RFC3339),
			"updated_at":       updatedAt.UTC().Format(time.RFC3339),
			"version":          version,
			"is_deleted":       isDeleted,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"decks": decks,
		"cards": cards,
	})
}
