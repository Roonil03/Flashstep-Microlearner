package v1

import (
	"errors"
	"math"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"
)

var legacyCardCreatedAtPattern = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?$`)

// Older Flutter review queues serialized local card creation metadata without
// an offset. Validate its shape and calendar without guessing a UTC instant.
func parseLegacyCardCreatedAt(stamp string) (time.Time, error) {
	if !legacyCardCreatedAtPattern.MatchString(stamp) {
		return time.Time{}, errors.New("invalid legacy card creation timestamp")
	}
	return time.Parse("2006-01-02T15:04:05", stamp)
}

// Validate before the legacy normalization helpers, which otherwise silently
// coerce malformed JSON to defaults and can poison every later sync batch.
func validateSyncRecord(raw map[string]any, entity string) error {
	bad := errors.New("invalid " + entity + " fields, values or timestamps")
	for _, field := range []string{"id", "deck_id", "user_id", "front", "back", "title", "description", "state", "rating", "device_id"} {
		if value, ok := raw[field]; ok && value != nil {
			if _, ok := value.(string); !ok {
				return bad
			}
		}
	}
	for _, field := range []string{"is_deleted", "is_public", "from_deck_deletion", "allow_create"} {
		if value, ok := raw[field]; ok {
			if _, ok := value.(bool); !ok {
				return bad
			}
		}
	}
	for _, field := range []string{"version", "repetition_count", "interval", "ease_factor", "previous_interval", "new_interval"} {
		if value, ok := raw[field]; ok && value != nil {
			n, ok := value.(float64)
			if !ok || math.IsNaN(n) || math.IsInf(n, 0) || n < 0 || n > 2147483647 {
				return bad
			}
			if (field == "version" || field == "repetition_count") && n != math.Trunc(n) {
				return bad
			}
			if field == "version" && n < 1 {
				return bad
			}
		}
	}
	for _, field := range []string{"created_at", "updated_at", "reviewed_at", "due_timestamp", "last_reviewed_at"} {
		if value, ok := raw[field]; ok && value != nil {
			stamp, ok := value.(string)
			if !ok {
				return bad
			}
			parsed, err := time.Parse(time.RFC3339Nano, stamp)
			legacyCreation := false
			if err != nil && entity == "card" && field == "created_at" {
				parsed, err = parseLegacyCardCreatedAt(stamp)
				legacyCreation = err == nil
			}
			if err != nil || parsed.Year() < 1 || parsed.Year() > 9998 {
				return bad
			}
			if !legacyCreation && field != "due_timestamp" && parsed.After(time.Now().Add(10*time.Minute)) {
				return bad
			}
		}
	}
	// PostgreSQL VARCHAR counts Unicode characters. TEXT content has historically
	// been unrestricted; the HTTP body limit bounds it without rejecting edits.
	if utf8.RuneCountInString(asString(raw["title"])) > 255 {
		return bad
	}
	if entity == "card" {
		state := asString(raw["state"])
		if state != "" && state != "new" && state != "learning" && state != "review" {
			return bad
		}
	}
	if entity == "review_log" {
		switch strings.TrimSpace(asString(raw["rating"])) {
		case "again", "hard", "good", "easy":
		default:
			return bad
		}
	}
	return nil
}
