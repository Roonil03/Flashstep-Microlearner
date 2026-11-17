package repositories

import (
	"context"
	"time"
)

// CleanupDeletedUsers is driven by API activity, including registration/login.
// Main's foreign keys cascade all data belonging to a permanently removed user.
func (r *UserRepository) CleanupDeletedUsers(ctx context.Context) error {
	_, err := r.DB.ExecContext(ctx, `WITH candidates AS (
 SELECT id FROM users WHERE is_deleted AND updated_at<=clock_timestamp()-interval '24 hours'
 ORDER BY updated_at,id LIMIT 100 FOR UPDATE SKIP LOCKED
 ) DELETE FROM users u USING candidates c WHERE u.id=c.id`)
	return err
}

// CleanupDeletedContent shares the upload/Undo account lock. Parent deletion
// keeps its children for the entire deck grace, even though cards have 2s grace.
func (r *UserRepository) CleanupDeletedContent(ctx context.Context, userID string) error {
	tx, err := r.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	if _, err = tx.ExecContext(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, userID); err != nil {
		return err
	}
	rows, err := tx.QueryContext(ctx, `SELECT id FROM decks WHERE user_id=$1 AND
 ((is_deleted AND updated_at<=clock_timestamp()-interval '10 seconds') OR
 (NOT is_deleted AND EXISTS(SELECT 1 FROM cards c WHERE c.deck_id=decks.id AND c.is_deleted
 AND c.updated_at<=clock_timestamp()-interval '2 seconds')))
 ORDER BY id LIMIT 100 FOR UPDATE`, userID)
	if err != nil {
		return err
	}
	ids := []string{}
	for rows.Next() {
		var id string
		if err = rows.Scan(&id); err != nil {
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
	for _, id := range ids {
		var deleted bool
		if err = tx.QueryRowContext(ctx, `SELECT is_deleted FROM decks WHERE id=$1`, id).Scan(&deleted); err != nil {
			return err
		}
		if deleted {
			if _, err = tx.ExecContext(ctx, `DELETE FROM decks WHERE id=$1 AND is_deleted AND updated_at<=clock_timestamp()-interval '10 seconds'`, id); err != nil {
				return err
			}
		} else {
			// Main cascades raw reviews and card progress with the card.
			if _, err = tx.ExecContext(ctx, `DELETE FROM cards WHERE id IN(SELECT id FROM cards WHERE deck_id=$1 AND is_deleted AND updated_at<=clock_timestamp()-interval '2 seconds' ORDER BY id LIMIT 500)`, id); err != nil {
				return err
			}
			if err = NewProgressRepository().RecomputeDeckProgress(ctx, tx, userID, id); err != nil {
				return err
			}
		}
	}
	if len(ids) > 0 {
		if err = NewAnalyticsRepository(r.DB).RefreshUserAnalyticsTx(ctx, tx, userID, time.Now().UTC()); err != nil {
			return err
		}
	}
	return tx.Commit()
}
