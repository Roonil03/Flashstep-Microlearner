package maintenance

import (
	"context"
	"database/sql"
	"log"
	"time"

	"backend/internal/repositories"
)

func StartAnalyticsAggregation(db *sql.DB) {
	repo := repositories.NewAnalyticsRepository(db)

	go func() {
		if err := repo.RefreshAllUsersAnalytics(context.Background(), time.Now().UTC()); err != nil {
			log.Printf("initial analytics refresh failed: %v", err)
		}
		for {
			now := time.Now().UTC()
			nextRun := time.Date(now.Year(), now.Month(), now.Day()+1, 0, 0, 0, 0, time.UTC)
			timer := time.NewTimer(time.Until(nextRun))
			<-timer.C
			timer.Stop()

			if err := repo.RefreshAllUsersAnalytics(context.Background(), nextRun); err != nil {
				log.Printf("analytics aggregation failed: %v", err)
				continue
			}
			log.Printf("analytics aggregation refreshed at %s", nextRun.Format(time.RFC3339))
		}
	}()
}
