package repositories

import (
	"context"
	"database/sql"

	"github.com/lib/pq"
)

// LockContentIDs serializes competing content UUID claims.
// Take the account lock first, sorted claim stripes second, deck row locks last.
// A fixed 64-stripe namespace bounds shared lock memory even for large uploads.
func LockContentIDs(ctx context.Context, tx *sql.Tx, ids []string) error {
	return lockContentClaims(ctx, tx, `SELECT unnest($1::text[]) AS id`, pq.Array(ids))
}

// claimsSQL is supplied only by the static query above. Sorting in SQL
// also avoids materializing every deletion ID in application memory.
func lockContentClaims(ctx context.Context, tx *sql.Tx, claimsSQL string, args ...any) error {
	_, err := tx.ExecContext(ctx, `SELECT pg_advisory_xact_lock(130001,stripe)
        FROM (SELECT DISTINCT ((hashtextextended(id,1)%64+64)%64)::integer AS stripe
              FROM (`+claimsSQL+`) ids ORDER BY stripe) claims`, args...)
	return err
}
