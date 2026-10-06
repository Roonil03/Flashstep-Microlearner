package v1

import (
	"backend/internal/repositories"
	"context"
	"database/sql"
	"errors"
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/lib/pq"
)

type syncInputError struct{ message string }

func (e *syncInputError) Error() string { return e.message }
func invalidSync(message string) error  { return &syncInputError{message} }

type deckRevision struct {
	owner   uuid.UUID
	updated time.Time
	deleted bool
}
type cardRevision struct {
	deck, owner       uuid.UUID
	updated           time.Time
	deleted, reviewed bool
}
type logReference struct{ user, card uuid.UUID }

// writeSyncRows bounds bind parameters and round trips, including legacy uploads.
func writeSyncRows(ctx context.Context, tx *sql.Tx, prefix, suffix string, rows [][]any) error {
	const batchSize = 200
	for offset := 0; offset < len(rows); offset += batchSize {
		end := min(offset+batchSize, len(rows))
		args := []any{}
		values := []string{}
		for _, row := range rows[offset:end] {
			slots := make([]string, len(row))
			for i, value := range row {
				args = append(args, value)
				slots[i] = fmt.Sprintf("$%d", len(args))
			}
			values = append(values, "("+strings.Join(slots, ",")+")")
		}
		if _, err := tx.ExecContext(ctx, prefix+strings.Join(values, ",")+suffix, args...); err != nil {
			return err
		}
	}
	return nil
}

