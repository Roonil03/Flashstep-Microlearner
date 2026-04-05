package services

import (
	"context"
	"time"

	"backend/internal/models"
	"backend/internal/repositories"
)

type AnalyticsService struct {
	repo *repositories.AnalyticsRepository
}

func NewAnalyticsService(repo *repositories.AnalyticsRepository) *AnalyticsService {
	return &AnalyticsService{repo: repo}
}

func (s *AnalyticsService) DailyReviewCount(ctx context.Context, userID string, from, to time.Time) ([]models.DailyReviewCount, error) {
	return s.repo.DailyReviewCount(ctx, userID, from, to)
}

func (s *AnalyticsService) AccuracyTrends(ctx context.Context, userID string, from, to time.Time) ([]models.AccuracyTrend, error) {
	return s.repo.AccuracyTrends(ctx, userID, from, to)
}

func (s *AnalyticsService) DeckPerformance(ctx context.Context, userID, deckID string) (models.DeckPerformance, error) {
	return s.repo.DeckPerformance(ctx, userID, deckID)
}

func (s *AnalyticsService) AverageSessionLength(ctx context.Context, userID string, from, to time.Time) (float64, error) {
	return s.repo.AverageSessionLength(ctx, userID, from, to)
}

func (s *AnalyticsService) Dashboard(ctx context.Context, userID string, rangeDays int) (models.AnalyticsDashboard, error) {
	return s.repo.Dashboard(ctx, userID, rangeDays)
}

func (s *AnalyticsService) RefreshAllAnalytics(ctx context.Context, asOf time.Time) error {
	return s.repo.RefreshAllUsersAnalytics(ctx, asOf)
}
