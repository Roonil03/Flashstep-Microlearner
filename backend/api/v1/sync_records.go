package v1

import (
	"context"
	"database/sql"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"time"
)

type syncQuerier interface {
	QueryContext(context.Context, string, ...any) (*sql.Rows, error)
}

func readSyncDecks(ctx context.Context, q syncQuerier, filter string, args ...any) ([]gin.H, error) {
	rows, err := q.QueryContext(ctx, `SELECT d.id,d.user_id,d.title,d.description,d.is_public,d.created_at,d.updated_at,d.version,d.is_deleted FROM (
 SELECT id,user_id,title,description,is_public,created_at,updated_at,version,is_deleted FROM decks
 UNION ALL SELECT entity_id,user_id,'',NULL,false,purged_at,purged_at,1,true FROM purged_entities WHERE entity='deck'
 ) d `+filter, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make([]gin.H, 0)
	for rows.Next() {
		var id, owner uuid.UUID
		var title string
		var description *string
		var public, deleted bool
		var created, updated time.Time
		var version int
		if err := rows.Scan(&id, &owner, &title, &description, &public, &created, &updated, &version, &deleted); err != nil {
			return nil, err
		}
		out = append(out, gin.H{"id": id.String(), "user_id": owner.String(), "title": title, "description": description, "is_public": public, "created_at": created.UTC().Format(time.RFC3339Nano), "updated_at": updated.UTC().Format(time.RFC3339Nano), "version": version, "is_deleted": deleted})
	}
	return out, rows.Err()
}

func readSyncCards(ctx context.Context, q syncQuerier, filter string, args ...any) ([]gin.H, error) {
	return readSyncCardsIncludingPurged(ctx, q, true, filter, args...)
}

func readSyncCardsIncludingPurged(ctx context.Context, q syncQuerier, includePurged bool, filter string, args ...any) ([]gin.H, error) {
	receiptFilter := ""
	if !includePurged {
		receiptFilter = " AND false"
	}
	rows, err := q.QueryContext(ctx, `SELECT c.id,c.deck_id,c.front,c.back,c.state,c.interval,c.ease_factor,c.repetition_count,c.due_timestamp,c.last_reviewed_at,c.created_at,c.updated_at,c.version,c.is_deleted FROM (
 SELECT id,deck_id,front,back,state,interval,ease_factor,repetition_count,due_timestamp,last_reviewed_at,created_at,updated_at,version,is_deleted FROM cards
 UNION ALL SELECT entity_id,parent_id,'','','new',0,2.5,0,NULL,NULL,purged_at,purged_at,1,true FROM purged_entities WHERE entity='card'`+receiptFilter+`
 ) c JOIN (SELECT id,user_id FROM decks UNION ALL SELECT entity_id,user_id FROM purged_entities WHERE entity='deck'`+receiptFilter+`) d ON d.id=c.deck_id `+filter, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make([]gin.H, 0)
	for rows.Next() {
		var id, deck uuid.UUID
		var front, back, state string
		var interval, ease float64
		var reps, version int
		var due, reviewed *time.Time
		var created, updated time.Time
		var deleted bool
		if err := rows.Scan(&id, &deck, &front, &back, &state, &interval, &ease, &reps, &due, &reviewed, &created, &updated, &version, &deleted); err != nil {
			return nil, err
		}
		out = append(out, gin.H{"id": id.String(), "deck_id": deck.String(), "front": front, "back": back, "state": state, "interval": interval, "ease_factor": ease, "repetition_count": reps, "due_timestamp": syncTime(due), "last_reviewed_at": syncTime(reviewed), "created_at": created.UTC().Format(time.RFC3339Nano), "updated_at": updated.UTC().Format(time.RFC3339Nano), "version": version, "is_deleted": deleted})
	}
	return out, rows.Err()
}
func syncTime(t *time.Time) any {
	if t == nil {
		return nil
	}
	return t.UTC().Format(time.RFC3339Nano)
}