func applySyncChanges(ctx context.Context, tx *sql.Tx, user uuid.UUID, decks []syncDeck, cards []syncCard, logs []syncReviewLog) error {
	if _, err := tx.ExecContext(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, user.String()); err != nil {
		return err
	}
	deckIDs, cardIDs, logIDs := []string{}, []string{}, []string{}
	for _, d := range decks {
		deckIDs = append(deckIDs, d.ID.String())
	}
	for _, c := range cards {
		deckIDs = append(deckIDs, c.DeckID.String())
		cardIDs = append(cardIDs, c.ID.String())
	}
	for _, l := range logs {
		cardIDs = append(cardIDs, l.CardID.String())
		logIDs = append(logIDs, l.ID.String())
	}
	// A consistent order is shared with direct card creation's parent-row lock.
	locked, err := tx.QueryContext(ctx, `SELECT id FROM decks WHERE user_id=$1 AND
 (id=ANY($2::uuid[]) OR id IN(SELECT deck_id FROM cards WHERE id=ANY($3::uuid[]))) ORDER BY id FOR UPDATE`, user, pq.Array(deckIDs), pq.Array(cardIDs))
	if err != nil {
		return err
	}
	for locked.Next() {
		var id uuid.UUID
		if err = locked.Scan(&id); err != nil {
			locked.Close()
			return err
		}
	}
	err = locked.Err()
	locked.Close()
	if err != nil {
		return err
	}
	deckState := map[uuid.UUID]deckRevision{}
	rows, err := tx.QueryContext(ctx, `SELECT id,user_id,updated_at,is_deleted FROM decks WHERE id=ANY($1::uuid[]) OR id IN(SELECT deck_id FROM cards WHERE id=ANY($2::uuid[]))`, pq.Array(deckIDs), pq.Array(cardIDs))
	if err != nil {
		return err
	}
	for rows.Next() {
		var id uuid.UUID
		var d deckRevision
		if err = rows.Scan(&id, &d.owner, &d.updated, &d.deleted); err != nil {
			rows.Close()
			return err
		}
		deckState[id] = d
	}
	err = rows.Err()
	rows.Close()
	if err != nil {
		return err
	}
	ownedIDs := []string{}
	for id, d := range deckState {
		if d.owner == user {
			ownedIDs = append(ownedIDs, id.String())
		}
	}
	cardState := map[uuid.UUID]cardRevision{}
	counts := map[uuid.UUID]int{}
	rows, err = tx.QueryContext(ctx, `SELECT c.id,c.deck_id,d.user_id,c.updated_at,c.is_deleted,
 EXISTS(SELECT 1 FROM review_logs rl WHERE rl.card_id=c.id AND rl.user_id=$1)
 FROM cards c JOIN decks d ON d.id=c.deck_id WHERE c.deck_id=ANY($2::uuid[]) OR c.id=ANY($3::uuid[])`, user, pq.Array(ownedIDs), pq.Array(cardIDs))
	if err != nil {
		return err
	}
	for rows.Next() {
		var id uuid.UUID
		var c cardRevision
		if err = rows.Scan(&id, &c.deck, &c.owner, &c.updated, &c.deleted, &c.reviewed); err != nil {
			rows.Close()
			return err
		}
		cardState[id] = c
		if !c.deleted {
			counts[c.deck]++
		}
	}
	err = rows.Err()
	rows.Close()
	if err != nil {
		return err
	}
	existingLogs := map[uuid.UUID]logReference{}
	rows, err = tx.QueryContext(ctx, `SELECT id,user_id,card_id FROM review_logs WHERE id=ANY($1::uuid[])`, pq.Array(logIDs))
	if err != nil {
		return err
	}
	for rows.Next() {
		var id uuid.UUID
		var l logReference
		if err = rows.Scan(&id, &l.user, &l.card); err != nil {
			rows.Close()
			return err
		}
		existingLogs[id] = l
	}
	err = rows.Err()
	rows.Close()
	if err != nil {
		return err
	}

	acceptedDecks := map[uuid.UUID]syncDeck{}
	acceptedCards := map[uuid.UUID]syncCard{}
	cascades := map[uuid.UUID]time.Time{}
	impactedCards := map[uuid.UUID]bool{}
	impactedDecks := map[uuid.UUID]bool{}
	for _, d := range decks {
		old, exists := deckState[d.ID]
		if exists && old.owner != user {
			return invalidSync("deck id belongs to another account")
		}
		if exists && !d.UpdatedAt.After(old.updated) {
			continue
		}
		deckState[d.ID] = deckRevision{user, d.UpdatedAt, d.IsDeleted}
		acceptedDecks[d.ID] = d
		if d.IsDeleted {
			// Only the first accepted cascade sees active child rows. A later deck undo
			// does not implicitly resurrect cards; explicit card operations do that.
			if _, ok := cascades[d.ID]; !ok {
				cascades[d.ID] = d.UpdatedAt
			}
			for id, c := range cardState {
				if c.deck == d.ID && !c.deleted {
					c.deleted = true
					if d.UpdatedAt.After(c.updated) {
						c.updated = d.UpdatedAt
					}
					cardState[id] = c
					counts[d.ID]--
					if c.reviewed {
						impactedCards[id] = true
						impactedDecks[d.ID] = true
					}
				}
			}
		}
	}
	deckRows := [][]any{}
	for _, id := range sortedSyncIDs(acceptedDecks) {
		d := acceptedDecks[id]
		deckRows = append(deckRows, []any{d.ID, user, d.Title, nullableStringValue(d.Description), d.IsPublic, d.CreatedAt, d.UpdatedAt, d.Version, d.IsDeleted})
	}
	if err := writeSyncRows(ctx, tx, `INSERT INTO decks(id,user_id,title,description,is_public,created_at,updated_at,version,is_deleted) VALUES `,
		` ON CONFLICT(id) DO UPDATE SET title=EXCLUDED.title,description=EXCLUDED.description,is_public=EXCLUDED.is_public,updated_at=EXCLUDED.updated_at,version=EXCLUDED.version,is_deleted=EXCLUDED.is_deleted WHERE decks.user_id=EXCLUDED.user_id AND decks.updated_at<EXCLUDED.updated_at`, deckRows); err != nil {
		return err
	}
	// Detect concurrent cross-account UUID collisions without acknowledging them.
	if len(deckRows) > 0 {
		var bad bool
		if err := tx.QueryRowContext(ctx, `SELECT EXISTS(SELECT 1 FROM decks WHERE id=ANY($1::uuid[]) AND user_id<>$2)`, pq.Array(deckIDs), user).Scan(&bad); err != nil {
			return err
		}
		if bad {
			return invalidSync("deck id belongs to another account")
		}
	}
	cascadeRows := [][]any{}
	for _, id := range sortedSyncIDs(cascades) {
		cascadeRows = append(cascadeRows, []any{id.String(), cascades[id]})
	}
	if err := writeSyncRows(ctx, tx, `UPDATE cards c SET is_deleted=true,updated_at=GREATEST(c.updated_at,v.at),version=c.version+CASE WHEN c.updated_at<v.at THEN 1 ELSE 0 END FROM (VALUES `,
		`) AS input(id,stamp) CROSS JOIN LATERAL(SELECT input.id::uuid AS id,input.stamp::timestamptz AS at) v WHERE c.deck_id=v.id AND NOT c.is_deleted`, cascadeRows); err != nil {
		return err
	}
	// Existing UPDATE triggers stamp server time. Read actual revisions after
	// deck writes/cascades instead of assuming payload timestamps survived.
	revisionIDs := []string{}
	for id := range deckState {
		revisionIDs = append(revisionIDs, id.String())
	}
	rows, err = tx.QueryContext(ctx, `SELECT id,user_id,updated_at,is_deleted FROM decks WHERE id=ANY($1::uuid[])`, pq.Array(revisionIDs))
	if err != nil {
		return err
	}
	for rows.Next() {
		var id uuid.UUID
		var d deckRevision
		if err = rows.Scan(&id, &d.owner, &d.updated, &d.deleted); err != nil {
			rows.Close()
			return err
		}
		deckState[id] = d
	}
	err = rows.Err()
	rows.Close()
	if err != nil {
		return err
	}
	if len(cascades) > 0 {
		ids := []string{}
		for id := range cascades {
			ids = append(ids, id.String())
		}
		rows, err = tx.QueryContext(ctx, `SELECT id,updated_at,is_deleted FROM cards WHERE deck_id=ANY($1::uuid[])`, pq.Array(ids))
		if err != nil {
			return err
		}
		for rows.Next() {
			var id uuid.UUID
			var stamp time.Time
			var deleted bool
			if err = rows.Scan(&id, &stamp, &deleted); err != nil {
				rows.Close()
				return err
			}
			c := cardState[id]
			c.updated = stamp
			c.deleted = deleted
			cardState[id] = c
		}
		err = rows.Err()
		rows.Close()
		if err != nil {
			return err
		}
	}

	for _, c := range cards {
		old, exists := cardState[c.ID]
		if exists && old.owner != user {
			return invalidSync("card id belongs to another account")
		}
		deck, ok := deckState[c.DeckID]
		if !ok || deck.owner != user {
			return invalidSync("card references a missing or unauthorized deck")
		}
		if deck.deleted && !c.IsDeleted {
			if !c.UpdatedAt.After(deck.updated) {
				continue
			}
			return invalidSync("cannot apply active card changes to a deleted deck")
		}
		if exists && !c.UpdatedAt.After(old.updated) {
			continue
		}
		if exists && !old.deleted {
			counts[old.deck]--
		}
		if !c.IsDeleted {
			counts[c.DeckID]++
			if counts[c.DeckID] > maxCardsPerDeck {
				return invalidSync("a deck can contain at most 50 cards")
			}
		}
		acceptedCards[c.ID] = c
		cardState[c.ID] = cardRevision{c.DeckID, user, c.UpdatedAt, c.IsDeleted, old.reviewed}
		if old.reviewed {
			impactedCards[c.ID] = true
			impactedDecks[c.DeckID] = true
			if exists {
				impactedDecks[old.deck] = true
			}
		}
	}
	acceptedLogs := map[uuid.UUID]syncReviewLog{}
	for _, l := range logs {
		if l.UserID != user {
			return invalidSync("review log user_id does not match authenticated user")
		}
		card, ok := cardState[l.CardID]
		if !ok || card.owner != user {
			return invalidSync("review log references a missing or unauthorized card")
		}
		if old, ok := existingLogs[l.ID]; ok {
			if old.user != user || old.card != l.CardID {
				return invalidSync("review log id collision")
			}
			continue
		}
		acceptedLogs[l.ID] = l
		existingLogs[l.ID] = logReference{user, l.CardID}
		impactedCards[l.CardID] = true
		impactedDecks[card.deck] = true
	}
	cardRows := [][]any{}
	for _, id := range sortedSyncIDs(acceptedCards) {
		c := acceptedCards[id]
		cardRows = append(cardRows, []any{c.ID, c.DeckID, c.Front, c.Back, c.State, c.Interval, c.EaseFactor, c.RepetitionCount, nullableTimeValue(c.DueTimestamp), nullableTimeValue(c.LastReviewedAt), c.CreatedAt, c.UpdatedAt, c.Version, c.IsDeleted})
	}
	if err := writeSyncRows(ctx, tx, `INSERT INTO cards(id,deck_id,front,back,state,interval,ease_factor,repetition_count,due_timestamp,last_reviewed_at,created_at,updated_at,version,is_deleted) VALUES `,
		` ON CONFLICT(id) DO UPDATE SET deck_id=EXCLUDED.deck_id,front=EXCLUDED.front,back=EXCLUDED.back,state=EXCLUDED.state,interval=EXCLUDED.interval,ease_factor=EXCLUDED.ease_factor,repetition_count=EXCLUDED.repetition_count,due_timestamp=EXCLUDED.due_timestamp,last_reviewed_at=EXCLUDED.last_reviewed_at,updated_at=EXCLUDED.updated_at,version=EXCLUDED.version,is_deleted=EXCLUDED.is_deleted WHERE cards.updated_at<EXCLUDED.updated_at AND cards.deck_id IN(SELECT id FROM decks WHERE user_id=(SELECT user_id FROM decks WHERE id=EXCLUDED.deck_id))`, cardRows); err != nil {
		return err
	}
	if len(cardRows) > 0 {
		var bad bool
		if err := tx.QueryRowContext(ctx, `SELECT EXISTS(SELECT 1 FROM cards c JOIN decks d ON d.id=c.deck_id WHERE c.id=ANY($1::uuid[]) AND d.user_id<>$2)`, pq.Array(cardIDs), user).Scan(&bad); err != nil {
			return err
		}
		if bad {
			return invalidSync("card id belongs to another account")
		}
	}
	logRows := [][]any{}
	for _, id := range sortedSyncIDs(acceptedLogs) {
		l := acceptedLogs[id]
		logRows = append(logRows, []any{l.ID, user, l.CardID, l.Rating, l.PreviousInterval, l.NewInterval, l.ReviewedAt, nullableUUIDValue(l.DeviceID), l.CreatedAt})
	}
	if err := writeSyncRows(ctx, tx, `INSERT INTO review_logs(id,user_id,card_id,rating,previous_interval,new_interval,reviewed_at,device_id,created_at) VALUES `, ` ON CONFLICT(id) DO NOTHING`, logRows); err != nil {
		return err
	}
	if len(logRows) > 0 {
		var bad bool
		if err := tx.QueryRowContext(ctx, `SELECT EXISTS(SELECT 1 FROM review_logs WHERE id=ANY($1::uuid[]) AND user_id<>$2)`, pq.Array(logIDs), user).Scan(&bad); err != nil {
			return err
		}
		if bad {
			return invalidSync("review log id collision")
		}
	}
	progress := repositories.NewProgressRepository()
	for _, id := range sortedSyncIDs(impactedCards) {
		if err := progress.RecomputeUserCardProgress(ctx, tx, user.String(), id.String()); err != nil {
			return err
		}
	}
	for _, id := range sortedSyncIDs(impactedDecks) {
		if err := progress.RecomputeDeckProgress(ctx, tx, user.String(), id.String()); err != nil {
			return err
		}
	}
	if len(acceptedLogs) > 0 {
		return repositories.NewAnalyticsRepository(nil).RefreshUserAnalyticsTx(ctx, tx, user.String(), time.Now().UTC())
	}
	return nil
}

func sortedSyncIDs[T any](values map[uuid.UUID]T) []uuid.UUID {
	ids := make([]uuid.UUID, 0, len(values))
	for id := range values {
		ids = append(ids, id)
	}
	sort.Slice(ids, func(i, j int) bool { return ids[i].String() < ids[j].String() })
	return ids
}

func syncErrorStatus(err error) int {
	var input *syncInputError
	if errors.As(err, &input) {
		return 400
	}
	return 500
}
