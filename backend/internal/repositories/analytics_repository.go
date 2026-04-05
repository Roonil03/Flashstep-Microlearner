package repositories

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"sort"
	"time"

	"backend/internal/models"
)

type AnalyticsRepository struct {
	DB *sql.DB
}

func NewAnalyticsRepository(db *sql.DB) *AnalyticsRepository {
	return &AnalyticsRepository{DB: db}
}

func utcDay(t time.Time) time.Time {
	u := t.UTC()
	return time.Date(u.Year(), u.Month(), u.Day(), 0, 0, 0, 0, time.UTC)
}

func (r *AnalyticsRepository) DailyReviewCount(ctx context.Context, userID string, from, to time.Time) ([]models.DailyReviewCount, error) {
	if err := r.RefreshUserAnalytics(ctx, userID, time.Now().UTC()); err != nil {
		return nil, err
	}
	rows, err := r.DB.QueryContext(ctx, `
		SELECT day, reviews_count
		FROM analytics_daily_stats
		WHERE user_id = $1
		  AND day >= $2::date
		  AND day <= $3::date
		ORDER BY day ASC
	`, userID, utcDay(from), utcDay(to))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make([]models.DailyReviewCount, 0)
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
	if err := r.RefreshUserAnalytics(ctx, userID, time.Now().UTC()); err != nil {
		return nil, err
	}
	rows, err := r.DB.QueryContext(ctx, `
		SELECT day, reviews_count, correct_count
		FROM analytics_daily_stats
		WHERE user_id = $1
		  AND day >= $2::date
		  AND day <= $3::date
		ORDER BY day ASC
	`, userID, utcDay(from), utcDay(to))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make([]models.AccuracyTrend, 0)
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
	if err := r.RefreshUserAnalytics(ctx, userID, time.Now().UTC()); err != nil {
		return out, err
	}
	err := r.DB.QueryRowContext(ctx, `
		SELECT
			d.id,
			d.title,
			COALESCE(up.total_reviews, 0) AS total_reviews,
			COALESCE(up.correct_reviews, 0) AS correct_reviews,
			COALESCE(up.current_streak, 0) AS current_streak,
			COALESCE(up.longest_streak, 0) AS longest_streak
		FROM decks d
		LEFT JOIN user_progress up ON up.deck_id = d.id AND up.user_id = d.user_id
		WHERE d.id = $1
		  AND d.user_id = $2
		  AND d.is_deleted = false
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
	if err := r.RefreshUserAnalytics(ctx, userID, time.Now().UTC()); err != nil {
		return 0, err
	}
	var avg sql.NullFloat64
	err := r.DB.QueryRowContext(ctx, `
		SELECT AVG(reviews_count)::float8
		FROM analytics_daily_stats
		WHERE user_id = $1
		  AND day >= $2::date
		  AND day <= $3::date
		  AND reviews_count > 0
	`, userID, utcDay(from), utcDay(to)).Scan(&avg)
	if err != nil {
		return 0, err
	}
	if !avg.Valid {
		return 0, nil
	}
	return avg.Float64, nil
}

func (r *AnalyticsRepository) Dashboard(ctx context.Context, userID string, rangeDays int) (models.AnalyticsDashboard, error) {
	if rangeDays != 7 && rangeDays != 30 && rangeDays != 90 {
		rangeDays = 30
	}
	asOf := utcDay(time.Now().UTC())
	if err := r.RefreshUserAnalytics(ctx, userID, asOf); err != nil {
		return models.AnalyticsDashboard{}, err
	}

	var dash models.AnalyticsDashboard
	var username string
	var totalDecks, totalCards, learnedCards, matureCards, newCards, learningCards, reviewCards int
	var dueNow, dueNext24Hours int
	var longestInterval sql.NullFloat64
	future := time.Now().UTC().Add(24 * time.Hour)

	err := r.DB.QueryRowContext(ctx, `
		SELECT
			u.username,
			COUNT(DISTINCT d.id) FILTER (WHERE d.is_deleted = false) AS total_decks,
			COUNT(c.id) FILTER (WHERE d.is_deleted = false AND c.is_deleted = false) AS total_cards,
			COUNT(c.id) FILTER (WHERE d.is_deleted = false AND c.is_deleted = false AND (c.repetition_count > 0 OR c.last_reviewed_at IS NOT NULL)) AS learned_cards,
			COUNT(c.id) FILTER (WHERE d.is_deleted = false AND c.is_deleted = false AND c.interval >= 21) AS mature_cards,
			COUNT(c.id) FILTER (WHERE d.is_deleted = false AND c.is_deleted = false AND c.state = 'new') AS new_cards,
			COUNT(c.id) FILTER (WHERE d.is_deleted = false AND c.is_deleted = false AND c.state = 'learning') AS learning_cards,
			COUNT(c.id) FILTER (WHERE d.is_deleted = false AND c.is_deleted = false AND c.state = 'review') AS review_cards,
			COUNT(c.id) FILTER (WHERE d.is_deleted = false AND c.is_deleted = false AND c.due_timestamp IS NOT NULL AND c.due_timestamp <= $2) AS due_now,
			COUNT(c.id) FILTER (WHERE d.is_deleted = false AND c.is_deleted = false AND c.due_timestamp IS NOT NULL AND c.due_timestamp <= $3) AS due_next_24_hours,
			MAX(c.interval) FILTER (WHERE d.is_deleted = false AND c.is_deleted = false) AS longest_interval_days
		FROM users u
		LEFT JOIN decks d ON d.user_id = u.id
		LEFT JOIN cards c ON c.deck_id = d.id
		WHERE u.id = $1 AND u.is_deleted = false
		GROUP BY u.username
	`, userID, time.Now().UTC(), future).Scan(
		&username,
		&totalDecks,
		&totalCards,
		&learnedCards,
		&matureCards,
		&newCards,
		&learningCards,
		&reviewCards,
		&dueNow,
		&dueNext24Hours,
		&longestInterval,
	)
	if err != nil {
		return models.AnalyticsDashboard{}, err
	}

	var reviewsToday, reviewsInRange, activeDaysInRange, bestDayCount int
	var averageStudyLoad, retentionRate float64
	var againCount, hardCount, goodCount, easyCount int
	var reviewActivityRaw, accuracyTrendRaw []byte
	err = r.DB.QueryRowContext(ctx, `
		SELECT
			reviews_today,
			reviews_count,
			active_days,
			average_study_load,
			best_day_count,
			again_count,
			hard_count,
			good_count,
			easy_count,
			review_activity,
			accuracy_trend,
			CASE WHEN reviews_count = 0 THEN 0 ELSE correct_count::float8 / reviews_count END AS retention_rate
		FROM analytics_rollups
		WHERE user_id = $1 AND window_days = $2
	`, userID, rangeDays).Scan(
		&reviewsToday,
		&reviewsInRange,
		&activeDaysInRange,
		&averageStudyLoad,
		&bestDayCount,
		&againCount,
		&hardCount,
		&goodCount,
		&easyCount,
		&reviewActivityRaw,
		&accuracyTrendRaw,
		&retentionRate,
	)
	if err != nil {
		if err != sql.ErrNoRows {
			return models.AnalyticsDashboard{}, err
		}
	}

	reviewActivity := make([]models.DailyReviewCount, 0)
	if len(reviewActivityRaw) > 0 {
		_ = json.Unmarshal(reviewActivityRaw, &reviewActivity)
	}
	accuracyTrend := make([]models.AccuracyTrend, 0)
	if len(accuracyTrendRaw) > 0 {
		_ = json.Unmarshal(accuracyTrendRaw, &accuracyTrend)
	}

	currentStreak, _ := r.userCurrentStreak(ctx, userID)
	deckInsights, err := r.deckInsights(ctx, userID)
	if err != nil {
		return models.AnalyticsDashboard{}, err
	}

	dash = models.AnalyticsDashboard{
		Username:            username,
		RangeDays:           rangeDays,
		GeneratedAt:         time.Now().UTC(),
		TotalDecks:          totalDecks,
		TotalCards:          totalCards,
		LearnedCards:        learnedCards,
		MatureCards:         matureCards,
		NewCards:            newCards,
		LearningCards:       learningCards,
		ReviewCards:         reviewCards,
		DueNow:              dueNow,
		DueNext24Hours:      dueNext24Hours,
		ReviewsToday:        reviewsToday,
		ReviewsInRange:      reviewsInRange,
		ActiveDaysInRange:   activeDaysInRange,
		AverageStudyLoad:    averageStudyLoad,
		RetentionRate:       retentionRate,
		CurrentStreak:       currentStreak,
		BestDayCount:        bestDayCount,
		LongestIntervalDays: longestInterval.Float64,
		RatingBreakdown: models.RatingBreakdown{
			Again: againCount,
			Hard:  hardCount,
			Good:  goodCount,
			Easy:  easyCount,
		},
		ReviewActivity: reviewActivity,
		AccuracyTrend:  accuracyTrend,
		DeckInsights:   deckInsights,
	}
	return dash, nil
}

func (r *AnalyticsRepository) userCurrentStreak(ctx context.Context, userID string) (int, error) {
	rows, err := r.DB.QueryContext(ctx, `
		SELECT DISTINCT DATE(reviewed_at) AS day
		FROM review_logs
		WHERE user_id = $1
		ORDER BY day DESC
	`, userID)
	if err != nil {
		return 0, err
	}
	defer rows.Close()
	var days []time.Time
	for rows.Next() {
		var day time.Time
		if err := rows.Scan(&day); err != nil {
			return 0, err
		}
		days = append(days, utcDay(day))
	}
	if err := rows.Err(); err != nil {
		return 0, err
	}
	if len(days) == 0 {
		return 0, nil
	}
	today := utcDay(time.Now().UTC())
	if !days[0].Equal(today) {
		return 0, nil
	}
	streak := 1
	for i := 1; i < len(days); i++ {
		expected := days[i-1].AddDate(0, 0, -1)
		if days[i].Equal(expected) {
			streak++
			continue
		}
		break
	}
	return streak, nil
}

func (r *AnalyticsRepository) deckInsights(ctx context.Context, userID string) ([]models.DeckAnalyticsInsight, error) {
	rows, err := r.DB.QueryContext(ctx, `
		SELECT
			d.id,
			d.title,
			COUNT(c.id) FILTER (WHERE c.is_deleted = false) AS total_cards,
			COUNT(c.id) FILTER (WHERE c.is_deleted = false AND c.due_timestamp IS NOT NULL AND c.due_timestamp <= $2) AS due_cards,
			COALESCE(up.total_reviews, 0) AS reviewed_count,
			COALESCE(up.correct_reviews, 0) AS correct_count,
			COUNT(c.id) FILTER (WHERE c.is_deleted = false AND c.interval >= 21) AS mature_cards
		FROM decks d
		LEFT JOIN cards c ON c.deck_id = d.id
		LEFT JOIN user_progress up ON up.user_id = $1 AND up.deck_id = d.id
		WHERE d.user_id = $1
		  AND d.is_deleted = false
		GROUP BY d.id, d.title, up.total_reviews, up.correct_reviews
		ORDER BY due_cards DESC, reviewed_count DESC, d.title ASC
	`, userID, time.Now().UTC())
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make([]models.DeckAnalyticsInsight, 0)
	for rows.Next() {
		var item models.DeckAnalyticsInsight
		if err := rows.Scan(
			&item.DeckID,
			&item.Title,
			&item.TotalCards,
			&item.DueCards,
			&item.ReviewedCount,
			&item.CorrectCount,
			&item.MatureCards,
		); err != nil {
			return nil, err
		}
		if item.ReviewedCount > 0 {
			item.Accuracy = float64(item.CorrectCount) / float64(item.ReviewedCount)
		}
		out = append(out, item)
	}
	return out, rows.Err()
}

func (r *AnalyticsRepository) RefreshUserAnalytics(ctx context.Context, userID string, asOf time.Time) error {
	asOf = utcDay(asOf)
	from := asOf.AddDate(0, 0, -89)
	windowDays := []int{7, 30, 90}

	tx, err := r.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	if _, err := tx.ExecContext(ctx, `
		DELETE FROM analytics_daily_stats
		WHERE user_id = $1
		  AND day >= $2::date
		  AND day <= $3::date
	`, userID, from, asOf); err != nil {
		return err
	}

	if _, err := tx.ExecContext(ctx, `
		INSERT INTO analytics_daily_stats (
			user_id, day,
			reviews_count, correct_count,
			again_count, hard_count, good_count, easy_count,
			distinct_cards_reviewed, average_previous_interval, average_new_interval,
			created_at, updated_at
		)
		SELECT
			$1,
			DATE(reviewed_at) AS day,
			COUNT(*) AS reviews_count,
			COUNT(*) FILTER (WHERE rating <> 'again') AS correct_count,
			COUNT(*) FILTER (WHERE rating = 'again') AS again_count,
			COUNT(*) FILTER (WHERE rating = 'hard') AS hard_count,
			COUNT(*) FILTER (WHERE rating = 'good') AS good_count,
			COUNT(*) FILTER (WHERE rating = 'easy') AS easy_count,
			COUNT(DISTINCT card_id) AS distinct_cards_reviewed,
			COALESCE(AVG(previous_interval), 0) AS average_previous_interval,
			COALESCE(AVG(new_interval), 0) AS average_new_interval,
			NOW(),
			NOW()
		FROM review_logs
		WHERE user_id = $1
		  AND reviewed_at >= $2::timestamptz
		  AND reviewed_at < ($3::date + INTERVAL '1 day')
		GROUP BY DATE(reviewed_at)
	`, userID, from, asOf); err != nil {
		return err
	}

	for _, days := range windowDays {
		windowFrom := asOf.AddDate(0, 0, -(days - 1))
		if err := r.upsertRollup(ctx, tx, userID, days, windowFrom, asOf); err != nil {
			return err
		}
	}

	if err := tx.Commit(); err != nil {
		return err
	}
	return nil
}

func (r *AnalyticsRepository) RefreshAllUsersAnalytics(ctx context.Context, asOf time.Time) error {
	rows, err := r.DB.QueryContext(ctx, `SELECT id FROM users WHERE is_deleted = false`)
	if err != nil {
		return err
	}
	defer rows.Close()
	userIDs := make([]string, 0)
	for rows.Next() {
		var userID string
		if err := rows.Scan(&userID); err != nil {
			return err
		}
		userIDs = append(userIDs, userID)
	}
	if err := rows.Err(); err != nil {
		return err
	}
	for _, userID := range userIDs {
		if err := r.RefreshUserAnalytics(ctx, userID, asOf); err != nil {
			return fmt.Errorf("refresh analytics for user %s: %w", userID, err)
		}
	}
	return nil
}

func (r *AnalyticsRepository) upsertRollup(ctx context.Context, tx *sql.Tx, userID string, windowDays int, from, to time.Time) error {
	var reviewActivityRaw []byte
	var accuracyTrendRaw []byte
	var reviewsCount, correctCount, activeDays, reviewsToday, bestDayCount int
	var againCount, hardCount, goodCount, easyCount int
	var averageStudyLoad float64

	seriesRows, err := tx.QueryContext(ctx, `
		SELECT gs.day::date,
		       COALESCE(ds.reviews_count, 0) AS reviews_count,
		       COALESCE(ds.correct_count, 0) AS correct_count,
		       COALESCE(ds.again_count, 0) AS again_count,
		       COALESCE(ds.hard_count, 0) AS hard_count,
		       COALESCE(ds.good_count, 0) AS good_count,
		       COALESCE(ds.easy_count, 0) AS easy_count
		FROM generate_series($2::date, $3::date, INTERVAL '1 day') AS gs(day)
		LEFT JOIN analytics_daily_stats ds
		  ON ds.user_id = $1
		 AND ds.day = gs.day::date
		ORDER BY gs.day ASC
	`, userID, from, to)
	if err != nil {
		return err
	}
	defer seriesRows.Close()

	reviewActivity := make([]models.DailyReviewCount, 0, windowDays)
	accuracyTrend := make([]models.AccuracyTrend, 0, windowDays)
	for seriesRows.Next() {
		var day time.Time
		var reviews, correct, again, hard, good, easy int
		if err := seriesRows.Scan(&day, &reviews, &correct, &again, &hard, &good, &easy); err != nil {
			return err
		}
		reviewActivity = append(reviewActivity, models.DailyReviewCount{Date: utcDay(day), Count: reviews})
		acc := 0.0
		if reviews > 0 {
			acc = float64(correct) / float64(reviews)
			activeDays++
			averageStudyLoad += float64(reviews)
		}
		accuracyTrend = append(accuracyTrend, models.AccuracyTrend{Date: utcDay(day), Reviewed: reviews, Correct: correct, Accuracy: acc})
		reviewsCount += reviews
		correctCount += correct
		againCount += again
		hardCount += hard
		goodCount += good
		easyCount += easy
		if reviews > bestDayCount {
			bestDayCount = reviews
		}
		if utcDay(day).Equal(to) {
			reviewsToday = reviews
		}
	}
	if err := seriesRows.Err(); err != nil {
		return err
	}
	if activeDays > 0 {
		averageStudyLoad = averageStudyLoad / float64(activeDays)
	}
	if reviewActivityRaw, err = json.Marshal(reviewActivity); err != nil {
		return err
	}
	if accuracyTrendRaw, err = json.Marshal(accuracyTrend); err != nil {
		return err
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO analytics_rollups (
			user_id, window_days, from_date, to_date,
			reviews_count, correct_count, active_days, average_study_load,
			reviews_today, best_day_count,
			again_count, hard_count, good_count, easy_count,
			review_activity, accuracy_trend,
			computed_at, created_at, updated_at
		)
		VALUES (
			$1,$2,$3::date,$4::date,
			$5,$6,$7,$8,
			$9,$10,
			$11,$12,$13,$14,
			$15::jsonb,$16::jsonb,
			NOW(),NOW(),NOW()
		)
		ON CONFLICT (user_id, window_days) DO UPDATE
		SET from_date = EXCLUDED.from_date,
		    to_date = EXCLUDED.to_date,
		    reviews_count = EXCLUDED.reviews_count,
		    correct_count = EXCLUDED.correct_count,
		    active_days = EXCLUDED.active_days,
		    average_study_load = EXCLUDED.average_study_load,
		    reviews_today = EXCLUDED.reviews_today,
		    best_day_count = EXCLUDED.best_day_count,
		    again_count = EXCLUDED.again_count,
		    hard_count = EXCLUDED.hard_count,
		    good_count = EXCLUDED.good_count,
		    easy_count = EXCLUDED.easy_count,
		    review_activity = EXCLUDED.review_activity,
		    accuracy_trend = EXCLUDED.accuracy_trend,
		    computed_at = EXCLUDED.computed_at,
		    updated_at = NOW()
	`, userID, windowDays, from, to,
		reviewsCount, correctCount, activeDays, averageStudyLoad,
		reviewsToday, bestDayCount,
		againCount, hardCount, goodCount, easyCount,
		string(reviewActivityRaw), string(accuracyTrendRaw),
	)
	return err
}

func computeStreaks(days []time.Time, today time.Time) (current int, longest int) {
	if len(days) == 0 {
		return 0, 0
	}
	sort.Slice(days, func(i, j int) bool { return days[i].Before(days[j]) })
	longest = 1
	run := 1
	for i := 1; i < len(days); i++ {
		prev := utcDay(days[i-1])
		curr := utcDay(days[i])
		delta := int(curr.Sub(prev).Hours() / 24)
		if delta == 1 {
			run++
			if run > longest {
				longest = run
			}
		} else if delta > 1 {
			run = 1
		}
	}
	daySet := map[time.Time]struct{}{}
	for _, day := range days {
		daySet[utcDay(day)] = struct{}{}
	}
	current = 0
	cursor := utcDay(today)
	for {
		if _, ok := daySet[cursor]; !ok {
			break
		}
		current++
		cursor = cursor.AddDate(0, 0, -1)
	}
	return current, longest
}
