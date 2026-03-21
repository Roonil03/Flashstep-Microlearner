package v1

import (
	"backend/internal/db"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

func SyncDownload(c *gin.Context) {
	userID := c.GetString("user_id")
	sinceStr := c.Query("since")
	var since time.Time
	var err error
	if sinceStr == "" {
		since = time.Unix(0, 0)
	} else {
		since, err = time.Parse(time.RFC3339, sinceStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid since format (use RFC3339)"})
			return
		}
	}

	deckRows, err := db.DB.Query(`
		SELECT id, user_id, title, description, is_public,
		       created_at, updated_at, version, is_deleted
		FROM decks
		WHERE (user_id=$1 OR is_public=true)
		AND updated_at > $2
	`, userID, since)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	defer deckRows.Close()
	var decks []gin.H
	for deckRows.Next() {
		var id, uid, title, desc string
		var isPublic, isDeleted bool
		var createdAt, updatedAt time.Time
		var version int
		err := deckRows.Scan(
			&id, &uid, &title, &desc, &isPublic,
			&createdAt, &updatedAt, &version, &isDeleted,
		)
		if err != nil {
			continue
		}
		decks = append(decks, gin.H{
			"id":          id,
			"user_id":     uid,
			"title":       title,
			"description": desc,
			"is_public":   isPublic,
			"created_at":  createdAt,
			"updated_at":  updatedAt,
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
		JOIN decks d ON c.deck_id = d.id
		WHERE (d.user_id=$1 OR d.is_public=true)
		AND c.updated_at > $2
	`, userID, since)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	defer cardRows.Close()
	var cards []gin.H
	for cardRows.Next() {
		var id, deckID, front, back, state string
		var interval, ease float64
		var reps int
		var due, lastReviewed, createdAt, updatedAt *time.Time
		var version int
		var isDeleted bool
		err := cardRows.Scan(
			&id, &deckID, &front, &back, &state,
			&interval, &ease, &reps,
			&due, &lastReviewed,
			&createdAt, &updatedAt,
			&version, &isDeleted,
		)
		if err != nil {
			continue
		}
		cards = append(cards, gin.H{
			"id":               id,
			"deck_id":          deckID,
			"front":            front,
			"back":             back,
			"state":            state,
			"interval":         interval,
			"ease_factor":      ease,
			"repetition_count": reps,
			"due_timestamp":    due,
			"last_reviewed_at": lastReviewed,
			"created_at":       createdAt,
			"updated_at":       updatedAt,
			"version":          version,
			"is_deleted":       isDeleted,
		})
	}
	c.JSON(http.StatusOK, gin.H{
		"decks": decks,
		"cards": cards,
	})
}
