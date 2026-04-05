package repositories

import (
	"context"
	"database/sql"
	"time"

	"github.com/google/uuid"
)

type txRunner interface {
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
}

type ProgressRepository struct{}

func NewProgressRepository() *ProgressRepository {
	return &ProgressRepository{}
}

func (r *ProgressRepository) RecomputeUserCardProgress(ctx context.Context, tx txRunner, userID, cardID string) error {
	var deckID string
	var currentInterval, easeFactor float64
	var repetitionCount int
	var dueTimestamp, lastReviewedAt sql.NullTime
	err := tx.QueryRowContext(ctx, `
		SELECT c.deck_id, c.interval, c.ease_factor, c.repetition_count, c.due_timestamp, c.last_reviewed_at
		FROM cards c
		JOIN decks d ON d.id = c.deck_id
		WHERE c.id = $1 AND d.user_id = $2
	`, cardID, userID).Scan(
		&deckID,
		&currentInterval,
		&easeFactor,
		&repetitionCount,
		&dueTimestamp,
		&lastReviewedAt,
	)
	if err == sql.ErrNoRows {
		return nil
	}
	if err != nil {
		return err
	}

	var total, correct, again, hard, good, easy int
	var lastRating sql.NullString
	err = tx.QueryRowContext(ctx, `
		SELECT
			COUNT(*) AS total_reviews,
			COUNT(*) FILTER (WHERE rating <> 'again') AS correct_reviews,
			COUNT(*) FILTER (WHERE rating = 'again') AS again_count,
			COUNT(*) FILTER (WHERE rating = 'hard') AS hard_count,
			COUNT(*) FILTER (WHERE rating = 'good') AS good_count,
			COUNT(*) FILTER (WHERE rating = 'easy') AS easy_count,
			(ARRAY_AGG(rating ORDER BY reviewed_at DESC, created_at DESC, id DESC))[1] AS last_rating
		FROM review_logs
		WHERE user_id = $1 AND card_id = $2
	`, userID, cardID).Scan(&total, &correct, &again, &hard, &good, &easy, &lastRating)
	if err != nil {
		return err
	}
	if total == 0 {
		_, err = tx.ExecContext(ctx, `DELETE FROM user_card_progress WHERE user_id = $1 AND card_id = $2`, userID, cardID)
		return err
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO user_card_progress (
			id, user_id, card_id, deck_id,
			total_reviews, correct_reviews,
			again_count, hard_count, good_count, easy_count,
			last_rating, current_interval, ease_factor, repetition_count,
			due_timestamp, last_reviewed_at,
			created_at, updated_at, version
		)
		VALUES (
			$1,$2,$3,$4,
			$5,$6,
			$7,$8,$9,$10,
			$11,$12,$13,$14,
			$15,$16,
			NOW(),NOW(),1
		)
		ON CONFLICT (user_id, card_id) DO UPDATE
		SET deck_id = EXCLUDED.deck_id,
		    total_reviews = EXCLUDED.total_reviews,
		    correct_reviews = EXCLUDED.correct_reviews,
		    again_count = EXCLUDED.again_count,
		    hard_count = EXCLUDED.hard_count,
		    good_count = EXCLUDED.good_count,
		    easy_count = EXCLUDED.easy_count,
		    last_rating = EXCLUDED.last_rating,
		    current_interval = EXCLUDED.current_interval,
		    ease_factor = EXCLUDED.ease_factor,
		    repetition_count = EXCLUDED.repetition_count,
		    due_timestamp = EXCLUDED.due_timestamp,
		    last_reviewed_at = EXCLUDED.last_reviewed_at,
		    updated_at = NOW(),
		    version = user_card_progress.version + 1
	`, uuid.New().String(), userID, cardID, deckID,
		total, correct,
		again, hard, good, easy,
		nullableString(lastRating), currentInterval, easeFactor, repetitionCount,
		nullableTime(dueTimestamp), nullableTime(lastReviewedAt),
	)
	return err
}

func nullableString(value sql.NullString) any {
	if !value.Valid {
		return nil
	}
	return value.String
}

func nullableTime(value sql.NullTime) any {
	if !value.Valid {
		return nil
	}
	return value.Time
}

func (r *ProgressRepository) RecomputeDeckProgress(ctx context.Context, tx txRunner, userID, deckID string) error {
	var total, correct int
	var lastReviewDate sql.NullTime
	err := tx.QueryRowContext(ctx, `
		SELECT
			COUNT(*) AS total_reviews,
			COUNT(*) FILTER (WHERE rl.rating <> 'again') AS correct_reviews,
			MAX(DATE(rl.reviewed_at)) AS last_review_date
		FROM review_logs rl
		JOIN cards c ON c.id = rl.card_id
		JOIN decks d ON d.id = c.deck_id
		WHERE rl.user_id = $1 AND c.deck_id = $2 AND d.user_id = $1
	`, userID, deckID).Scan(&total, &correct, &lastReviewDate)
	if err != nil {
		return err
	}

	rows, err := tx.QueryContext(ctx, `
		SELECT DISTINCT DATE(rl.reviewed_at) AS day
		FROM review_logs rl
		JOIN cards c ON c.id = rl.card_id
		JOIN decks d ON d.id = c.deck_id
		WHERE rl.user_id = $1 AND c.deck_id = $2 AND d.user_id = $1
		ORDER BY day ASC
	`, userID, deckID)
	if err != nil {
		return err
	}
	defer rows.Close()
	var days []time.Time
	for rows.Next() {
		var day time.Time
		if err := rows.Scan(&day); err != nil {
			return err
		}
		days = append(days, day.UTC())
	}
	if err := rows.Err(); err != nil {
		return err
	}
	currentStreak, longestStreak := computeStreaks(days, time.Now().UTC())

	if total == 0 {
		_, err = tx.ExecContext(ctx, `DELETE FROM user_progress WHERE user_id = $1 AND deck_id = $2`, userID, deckID)
		return err
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO user_progress (
			id, user_id, deck_id,
			total_reviews, correct_reviews,
			current_streak, longest_streak,
			last_review_date,
			updated_at, version
		)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,NOW(),1)
		ON CONFLICT (user_id, deck_id) DO UPDATE
		SET total_reviews = EXCLUDED.total_reviews,
		    correct_reviews = EXCLUDED.correct_reviews,
		    current_streak = EXCLUDED.current_streak,
		    longest_streak = EXCLUDED.longest_streak,
		    last_review_date = EXCLUDED.last_review_date,
		    updated_at = NOW(),
		    version = user_progress.version + 1
	`, uuid.New().String(), userID, deckID, total, correct, currentStreak, longestStreak, nullableTime(lastReviewDate))
	return err
}
