package repositories

import (
	"context"
	"database/sql"

	"github.com/lib/pq"
)

// LockContentIDs serializes claims across live content and permanent receipts.
// Take the account lock first, sorted claim stripes second, deck row locks last.
// A fixed 64-stripe namespace bounds shared lock memory even for a huge purge.
func LockContentIDs(ctx context.Context, tx *sql.Tx, ids []string) error {
	return lockContentClaims(ctx, tx, `SELECT unnest($1::text[]) AS id`, pq.Array(ids))
}

const deletedCardCandidates = `
    SELECT d.user_id,c.id,c.deck_id FROM cards c JOIN decks d ON d.id=c.deck_id
        WHERE d.user_id=$1 AND c.is_deleted
    UNION ALL SELECT d.user_id,c.id,c.deck_id FROM decks d JOIN cards c ON c.deck_id=d.id
        WHERE d.user_id=$1 AND d.is_deleted AND NOT c.is_deleted`

func lockDeletedContentIDs(ctx context.Context, tx *sql.Tx, userID string) error {
	return lockContentClaims(ctx, tx, `
        SELECT 'deck:'||id::text AS id FROM decks WHERE user_id=$1 AND is_deleted
        UNION ALL SELECT 'card:'||id::text FROM (`+deletedCardCandidates+`) cards`, userID)
}

// claimsSQL is supplied only by the two static queries above. Sorting in SQL
// also avoids materializing every deletion ID in application memory.
func lockContentClaims(ctx context.Context, tx *sql.Tx, claimsSQL string, args ...any) error {
	_, err := tx.ExecContext(ctx, `SELECT pg_advisory_xact_lock(130001,stripe)
        FROM (SELECT DISTINCT ((hashtextextended(id,1)%64+64)%64)::integer AS stripe
              FROM (`+claimsSQL+`) ids ORDER BY stripe) claims`, args...)
	return err
}
