package maintenance

import (
	"context"
	"database/sql"
	"log"
	"time"

	"backend/internal/repositories"
)

// StartBugReportCleanup expires metadata even when no new reports are submitted.
func StartBugReportCleanup(db *sql.DB) {
	go func() {
		ticker := time.NewTicker(time.Hour)
		defer ticker.Stop()
		for {
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			err := cleanupBugReports(ctx, db)
			cancel()
			if err != nil {
				log.Printf("bug report metadata cleanup failed: error_type=%T", err)
			}
			<-ticker.C
		}
	}()
}

func cleanupBugReports(ctx context.Context, db *sql.DB) error {
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err = tx.ExecContext(ctx, "SELECT pg_advisory_xact_lock($1)", repositories.BugReportQuotaLock); err != nil {
		return err
	}
	if err = repositories.CleanupBugReportMetadata(ctx, tx); err != nil {
		return err
	}
	return tx.Commit()
}
