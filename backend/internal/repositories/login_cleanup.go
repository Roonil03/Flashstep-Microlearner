package repositories

import (
	"context"
	"database/sql"

	"github.com/lib/pq"
)

const expiredDeletedUserPredicate = `u.is_deleted AND u.updated_at<=clock_timestamp()-interval '24 hours'`

// CleanupDeletedUsers removes explicitly deleted accounts after their 24-hour
// grace period. The existing foreign keys cascade their owned data; ordinary
// card/deck tombstones and accounts not marked deleted are unaffected.
func (r *UserRepository) CleanupDeletedUsers(ctx context.Context) error {
	// Hold selected account row locks through deletion, then recheck deletion
	// status and grace eligibility in a fresh READ COMMITTED statement.
	tx, err := r.DB.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
	if err != nil {
		return err
	}
	defer tx.Rollback()
	// Claim the replica lock before the one bounded candidate query, including
	// idle runs. Contention skips the scan; an empty result issues no DELETE.
	var locked bool
	if err := tx.QueryRowContext(ctx, `SELECT pg_try_advisory_xact_lock(130002,1)`).Scan(&locked); err != nil {
		return err
	}
	if !locked {
		return nil
	}
	rows, err := tx.QueryContext(ctx, `SELECT u.id FROM users u WHERE `+expiredDeletedUserPredicate+`
 ORDER BY u.updated_at,u.id LIMIT 100 FOR UPDATE OF u SKIP LOCKED`)
	if err != nil {
		return err
	}
	ids := make([]string, 0, 100)
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return err
		}
		ids = append(ids, id)
	}
	err = rows.Err()
	rows.Close()
	if err != nil {
		return err
	}
	if len(ids) == 0 {
		return nil
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM users u WHERE u.id=ANY($1::uuid[]) AND `+expiredDeletedUserPredicate, pq.Array(ids)); err != nil {
		return err
	}
	return tx.Commit()
}
