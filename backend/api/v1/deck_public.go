package v1

import (
	"backend/internal/db"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func GetPublicDecks(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(strings.TrimSpace(userIDStr))
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user id in auth context"})
		return
	}

	rows, err := db.DB.Query(`
		SELECT d.id, d.user_id, d.title, d.description, d.updated_at, d.version,
		       u.username,
		       COUNT(c.id) FILTER (WHERE c.is_deleted=false) AS card_count
		FROM decks d
		JOIN users u ON u.id = d.user_id
		LEFT JOIN cards c ON c.deck_id = d.id
		WHERE d.is_public=true
		  AND d.is_deleted=false
		  AND d.user_id <> $1
		GROUP BY d.id, d.user_id, d.title, d.description, d.updated_at, d.version, u.username
		ORDER BY d.updated_at DESC, d.title ASC
	`, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()

	publicDecks := make([]gin.H, 0)
	for rows.Next() {
		var deckID, ownerID uuid.UUID
		var title string
		var description *string
		var updatedAt time.Time
		var version int
		var ownerUsername string
		var cardCount int

		if err := rows.Scan(
			&deckID,
			&ownerID,
			&title,
			&description,
			&updatedAt,
			&version,
			&ownerUsername,
			&cardCount,
		); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		publicDecks = append(publicDecks, gin.H{
			"id":             deckID.String(),
			"user_id":        ownerID.String(),
			"title":          title,
			"description":    description,
			"updated_at":     updatedAt.UTC().Format(time.RFC3339),
			"version":        version,
			"owner_username": ownerUsername,
			"card_count":     cardCount,
		})
	}

	c.JSON(http.StatusOK, publicDecks)
}

func DownloadPublicDeck(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(strings.TrimSpace(userIDStr))
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user id in auth context"})
		return
	}

	sourceDeckID, err := uuid.Parse(strings.TrimSpace(c.Param("id")))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "deck id must be a valid UUID"})
		return
	}

	tx, err := db.DB.Begin()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer func() {
		_ = tx.Rollback()
	}()

	var sourceOwnerID uuid.UUID
	var sourceTitle string
	var sourceDescription *string
	var sourceOwnerUsername string
	err = tx.QueryRow(`
		SELECT d.user_id, d.title, d.description, u.username
		FROM decks d
		JOIN users u ON u.id = d.user_id
		WHERE d.id=$1
		  AND d.is_public=true
		  AND d.is_deleted=false
	`, sourceDeckID).Scan(
		&sourceOwnerID,
		&sourceTitle,
		&sourceDescription,
		&sourceOwnerUsername,
	)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "public deck not found"})
		return
	}

	if sourceOwnerID == userID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "you already own this public deck"})
		return
	}

	newDeckID := uuid.New()
	now := time.Now().UTC()

	_, err = tx.Exec(`
	INSERT INTO decks (
		id, user_id, title, description, is_public,
		created_at, updated_at, version, is_deleted
	)
	VALUES ($1,$2,$3,$4,false,$5,$5,1,false)
`, newDeckID, userID, sourceTitle, nullableStringValue(sourceDescription), now)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	type copiedCard struct {
		ID              uuid.UUID
		DeckID          uuid.UUID
		Front           string
		Back            string
		State           string
		Interval        float64
		EaseFactor      float64
		RepetitionCount int
		DueTimestamp    time.Time
		LastReviewedAt  *time.Time
		CreatedAt       time.Time
		UpdatedAt       time.Time
		Version         int
		IsDeleted       bool
	}

	type sourceCard struct {
		Front string
		Back  string
	}

	cardRows, err := tx.Query(`
	SELECT front, back
	FROM cards
	WHERE deck_id=$1
	  AND is_deleted=false
	ORDER BY created_at ASC, id ASC
`, sourceDeckID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	sourceCards := make([]sourceCard, 0)
	for cardRows.Next() {
		var row sourceCard
		if err := cardRows.Scan(&row.Front, &row.Back); err != nil {
			_ = cardRows.Close()
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		sourceCards = append(sourceCards, row)
	}
	if err := cardRows.Err(); err != nil {
		_ = cardRows.Close()
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if err := cardRows.Close(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	cards := make([]copiedCard, 0, len(sourceCards))
	for _, src := range sourceCards {
		newCardID := uuid.New()
		dueAt := now

		_, err = tx.Exec(`
		INSERT INTO cards (
			id, deck_id, front, back, state,
			interval, ease_factor, repetition_count,
			due_timestamp, last_reviewed_at,
			created_at, updated_at, version, is_deleted
		)
		VALUES ($1,$2,$3,$4,'new',0,2.5,0,$5,NULL,$6,$6,1,false)
	`, newCardID, newDeckID, src.Front, src.Back, dueAt, now)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		cards = append(cards, copiedCard{
			ID:              newCardID,
			DeckID:          newDeckID,
			Front:           src.Front,
			Back:            src.Back,
			State:           "new",
			Interval:        0,
			EaseFactor:      2.5,
			RepetitionCount: 0,
			DueTimestamp:    dueAt,
			LastReviewedAt:  nil,
			CreatedAt:       now,
			UpdatedAt:       now,
			Version:         1,
			IsDeleted:       false,
		})
	}

	if err := tx.Commit(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	cardPayload := make([]gin.H, 0, len(cards))
	for _, card := range cards {
		cardPayload = append(cardPayload, gin.H{
			"id":               card.ID.String(),
			"deck_id":          card.DeckID.String(),
			"front":            card.Front,
			"back":             card.Back,
			"state":            card.State,
			"interval":         card.Interval,
			"ease_factor":      card.EaseFactor,
			"repetition_count": card.RepetitionCount,
			"due_timestamp":    card.DueTimestamp.UTC().Format(time.RFC3339),
			"last_reviewed_at": nil,
			"created_at":       card.CreatedAt.UTC().Format(time.RFC3339),
			"updated_at":       card.UpdatedAt.UTC().Format(time.RFC3339),
			"version":          card.Version,
			"is_deleted":       card.IsDeleted,
		})
	}

	c.JSON(http.StatusCreated, gin.H{
		"deck": gin.H{
			"id":          newDeckID.String(),
			"user_id":     userID.String(),
			"title":       sourceTitle,
			"description": sourceDescription,
			"is_public":   false,
			"created_at":  now.UTC().Format(time.RFC3339),
			"updated_at":  now.UTC().Format(time.RFC3339),
			"version":     1,
			"is_deleted":  false,
		},
		"cards":                 cardPayload,
		"downloaded_from":       sourceDeckID.String(),
		"source_owner_id":       sourceOwnerID.String(),
		"source_owner_username": sourceOwnerUsername,
	})
}
