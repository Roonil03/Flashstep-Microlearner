package v1

import (
	"backend/internal/db"
	"database/sql"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/lib/pq"
	"net/http"
	"strconv"
	"strings"
)

func syncUser(c *gin.Context) (uuid.UUID, bool) {
	user, err := uuid.Parse(strings.TrimSpace(c.GetString("user_id")))
	if err != nil {
		c.JSON(401, gin.H{"error": "invalid user id in auth context"})
		return uuid.Nil, false
	}
	return user, true
}
func syncCursor(value string) (uuid.UUID, error) {
	if strings.TrimSpace(value) == "" {
		return uuid.Nil, nil
	}
	return uuid.Parse(value)
}
func syncPageLimit(value int) (int, bool) {
	if value == 0 {
		return 500, true
	}
	return value, value >= 1 && value <= 500
}

// SyncManifest visits revision metadata only; unchanged decks need no card bodies.
func SyncManifest(c *gin.Context) {
	user, ok := syncUser(c)
	if !ok {
		return
	}
	cursor, err := syncCursor(c.Query("cursor"))
	if err != nil {
		c.JSON(400, gin.H{"error": "invalid cursor"})
		return
	}
	limit := 500
	if value := c.Query("limit"); value != "" {
		limit, err = strconv.Atoi(value)
		if err != nil {
			c.JSON(400, gin.H{"error": "invalid limit"})
			return
		}
	}
	limit, ok = syncPageLimit(limit)
	if !ok {
		c.JSON(400, gin.H{"error": "limit must be between 1 and 500"})
		return
	}
	rows, err := db.DB.QueryContext(c.Request.Context(), `
 WITH page AS (SELECT id,version,updated_at,is_deleted FROM decks WHERE user_id=$1 AND id>$2 ORDER BY id LIMIT $3)
 SELECT d.id,md5(jsonb_build_array(d.id,d.version,EXTRACT(EPOCH FROM d.updated_at),d.is_deleted,
 COALESCE(children.revisions,'[]'::jsonb))::text)
 FROM page d LEFT JOIN LATERAL (
 SELECT jsonb_agg(jsonb_build_array(c.id,c.deck_id,c.version,EXTRACT(EPOCH FROM c.updated_at),c.is_deleted) ORDER BY c.id) AS revisions
 FROM cards c WHERE c.deck_id=d.id) children ON true ORDER BY d.id`, user, cursor, limit+1)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()
	out := make([]gin.H, 0)
	var next any
	for rows.Next() {
		var id uuid.UUID
		var fingerprint string
		if err := rows.Scan(&id, &fingerprint); err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}
		if len(out) == limit {
			next = out[len(out)-1]["id"]
			break
		}
		out = append(out, gin.H{"id": id.String(), "fingerprint": fingerprint})
	}
	if err := rows.Err(); err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	c.JSON(200, gin.H{"decks": out, "next_cursor": next})
}

type syncFetchRequest struct {
	DeckIDs []string `json:"deck_ids"`
	Cursor  string   `json:"cursor"`
	Limit   int      `json:"limit"`
}

// SyncFetch pages all selected decks' cards by UUID, including every tombstone.
func SyncFetch(c *gin.Context) {
	user, ok := syncUser(c)
	if !ok {
		return
	}
	var request syncFetchRequest
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 1<<20)
	if err := c.ShouldBindJSON(&request); err != nil {
		c.JSON(400, gin.H{"error": "invalid fetch payload"})
		return
	}
	if len(request.DeckIDs) < 1 || len(request.DeckIDs) > 25 {
		c.JSON(400, gin.H{"error": "deck_ids must contain between 1 and 25 UUIDs"})
		return
	}
	ids := []string{}
	seen := map[uuid.UUID]bool{}
	for _, value := range request.DeckIDs {
		id, err := uuid.Parse(value)
		if err != nil {
			c.JSON(400, gin.H{"error": "invalid deck id"})
			return
		}
		if !seen[id] {
			ids = append(ids, id.String())
			seen[id] = true
		}
	}
	cursor, err := syncCursor(request.Cursor)
	if err != nil {
		c.JSON(400, gin.H{"error": "invalid cursor"})
		return
	}
	limit, ok := syncPageLimit(request.Limit)
	if !ok {
		c.JSON(400, gin.H{"error": "limit must be between 1 and 500"})
		return
	}
	ctx := c.Request.Context()
	tx, err := db.DB.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelRepeatableRead, ReadOnly: true})
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	defer tx.Rollback()
	decks, err := readSyncDecks(ctx, tx, `WHERE d.user_id=$1 AND d.id=ANY($2::uuid[]) ORDER BY d.id`, user, pq.Array(ids))
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	if len(decks) != len(ids) {
		c.JSON(400, gin.H{"error": "missing or unauthorized deck"})
		return
	}
	cards, err := readSyncCards(ctx, tx, `WHERE d.user_id=$1 AND c.deck_id=ANY($2::uuid[]) AND c.id>$3 ORDER BY c.id LIMIT $4`, user, pq.Array(ids), cursor, limit+1)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	var next any
	if len(cards) > limit {
		next = cards[limit-1]["id"]
		cards = cards[:limit]
	}
	if err := tx.Commit(); err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	c.JSON(200, gin.H{"decks": decks, "cards": cards, "next_cursor": next})
}
