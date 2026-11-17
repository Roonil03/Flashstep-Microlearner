package db

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
)

// CheckSchema only verifies the existing main schema. Startup never changes DDL.
func CheckSchema(ctx context.Context, conn *sql.DB) error {
	rows, err := conn.QueryContext(ctx, `SELECT table_name||'.'||column_name FROM (VALUES
 ('users','is_deleted'),('users','updated_at'),('users','password_hash'),
 ('decks','user_id'),('decks','is_deleted'),('decks','updated_at'),
 ('cards','deck_id'),('cards','is_deleted'),('cards','updated_at'),
 ('review_logs','card_id'),('review_logs','user_id'),('review_logs','created_at'),
 ('user_progress','deck_id'),('user_card_progress','card_id'),
 ('analytics_daily_stats','day'),('analytics_rollups','window_days')
 ) required(table_name,column_name) WHERE NOT EXISTS(SELECT 1 FROM pg_attribute
 WHERE attrelid=to_regclass(required.table_name) AND attname=required.column_name
 AND attnum>0 AND NOT attisdropped) ORDER BY table_name,column_name`)
	if err != nil {
		return fmt.Errorf("cannot verify database schema readiness: %w", err)
	}
	defer rows.Close()
	missing := []string{}
	for rows.Next() {
		var name string
		if err = rows.Scan(&name); err != nil {
			return err
		}
		missing = append(missing, name)
	}
	if err = rows.Err(); err != nil {
		return err
	}
	if len(missing) > 0 {
		return fmt.Errorf("database schema is not ready: %s; apply the existing backend/migrations/01_init.sql for a fresh database (startup never runs migrations)", strings.Join(missing, ", "))
	}
	return nil
}
