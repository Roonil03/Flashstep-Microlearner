package v1

import (
	"backend/internal/db"
	"errors"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

const maxCardsPerDeck = 50

type SyncUploadPayload struct {
	Decks      []map[string]any `json:"decks"`
	Cards      []map[string]any `json:"cards"`
	ReviewLogs []map[string]any `json:"review_logs"`
}

type syncDeck struct {
	ID          uuid.UUID
	Title       string
	Description *string
	IsPublic    bool
	CreatedAt   time.Time
	UpdatedAt   time.Time
	Version     int
	IsDeleted   bool
}

type syncCard struct {
	ID               uuid.UUID
	DeckID           uuid.UUID
	Front            string
	Back             string
	State            string
	Interval         float64
	EaseFactor       float64
	RepetitionCount  int
	DueTimestamp     *time.Time
	LastReviewedAt   *time.Time
	CreatedAt        time.Time
	UpdatedAt        time.Time
	Version          int
	IsDeleted        bool
	FromDeckDeletion bool
}

type syncReviewLog struct {
	ID               uuid.UUID
	UserID           uuid.UUID
	CardID           uuid.UUID
	Rating           string
	PreviousInterval float64
	NewInterval      float64
	ReviewedAt       time.Time
	DeviceID         *uuid.UUID
	CreatedAt        time.Time
}

func nullableStringValue(s *string) interface{} {
	if s == nil {
		return nil
	}
	return *s
}

func nullableTimeValue(t *time.Time) interface{} {
	if t == nil {
		return nil
	}
	return *t
}

func nullableUUIDValue(id *uuid.UUID) interface{} {
	if id == nil {
		return nil
	}
	return id.String()
}

func asString(v interface{}) string {
	if v == nil {
		return ""
	}
	switch t := v.(type) {
	case string:
		return strings.TrimSpace(t)
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
		n, _ := strconv.Atoi(strings.TrimSpace(t))
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
		n, _ := strconv.ParseFloat(strings.TrimSpace(t), 64)
		return n
	default:
		return 0
	}
}

func parseTimeOrZero(v interface{}) time.Time {
	s := asString(v)
	if s == "" {
		return time.Now().UTC()
	}
	parsed, err := time.Parse(time.RFC3339, s)
	if err != nil {
		return time.Now().UTC()
	}
	return parsed.UTC()
}

func parseOptionalTime(v interface{}) *time.Time {
	s := asString(v)
	if s == "" {
		return nil
	}
	parsed, err := time.Parse(time.RFC3339, s)
	if err != nil {
		return nil
	}
	t := parsed.UTC()
	return &t
}

func parseRequiredUUID(field string, v interface{}) (uuid.UUID, error) {
	s := asString(v)
	if s == "" {
		return uuid.Nil, errors.New(field + " is required")
	}
	id, err := uuid.Parse(s)
	if err != nil {
		return uuid.Nil, errors.New(field + " must be a valid UUID")
	}
	return id, nil
}

func normalizeNullableString(v interface{}) *string {
	s := asString(v)
	if s == "" {
		return nil
	}
	return &s
}

func normalizeDeck(raw map[string]interface{}) (syncDeck, error) {
	id, err := parseRequiredUUID("deck.id", raw["id"])
	if err != nil {
		return syncDeck{}, err
	}

	createdAt := parseTimeOrZero(raw["created_at"])
	updatedAt := parseTimeOrZero(raw["updated_at"])
	if createdAt.After(updatedAt) {
		createdAt = updatedAt
	}

	return syncDeck{
		ID:          id,
		Title:       asString(raw["title"]),
		Description: normalizeNullableString(raw["description"]),
		IsPublic:    asBool(raw["is_public"]),
		CreatedAt:   createdAt,
		UpdatedAt:   updatedAt,
		Version:     asInt(raw["version"]),
		IsDeleted:   asBool(raw["is_deleted"]),
	}, nil
}

func normalizeCard(raw map[string]interface{}) (syncCard, error) {
	id, err := parseRequiredUUID("card.id", raw["id"])
	if err != nil {
		return syncCard{}, err
	}
	deckID, err := parseRequiredUUID("card.deck_id", raw["deck_id"])
	if err != nil {
		return syncCard{}, err
	}

	createdAt := parseTimeOrZero(raw["created_at"])
	updatedAt := parseTimeOrZero(raw["updated_at"])
	if createdAt.After(updatedAt) {
		createdAt = updatedAt
	}

	state := asString(raw["state"])
	if state == "" {
		state = "new"
	}

	easeFactor := asFloat64(raw["ease_factor"])
	if easeFactor == 0 {
		easeFactor = 2.5
	}

	return syncCard{
		ID:               id,
		DeckID:           deckID,
		Front:            asString(raw["front"]),
		Back:             asString(raw["back"]),
		State:            state,
		Interval:         asFloat64(raw["interval"]),
		EaseFactor:       easeFactor,
		RepetitionCount:  asInt(raw["repetition_count"]),
		DueTimestamp:     parseOptionalTime(raw["due_timestamp"]),
		LastReviewedAt:   parseOptionalTime(raw["last_reviewed_at"]),
		CreatedAt:        createdAt,
		UpdatedAt:        updatedAt,
		Version:          asInt(raw["version"]),
		IsDeleted:        asBool(raw["is_deleted"]),
		FromDeckDeletion: asBool(raw["from_deck_deletion"]),
	}, nil
}

func parseOptionalUUID(v interface{}) (*uuid.UUID, error) {
	s := asString(v)
	if s == "" {
		return nil, nil
	}
	parsed, err := uuid.Parse(s)
	if err != nil {
		return nil, errors.New("invalid UUID")
	}
	return &parsed, nil
}

func normalizeReviewLog(raw map[string]interface{}, defaultUserID uuid.UUID) (syncReviewLog, error) {
	id, err := parseRequiredUUID("review_log.id", raw["id"])
	if err != nil {
		return syncReviewLog{}, err
	}
	cardID, err := parseRequiredUUID("review_log.card_id", raw["card_id"])
	if err != nil {
		return syncReviewLog{}, err
	}

	userID := defaultUserID
	if rawUserID := asString(raw["user_id"]); rawUserID != "" {
		parsedUserID, err := uuid.Parse(rawUserID)
		if err != nil {
			return syncReviewLog{}, errors.New("review_log.user_id must be a valid UUID")
		}
		userID = parsedUserID
	}

	deviceID, err := parseOptionalUUID(raw["device_id"])
	if err != nil {
		return syncReviewLog{}, errors.New("review_log.device_id must be a valid UUID")
	}

	rating := asString(raw["rating"])
	if rating == "" {
		return syncReviewLog{}, errors.New("review_log.rating is required")
	}

	return syncReviewLog{
		ID:               id,
		UserID:           userID,
		CardID:           cardID,
		Rating:           rating,
		PreviousInterval: asFloat64(raw["previous_interval"]),
		NewInterval:      asFloat64(raw["new_interval"]),
		ReviewedAt:       parseTimeOrZero(raw["reviewed_at"]),
		DeviceID:         deviceID,
		CreatedAt:        parseTimeOrZero(raw["created_at"]),
	}, nil
}

func SyncUpload(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(strings.TrimSpace(userIDStr))
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user id in auth context"})
		return
	}

	var payload SyncUploadPayload
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	decks := make([]syncDeck, 0, len(payload.Decks))
	for _, raw := range payload.Decks {
		deck, err := normalizeDeck(raw)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		if strings.TrimSpace(deck.Title) == "" && !deck.IsDeleted {
			c.JSON(http.StatusBadRequest, gin.H{"error": "deck.title is required"})
			return
		}
		decks = append(decks, deck)
	}

	cards := make([]syncCard, 0, len(payload.Cards))
	for _, raw := range payload.Cards {
		card, err := normalizeCard(raw)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		if !card.IsDeleted {
			if strings.TrimSpace(card.Front) == "" || strings.TrimSpace(card.Back) == "" {
				c.JSON(http.StatusBadRequest, gin.H{"error": "card front and back are required"})
				return
			}
		}
		cards = append(cards, card)
	}

	reviewLogs := make([]syncReviewLog, 0, len(payload.ReviewLogs))
	for _, raw := range payload.ReviewLogs {
		reviewLog, err := normalizeReviewLog(raw, userID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		reviewLogs = append(reviewLogs, reviewLog)
	}

	sort.SliceStable(decks, func(i, j int) bool {
		if !decks[i].UpdatedAt.Equal(decks[j].UpdatedAt) {
			return decks[i].UpdatedAt.Before(decks[j].UpdatedAt)
		}
		if !decks[i].CreatedAt.Equal(decks[j].CreatedAt) {
			return decks[i].CreatedAt.Before(decks[j].CreatedAt)
		}
		return decks[i].ID.String() < decks[j].ID.String()
	})
	sort.SliceStable(cards, func(i, j int) bool {
		if !cards[i].UpdatedAt.Equal(cards[j].UpdatedAt) {
			return cards[i].UpdatedAt.Before(cards[j].UpdatedAt)
		}
		if !cards[i].CreatedAt.Equal(cards[j].CreatedAt) {
			return cards[i].CreatedAt.Before(cards[j].CreatedAt)
		}
		return cards[i].ID.String() < cards[j].ID.String()
	})
	sort.SliceStable(reviewLogs, func(i, j int) bool {
		if !reviewLogs[i].ReviewedAt.Equal(reviewLogs[j].ReviewedAt) {
			return reviewLogs[i].ReviewedAt.Before(reviewLogs[j].ReviewedAt)
		}
		if !reviewLogs[i].CreatedAt.Equal(reviewLogs[j].CreatedAt) {
			return reviewLogs[i].CreatedAt.Before(reviewLogs[j].CreatedAt)
		}
		return reviewLogs[i].ID.String() < reviewLogs[j].ID.String()
	})

	ctx := c.Request.Context()
	tx, err := db.DB.BeginTx(ctx, nil)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	defer tx.Rollback()
	if err := applySyncChanges(ctx, tx, userID, decks, cards, reviewLogs); err != nil {
		c.JSON(syncErrorStatus(err), gin.H{"error": err.Error()})
		return
	}
	if err := tx.Commit(); err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":                "synced",
		"decks_processed":       len(decks),
		"cards_processed":       len(cards),
		"review_logs_processed": len(reviewLogs),
		"server_time":           time.Now().UTC().Format(time.RFC3339),
	})
}
