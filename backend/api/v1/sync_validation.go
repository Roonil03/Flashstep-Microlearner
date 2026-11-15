package v1

import (
	"errors"
	"math"
	"strings"
	"time"
	"unicode/utf8"
)

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
	for _, field := range []string{"is_deleted", "is_public", "from_deck_deletion"} {
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
			if err != nil || parsed.Year() < 1 || parsed.Year() > 9998 {
				return bad
			}
			if field != "due_timestamp" && parsed.After(time.Now().Add(10*time.Minute)) {
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
