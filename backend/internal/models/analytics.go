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
