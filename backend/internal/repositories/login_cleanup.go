package repositories

import (
	"context"
	"time"
)

// CleanupOnLogin runs once per UTC day after credentials have been verified.
// The marker, durable receipts and physical deletion commit together. Failed
// transactions are retried on the next login; they never consume the day.
func (r *UserRepository) CleanupOnLogin(ctx context.Context, userID string, now time.Time) error {
	tx, err := r.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	// Same lock as sync upload: an offline upsert cannot race a purge.
	if _, err = tx.ExecContext(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, userID); err != nil {
		return err
	}
	result, err := tx.ExecContext(ctx, `INSERT INTO login_cleanup_days(user_id,last_day) VALUES($1,$2::date)
        ON CONFLICT(user_id) DO UPDATE SET last_day=EXCLUDED.last_day
        WHERE login_cleanup_days.last_day<EXCLUDED.last_day`, userID, now.UTC().Format("2006-01-02"))
	if err != nil {
		return err
	}
	changed, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if changed == 0 {
		return tx.Commit()
	}
	var candidates bool
	if err = tx.QueryRowContext(ctx, `SELECT EXISTS(SELECT 1 FROM decks WHERE user_id=$1 AND is_deleted)
        OR EXISTS(SELECT 1 FROM decks d JOIN cards c ON c.deck_id=d.id WHERE d.user_id=$1 AND c.is_deleted)`, userID).Scan(&candidates); err != nil {
		return err
	}
	if !candidates {
		return tx.Commit()
	}
	// Acquire claim locks before row locks, just as upload and direct creation do.
	if err = lockDeletedContentIDs(ctx, tx, userID); err != nil {
		return err
	}
	// Lock parents in the order used by sync and direct card creation. This
	// freezes the deck membership while receipts are captured before deletion.
	rows, err := tx.QueryContext(ctx, `SELECT id FROM decks WHERE user_id=$1
        AND (is_deleted OR id IN(SELECT deck_id FROM cards WHERE is_deleted)) ORDER BY id FOR UPDATE`, userID)
	if err != nil {
		return err
	}
	for rows.Next() {
		var id string
		if err = rows.Scan(&id); err != nil {
			rows.Close()
			return err
		}
	}
	err = rows.Err()
	rows.Close()
	if err != nil {
		return err
	}
	if _, err = tx.ExecContext(ctx, `INSERT INTO purged_entities(user_id,entity,entity_id,parent_id)
        SELECT user_id,'card',id,deck_id FROM (`+deletedCardCandidates+`) candidates
        ON CONFLICT(entity,entity_id) DO NOTHING`, userID); err != nil {
		return err
	}
	if _, err = tx.ExecContext(ctx, `INSERT INTO purged_entities(user_id,entity,entity_id)
        SELECT user_id,'deck',id FROM decks WHERE user_id=$1 AND is_deleted
        ON CONFLICT(entity,entity_id) DO NOTHING`, userID); err != nil {
		return err
	}
	if _, err = tx.ExecContext(ctx, `WITH candidates AS MATERIALIZED (`+deletedCardCandidates+`)
        DELETE FROM cards c USING candidates k, purged_entities p, decks d
		WHERE p.user_id=$1 AND p.entity='card' AND p.entity_id=c.id AND d.id=c.deck_id AND d.user_id=$1
        AND c.id=k.id`, userID); err != nil {
		return err
	}
	if _, err = tx.ExecContext(ctx, `DELETE FROM decks d USING purged_entities p
        WHERE p.user_id=$1 AND p.entity='deck' AND p.entity_id=d.id AND d.user_id=$1 AND d.is_deleted`, userID); err != nil {
		return err
	}
	return tx.Commit()
}
