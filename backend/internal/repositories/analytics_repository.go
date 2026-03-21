package repositories

import (
	"context"
	"database/sql"
	"time"

	"backend/internal/models"
)

type AnalyticsRepository struct {
	DB *sql.DB
}

func NewAnalyticsRepository(db *sql.DB) *AnalyticsRepository {
	return &AnalyticsRepository{DB: db}
}

func (r *AnalyticsRepository) DailyReviewCount(ctx context.Context, userID string, from, to time.Time) ([]models.DailyReviewCount, error) {
	rows, err := r.DB.QueryContext(ctx, `
		SELECT DATE(reviewed_at) AS day, COUNT(*) AS count
		FROM review_logs
		WHERE user_id = $1
		  AND reviewed_at >= $2
		  AND reviewed_at <= $3
		GROUP BY DATE(reviewed_at)
		ORDER BY day ASC
	`, userID, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.DailyReviewCount
	for rows.Next() {
		var item models.DailyReviewCount
		if err := rows.Scan(&item.Date, &item.Count); err != nil {
			return nil, err
		}
		out = append(out, item)
	}
	return out, rows.Err()
}

func (r *AnalyticsRepository) AccuracyTrends(ctx context.Context, userID string, from, to time.Time) ([]models.AccuracyTrend, error) {
	rows, err := r.DB.QueryContext(ctx, `
		SELECT
			DATE(reviewed_at) AS day,
			COUNT(*) AS reviewed,
			COUNT(*) FILTER (WHERE rating IN ('good', 'easy')) AS correct
		FROM review_logs
		WHERE user_id = $1
		  AND reviewed_at >= $2
		  AND reviewed_at <= $3
		GROUP BY DATE(reviewed_at)
		ORDER BY day ASC
	`, userID, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.AccuracyTrend
	for rows.Next() {
		var item models.AccuracyTrend
		if err := rows.Scan(&item.Date, &item.Reviewed, &item.Correct); err != nil {
			return nil, err
		}
		if item.Reviewed > 0 {
			item.Accuracy = float64(item.Correct) / float64(item.Reviewed)
		}
		out = append(out, item)
	}
	return out, rows.Err()
}

func (r *AnalyticsRepository) DeckPerformance(ctx context.Context, userID, deckID string) (models.DeckPerformance, error) {
	var out models.DeckPerformance
	err := r.DB.QueryRowContext(ctx, `
		SELECT
			d.id,
			d.title,
			COUNT(rl.id) AS total_reviews,
			COUNT(*) FILTER (WHERE rl.rating IN ('good', 'easy')) AS correct_reviews,
			COALESCE(up.current_streak, 0) AS current_streak,
			COALESCE(up.longest_streak, 0) AS longest_streak
		FROM decks d
		LEFT JOIN cards c ON c.deck_id = d.id AND c.is_deleted = false
		LEFT JOIN review_logs rl ON rl.card_id = c.id
		LEFT JOIN user_progress up ON up.deck_id = d.id AND up.user_id = d.user_id
		WHERE d.id = $1
		  AND d.user_id = $2
		  AND d.is_deleted = false
		GROUP BY d.id, d.title, up.current_streak, up.longest_streak
	`, deckID, userID).Scan(
		&out.DeckID,
		&out.DeckTitle,
		&out.TotalReviews,
		&out.CorrectReviews,
		&out.CurrentStreak,
		&out.LongestStreak,
	)
	if err != nil {
		return models.DeckPerformance{}, err
	}
	if out.TotalReviews > 0 {
		out.Accuracy = float64(out.CorrectReviews) / float64(out.TotalReviews)
	}
	return out, nil
}

func (r *AnalyticsRepository) AverageSessionLength(ctx context.Context, userID string, from, to time.Time) (float64, error) {
	var avg sql.NullFloat64
	err := r.DB.QueryRowContext(ctx, `
		SELECT AVG(day_count)::float8
		FROM (
			SELECT COUNT(*) AS day_count
			FROM review_logs
			WHERE user_id = $1
			  AND reviewed_at >= $2
			  AND reviewed_at <= $3
			GROUP BY DATE(reviewed_at)
		) t
	`, userID, from, to).Scan(&avg)
	if err != nil {
		return 0, err
	}
	if !avg.Valid {
		return 0, nil
	}
	return avg.Float64, nil
}
