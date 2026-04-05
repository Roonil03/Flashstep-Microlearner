package models

import "time"

type DailyReviewCount struct {
	Date  time.Time `json:"date"`
	Count int       `json:"count"`
}

type AccuracyTrend struct {
	Date     time.Time `json:"date"`
	Reviewed int       `json:"reviewed"`
	Correct  int       `json:"correct"`
	Accuracy float64   `json:"accuracy"`
}

type AverageSessionLength struct {
	Date           time.Time `json:"date"`
	SessionCount   int       `json:"session_count"`
	AverageReviews float64   `json:"average_reviews"`
}

type DeckPerformance struct {
	DeckID         string  `json:"deck_id"`
	DeckTitle      string  `json:"deck_title"`
	TotalReviews   int     `json:"total_reviews"`
	CorrectReviews int     `json:"correct_reviews"`
	Accuracy       float64 `json:"accuracy"`
	CurrentStreak  int     `json:"current_streak"`
	LongestStreak  int     `json:"longest_streak"`
}

type RatingBreakdown struct {
	Again int `json:"again"`
	Hard  int `json:"hard"`
	Good  int `json:"good"`
	Easy  int `json:"easy"`
}

type DeckAnalyticsInsight struct {
	DeckID       string  `json:"deck_id"`
	Title        string  `json:"title"`
	TotalCards   int     `json:"total_cards"`
	DueCards     int     `json:"due_cards"`
	ReviewedCount int    `json:"reviewed_count"`
	CorrectCount int     `json:"correct_count"`
	MatureCards  int     `json:"mature_cards"`
	Accuracy     float64 `json:"accuracy"`
}

type AnalyticsDashboard struct {
	Username          string                 `json:"username"`
	RangeDays         int                    `json:"range_days"`
	GeneratedAt       time.Time              `json:"generated_at"`
	TotalDecks        int                    `json:"total_decks"`
	TotalCards        int                    `json:"total_cards"`
	LearnedCards      int                    `json:"learned_cards"`
	MatureCards       int                    `json:"mature_cards"`
	NewCards          int                    `json:"new_cards"`
	LearningCards     int                    `json:"learning_cards"`
	ReviewCards       int                    `json:"review_cards"`
	DueNow            int                    `json:"due_now"`
	DueNext24Hours    int                    `json:"due_next_24_hours"`
	ReviewsToday      int                    `json:"reviews_today"`
	ReviewsInRange    int                    `json:"reviews_in_range"`
	ActiveDaysInRange int                    `json:"active_days_in_range"`
	AverageStudyLoad  float64                `json:"average_study_load"`
	RetentionRate     float64                `json:"retention_rate"`
	CurrentStreak     int                    `json:"current_streak"`
	BestDayCount      int                    `json:"best_day_count"`
	LongestIntervalDays float64              `json:"longest_interval_days"`
	RatingBreakdown   RatingBreakdown        `json:"rating_breakdown"`
	ReviewActivity    []DailyReviewCount     `json:"review_activity"`
	AccuracyTrend     []AccuracyTrend        `json:"accuracy_trend"`
	DeckInsights      []DeckAnalyticsInsight `json:"deck_insights"`
}
