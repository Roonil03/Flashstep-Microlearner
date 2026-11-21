package maintenance

import (
	"context"
	"database/sql"
	"log"
	"time"

	"backend/internal/repositories"
)

const (
	accountCleanupInterval = 15 * time.Minute
	accountCleanupDelay    = 2 * time.Second
	accountCleanupTimeout  = 5 * time.Second
)

// DeletedAccountCleanup coalesces API activity into bounded background checks.
// It never scans the database at startup or in a request.
type DeletedAccountCleanup struct {
	activity chan struct{}
}

func StartDeletedAccountCleanup(ctx context.Context, db *sql.DB) *DeletedAccountCleanup {
	worker := &DeletedAccountCleanup{activity: make(chan struct{}, 1)}
	repo := repositories.NewUserRepository(db)
	go worker.run(ctx, repo.CleanupDeletedUsers, accountCleanupDelay, accountCleanupInterval)
	return worker
}

// NotifyActivity does no database work and never waits for the worker.
func (w *DeletedAccountCleanup) NotifyActivity() {
	select {
	case w.activity <- struct{}{}:
	default:
	}
}

func (w *DeletedAccountCleanup) run(ctx context.Context, cleanup func(context.Context) error, delay, interval time.Duration) {
	// This cooldown is intentionally process-local. A restart permits one cheap
	// eligibility check after real traffic; it does not perform a startup sweep.
	var nextRun time.Time
	for {
		select {
		case <-ctx.Done():
			return
		case <-w.activity:
		}
		if time.Now().Before(nextRun) {
			continue
		}
		timer := time.NewTimer(delay)
		select {
		case <-ctx.Done():
			timer.Stop()
			return
		case <-timer.C:
		}
		nextRun = time.Now().Add(interval)
		runCtx, cancel := context.WithTimeout(ctx, accountCleanupTimeout)
		if err := cleanup(runCtx); err != nil && ctx.Err() == nil {
			log.Printf("deleted account cleanup failed: %v", err)
		}
		cancel()
	}
}
