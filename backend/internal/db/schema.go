package db

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
)

// CheckSchema is read-only. Migrations are an operator-controlled deployment step;
// an old persistent volume must not look ready merely because PostgreSQL pings.
func CheckSchema(ctx context.Context, conn *sql.DB) error {
	rows, err := conn.QueryContext(ctx, `
		SELECT name FROM (
			SELECT table_name || '.' || column_name AS name
			FROM (VALUES
				('login_cleanup_days','user_id'), ('login_cleanup_days','last_day'),
				('purged_entities','receipt_id'), ('purged_entities','user_id'),
				('purged_entities','entity'), ('purged_entities','entity_id'),
				('purged_entities','parent_id'), ('purged_entities','purged_at'),
				('review_logs','deck_id'),
				('bug_report_submissions','id'), ('bug_report_submissions','user_id'),
				('bug_report_submissions','content_hash'), ('bug_report_submissions','status'),
				('bug_report_submissions','attempts'), ('bug_report_submissions','created_at'),
				('bug_report_submissions','last_attempt_at'),
				('bug_report_attempts','submission_id'), ('bug_report_attempts','attempted_at')
			) AS required(table_name,column_name)
			WHERE NOT EXISTS (SELECT 1 FROM pg_attribute
				WHERE attrelid=to_regclass(required.table_name)
				AND attname=required.column_name AND attnum>0 AND NOT attisdropped)
			UNION ALL
			SELECT name FROM (VALUES ('idx_purged_entities_user_receipt'),
				('idx_review_logs_user_deck'), ('bug_reports_last_attempt_idx'),
				('bug_report_attempts_time_idx')) AS required(name)
			WHERE to_regclass(name) IS NULL
			UNION ALL
			SELECT 'review_logs.trg_review_history_owner'
			WHERE NOT EXISTS (SELECT 1 FROM pg_trigger t JOIN pg_proc p ON p.oid=t.tgfoid
				WHERE t.tgrelid=to_regclass('review_logs') AND t.tgname='trg_review_history_owner'
				AND NOT t.tgisinternal AND t.tgenabled IN ('O','A')
				AND p.proname='validate_review_history_owner')
			UNION ALL
			SELECT 'review_logs must preserve history without a cards foreign key'
			WHERE EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid=to_regclass('review_logs')
				AND confrelid=to_regclass('cards') AND contype='f')
		) AS missing ORDER BY name`)
	if err != nil {
		return fmt.Errorf("cannot verify database schema readiness: %w", err)
	}
	defer rows.Close()
	var missing []string
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			return fmt.Errorf("cannot verify database schema readiness: %w", err)
		}
		missing = append(missing, name)
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("cannot verify database schema readiness: %w", err)
	}
	if len(missing) > 0 {
		return fmt.Errorf("database schema is not ready for v1.3.0: %s; back up this database, apply backend/migrations/01_init.sql for a fresh database, then backend/migrations/02_daily_login_purge.sql and backend/migrations/02_bug_reports.sql to this same database, and restart the server (startup never runs migrations)", strings.Join(missing, ", "))
	}
	return nil
}
