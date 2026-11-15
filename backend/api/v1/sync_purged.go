package v1

import (
	"backend/internal/db"
	"backend/internal/httperror"
	"context"
	"database/sql"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/lib/pq"
)

// SyncPurged returns only the authenticated account's deletion receipts.
func SyncPurged(c *gin.Context) {
	user, ok := syncUser(c)
	if !ok {
		return
	}
	cursor := int64(0)
	if value := c.Query("cursor"); value != "" {
		var err error
		cursor, err = strconv.ParseInt(value, 10, 64)
		if err != nil || cursor < 0 {
			c.JSON(400, gin.H{"error": "invalid cursor"})
			return
		}
	}
	ctx := c.Request.Context()
	tx, err := db.DB.BeginTx(ctx, nil)
	if err != nil {
		httperror.Internal(c, err)
		return
	}
	defer tx.Rollback()
	// Receipt sequences are allocated before commit. Sharing the writers' account
	// lock prevents advancing past an earlier uncommitted receipt for this user.
	if _, err = tx.ExecContext(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, user.String()); err != nil {
		httperror.Internal(c, err)
		return
	}
	rows, err := tx.QueryContext(ctx, `SELECT receipt_id,entity,entity_id FROM purged_entities WHERE user_id=$1 AND receipt_id>$2 ORDER BY receipt_id LIMIT 501`, user, cursor)
	if err != nil {
		httperror.Internal(c, err)
		return
	}
	defer rows.Close()
	out := []gin.H{}
	var next any
	last := cursor
	for rows.Next() {
		var sequence int64
		var entity, id string
		if err := rows.Scan(&sequence, &entity, &id); err != nil {
			httperror.Internal(c, err)
			return
		}
		if len(out) == 500 {
			next = strconv.FormatInt(last, 10)
			break
		}
		out = append(out, gin.H{"entity": entity, "id": id, "receipt_id": strconv.FormatInt(sequence, 10)})
		last = sequence
	}
	if err := rows.Err(); err != nil {
		httperror.Internal(c, err)
		return
	}
	rows.Close()
	if err = tx.Commit(); err != nil {
		httperror.Internal(c, err)
		return
	}
	c.JSON(200, gin.H{"purged": out, "next_cursor": next, "checkpoint_cursor": strconv.FormatInt(last, 10)})
}

// Called under the per-account sync/purge advisory lock. A purged UUID can
// never become content again, even with a newer offline timestamp.
func filterPurgedChanges(ctx context.Context, tx *sql.Tx, user uuid.UUID, decks []syncDeck, cards []syncCard, logs []syncReviewLog) ([]syncDeck, []syncCard, map[uuid.UUID]uuid.UUID, error) {
	ids := []string{}
	for _, d := range decks {
		ids = append(ids, d.ID.String())
	}
	for _, c := range cards {
		ids = append(ids, c.ID.String(), c.DeckID.String())
	}
	for _, l := range logs {
		ids = append(ids, l.CardID.String())
	}
	rows, err := tx.QueryContext(ctx, `SELECT entity,entity_id,user_id,parent_id FROM purged_entities WHERE entity_id=ANY($1::uuid[])`, pq.Array(ids))
	if err != nil {
		return nil, nil, nil, err
	}
	purgedDecks := map[uuid.UUID]bool{}
	purgedCards := map[uuid.UUID]uuid.UUID{}
	for rows.Next() {
		var entity string
		var id, owner uuid.UUID
		var parent uuid.NullUUID
		if err = rows.Scan(&entity, &id, &owner, &parent); err != nil {
			rows.Close()
			return nil, nil, nil, err
		}
		if owner != user {
			rows.Close()
			return nil, nil, nil, invalidSync("entity id belongs to another account")
		}
		if entity == "deck" {
			purgedDecks[id] = true
		} else {
			purgedCards[id] = parent.UUID
		}
	}
	err = rows.Err()
	rows.Close()
	if err != nil {
		return nil, nil, nil, err
	}
	keptDecks := []syncDeck{}
	for _, d := range decks {
		if !purgedDecks[d.ID] {
			keptDecks = append(keptDecks, d)
		}
	}
	keptCards := []syncCard{}
	for _, c := range cards {
		if _, gone := purgedCards[c.ID]; gone {
			continue
		}
		if purgedDecks[c.DeckID] {
			// An offline-created child of a purged deck also needs a receipt;
			// retain its review reference without ever inserting its content.
			var parent uuid.UUID
			err = tx.QueryRowContext(ctx, `INSERT INTO purged_entities(user_id,entity,entity_id,parent_id)
                SELECT $1,'card',$2,$3 WHERE NOT EXISTS(SELECT 1 FROM cards WHERE id=$2)
                ON CONFLICT(entity,entity_id) DO NOTHING RETURNING parent_id`, user, c.ID, c.DeckID).Scan(&parent)
			if err != nil && err != sql.ErrNoRows {
				return nil, nil, nil, err
			}
			if err == nil {
				purgedCards[c.ID] = parent
			}
			continue
		}
		keptCards = append(keptCards, c)
	}
	return keptDecks, keptCards, purgedCards, nil
}
