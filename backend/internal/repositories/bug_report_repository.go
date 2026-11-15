package repositories

import (
	"context"
	"database/sql"
)

const BugReportQuotaLock int64 = 1380266068

type reportMetadataExecutor interface {
	ExecContext(context.Context, string, ...any) (sql.Result, error)
}

// CleanupBugReportMetadata runs under BugReportQuotaLock, shared with reservations.
func CleanupBugReportMetadata(ctx context.Context, executor reportMetadataExecutor) error {
	if _, err := executor.ExecContext(ctx, "DELETE FROM bug_report_attempts WHERE attempted_at <= NOW() - INTERVAL '24 hours'"); err != nil {
		return err
	}
	_, err := executor.ExecContext(ctx, "DELETE FROM bug_report_submissions WHERE last_attempt_at < NOW() - INTERVAL '30 days'")
	return err
}
