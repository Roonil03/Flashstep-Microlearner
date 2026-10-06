# API Documentation

## Base URL and Availability

All endpoint paths below are relative to `/api/v1`, except `/health`.
The frontend's default API base URL is `https://flashstep-api.onrender.com/api/v1`.
JSON request bodies use `Content-Type: application/json`.

The v1.1.0 backend adds `/sync/manifest` and `/sync/fetch` without removing the
existing upload/download endpoints or requiring a database migration. Deploy
this backend before distributing the updated frontend. A frontend build can
override its base URL using `--dart-define=API_BASE_URL=<base URL>` for isolated
testing; this does not change the server's route prefix.

### Health Check

`GET /health` is outside `/api/v1` and does not require authentication.

Response `200 OK`:
```json
{"status": "ok"}
```

This checks HTTP service availability; it does not execute a database health query.

## Auth Header
Protected routes require:

```http
Authorization: Bearer <JWT_TOKEN>
```

Registration, login, and the health check are public. All deck, card, sync,
analytics, account-edit, and `/me` routes require the header above, including
browsing or downloading public decks.

---

## AUTH APIs

### Register
`POST /auth/register`

Request body:
```json
{
  "username": "john_doe",
  "email": "john@example.com",
  "password": "password123"
}
```

Response `201 Created`:
```json
{
  "user": {
    "id": "uuid",
    "username": "john_doe",
    "email": "john@example.com",
    "created_at": "2026-03-21T10:00:00Z",
    "updated_at": "2026-03-21T10:00:00Z"
  },
  "token": "jwt_token"
}
```

### Login
`POST /auth/login`

Request body:
```json
{
  "email": "john@example.com",
  "password": "password123"
}
```

Response `200 OK`:
```json
{
  "user": {
    "id": "uuid",
    "username": "john_doe",
    "email": "john@example.com",
    "created_at": "2026-03-21T10:00:00Z",
    "updated_at": "2026-03-21T10:00:00Z"
  },
  "token": "jwt_token"
}
```

### Get Current User
`GET /me`

Response `200 OK`:
```json
{
  "id": "uuid",
  "username": "john_doe",
  "email": "john@example.com",
  "created_at": "2026-03-21T10:00:00Z",
  "updated_at": "2026-03-21T10:00:00Z"
}
```

### Change Username
`PUT /auth/change-username`

Request body:
```json
{
  "username": "new_username"
}
```

Response `200 OK`:
```json
{
  "message": "username updated successfully"
}
```

Errors:
- `400 Bad Request`: invalid request payload
- `401 Unauthorized`: missing or invalid token
- `500 Internal Server Error`: database failure

### Change Password
`PUT /auth/change-password`

Request body:
```json
{
  "old_password": "current_password",
  "new_password": "new_secure_password"
}
```

Response `200 OK`:
```json
{
  "message": "password updated"
}
```

Errors:
- `400 Bad Request`: invalid request payload
- `401 Unauthorized`: old password incorrect or token missing/invalid

### Delete Account
`DELETE /auth/delete-account`

Response `200 OK`:
```json
{
  "message": "account deleted"
}
```

Behavior notes:
- this endpoint performs a **soft delete** of the authenticated user,
- the account becomes unavailable for normal use immediately,
- permanent cleanup is handled later by backend maintenance.

---

## DECK APIs

### Create Deck
`POST /decks`

Request body:
```json
{
  "title": "Biology",
  "description": "Class 12 notes",
  "is_public": false
}
```

Response `201 Created`:
```json
{
  "id": "deck_uuid"
}
```

Validation notes:
- `title` is required
- empty/blank descriptions may be stored as `null`

### Get My Decks
`GET /decks`

Returns the authenticated user's own active decks only.

Response `200 OK`:
```json
[
  {
    "id": "deck_uuid",
    "user_id": "user_uuid",
    "title": "Biology",
    "description": "Class 12 notes",
    "is_public": false,
    "created_at": "2026-03-21T10:00:00Z",
    "updated_at": "2026-03-21T10:00:00Z",
    "version": 1,
    "is_deleted": false
  }
]
```

### Get Public Decks
`GET /decks/public`

Returns public, non-deleted decks owned by other users.

Response `200 OK`:
```json
[
  {
    "id": "deck_uuid",
    "user_id": "owner_uuid",
    "title": "Operating Systems",
    "description": "Short OS review deck",
    "updated_at": "2026-03-24T10:00:00Z",
    "version": 3,
    "owner_username": "deck_owner",
    "card_count": 24
  }
]
```

Behavior notes:
- excludes deleted decks,
- excludes decks owned by the requesting user,
- `card_count` counts active cards only,
- optional `search` filters titles using a case-insensitive SQL `ILIKE` pattern
  surrounded by `%`; URL-encode the value (for example, `/decks/public?search=Operating%20Systems`),
- blank/omitted search returns all matching public decks; results are ordered by
  `updated_at` descending, then title ascending. This endpoint is not paginated.

### Download Public Deck
`POST /decks/:id/download`

Copies a public deck into the authenticated user's account.

Response `201 Created`:
```json
{
  "deck": {
    "id": "new_deck_uuid",
    "user_id": "current_user_uuid",
    "title": "Operating Systems",
    "description": "Short OS review deck",
    "is_public": false,
    "created_at": "2026-03-24T10:00:00Z",
    "updated_at": "2026-03-24T10:00:00Z",
    "version": 1,
    "is_deleted": false
  },
  "cards": [
    {
      "id": "new_card_uuid",
      "deck_id": "new_deck_uuid",
      "front": "What does a mutex do?",
      "back": "It provides mutual exclusion for critical sections.",
      "state": "new",
      "interval": 0,
      "ease_factor": 2.5,
      "repetition_count": 0,
      "due_timestamp": "2026-03-24T10:00:00Z",
      "last_reviewed_at": null,
      "created_at": "2026-03-24T10:00:00Z",
      "updated_at": "2026-03-24T10:00:00Z",
      "version": 1,
      "is_deleted": false
    }
  ],
  "downloaded_from": "source_deck_uuid",
  "source_owner_id": "owner_uuid",
  "source_owner_username": "deck_owner"
}
```

Behavior notes:
- the copied deck is owned by the downloader,
- the copied deck is created as `is_public=false`,
- copied cards receive new card IDs and belong to the new deck,
- the original public deck is unchanged,
- copied cards start with fresh review scheduling (`state=new`, interval and
  repetition count zero, ease factor 2.5, due now, no previous review),
- downloading your own public deck returns `400`; an unavailable, private, or
  deleted source returns `404`. Invalid source UUIDs return `400`.

### Update Deck
`PUT /decks/:id`

Supports deck rename and normal deck metadata edits.

Request body:
```json
{
  "title": "Biology Updated",
  "description": "Updated notes",
  "is_public": true,
  "version": 1
}
```

Response `200 OK`:
```json
{
  "message": "updated"
}
```

Errors:
- `400 Bad Request`: invalid payload or empty title
- `401 Unauthorized`: invalid or missing JWT
- `404 Not Found`: deck not found for that user
- `409 Conflict`: version conflict

Behavior notes:
- this route is used for **renaming decks**,
- `version` must be provided,
- updates apply only to the owner's non-deleted deck,
- successful updates increment `version` and refresh `updated_at`.

### Delete Deck
`DELETE /decks/:id`

Response `200 OK`:
```json
{
  "message": "deleted"
}
```

Behavior notes:
- delete is a **logical delete** (`is_deleted=true`),
- deleting a deck also logically deletes its child cards,
- deleted rows may still appear in sync payloads with `is_deleted=true`,
- the client may provide a short undo window before permanently removing the deck and cards from the local database.

---

## CARD APIs

### Create Card
`POST /cards`

Request body:
```json
{
  "deck_id": "deck_uuid",
  "front": "What is DNA?",
  "back": "Genetic material"
}
```

Response `201 Created`:
```json
{
  "id": "card_uuid"
}
```

Validation notes:
- `deck_id` must be a valid UUID,
- `front` and `back` are required,
- cards can only be created in the authenticated user's own active decks,
- a deck can contain at most 50 active cards.

The capacity check and insertion are one transaction with a parent-deck lock,
shared with sync uploads. Concurrent creation cannot bypass the active-card limit.

Errors:
- `400 Bad Request`: invalid JSON/UUID, blank front/back, or the deck already has 50 active cards
- `401 Unauthorized`: missing or invalid JWT
- `403 Forbidden`: missing, deleted, or unauthorized parent deck
- `500 Internal Server Error`: database/transaction failure

### Get Cards of Deck
`GET /decks/:deck_id/cards`

Response `200 OK`:
```json
[
  {
    "id": "card_uuid",
    "deck_id": "deck_uuid",
    "front": "What is DNA?",
    "back": "Genetic material",
    "state": "new",
    "due_timestamp": "2026-03-22T10:00:00Z",
    "updated_at": "2026-03-21T10:00:00Z",
    "version": 1,
    "is_deleted": false
  }
]
```

Behavior notes:
- returns cards for either:
  - one of the authenticated user's decks, or
  - a public deck,
- deleted cards are excluded from normal listing,
- parent deck must also be active.

### Update Card
`PUT /cards/:id`

Supports changing the front/back content of a card.

Request body:
```json
{
  "front": "Updated Question",
  "back": "Updated Answer",
  "version": 1
}
```

Response `200 OK`:
```json
{
  "message": "updated"
}
```

Errors:
- `400 Bad Request`: invalid payload or empty front/back
- `401 Unauthorized`: invalid or missing JWT
- `404 Not Found`: card not found for that user
- `409 Conflict`: version conflict

Behavior notes:
- `version` must be provided,
- updates apply only if the card belongs to one of the user's active decks,
- successful updates increment `version` and refresh `updated_at`.

### Delete Card
`DELETE /cards/:id`

Response `200 OK`:
```json
{
  "message": "deleted"
}
```

Behavior notes:
- delete is a **logical delete** (`is_deleted=true`),
- only the targeted card is deleted,
- deleted rows may still appear in sync payloads with `is_deleted=true`,
- the client may provide a short undo window before permanently removing the card from the local database.

---

## SYNC APIs

### Deck Manifest (v1.1.0)

`GET /sync/manifest?cursor=<deck UUID>&limit=500`

Query parameters:
- `cursor`: optional deck UUID; omit it for the first page. Subsequent pages
  return deck IDs strictly greater than this cursor.
- `limit`: integer from 1 through 500; omission or explicit `0` uses 500.

Response `200 OK`:
```json
{
  "decks": [
    {
      "id": "11111111-1111-4111-8111-111111111111",
      "fingerprint": "opaque revision digest"
    }
  ],
  "next_cursor": null
}
```

Only owned decks are returned, ordered by UUID, including deleted decks.
Fingerprints include the deck revision/timestamp/deletion flag and ordered
child-card IDs, parent IDs, revisions, timestamps, and deletion flags. Treat the
fingerprint as an opaque equality token, not a timestamp or authentication value.
No card bodies or review logs are returned. Empty results use `decks: []`.

If more records exist, `next_cursor` is the last returned deck UUID. Pass it as
`cursor` in the next request; `null` means the manifest is complete.

Errors:
- `400 Bad Request`: invalid UUID cursor or invalid/non-integer limit
- `401 Unauthorized`: missing or invalid JWT
- `500 Internal Server Error`: database/read failure

### Fetch Selected Decks (v1.1.0)

`POST /sync/fetch`

Request body:
```json
{
  "deck_ids": ["11111111-1111-4111-8111-111111111111"],
  "limit": 500
}
```

- `deck_ids`: required array of 1–25 UUID entries. Every deck must belong to the
  authenticated account; public visibility does not grant access through sync.
  Duplicate IDs are deduplicated, but the input still cannot exceed 25 entries.
- `cursor`: optional card UUID; omit it for the first page. On later pages,
  supply the returned `next_cursor` and keep the same `deck_ids`.
- `limit`: integer from 1 through 500; omission or explicit `0` uses 500.
- The request body is limited to 1 MiB; oversized bodies return `400`.

Response `200 OK` contains `decks`, `cards`, and `next_cursor`. Deck and card
objects have the complete record shapes shown under **Download Changes** below.
Each page repeats all selected deck records, ordered by deck UUID, even when
that page has no cards. `cards` contains up to `limit` records ordered by card
UUID across the entire selected set, not a separate limit/cursor for each deck.
Both arrays include tombstones. Empty card results use `cards: []`.

If more cards exist, `next_cursor` is the last returned card UUID; otherwise it
is `null`. Review logs, fingerprints, and the upload-only `from_deck_deletion`
marker are not included. Timestamp strings are UTC RFC3339 with available
fractional precision; nullable card dates and deck descriptions remain `null`.

Errors:
- `400 Bad Request`: malformed/oversized JSON, missing or invalid deck IDs,
  more than 25 input IDs, any missing/unauthorized deck, invalid cursor or limit
- `401 Unauthorized`: missing or invalid JWT
- `500 Internal Server Error`: database/read/transaction failure

### Reconciliation Sequence and Compatibility

1. Upload queued mutations in deck → card → review-log order. The updated
   frontend coalesces concurrent sync calls per account and uses batches of at
   most 200 records and approximately 1 MiB. These are client batching targets,
   not newly imposed limits on the legacy upload endpoint. An oversized single
   operation is attempted separately and retained if it fails.
2. Read the manifest every sync and compare account-specific cached
   fingerprints. Fetch missing or changed decks in groups of up to 25.
3. Merge every card page, including tombstones, while protecting still-queued
   local edits. Save the manifest's original fingerprint only after all pages
   for that group merge successfully. Invalidate fingerprints for decks with
   remaining pending edits; missing/corrupt metadata starts fresh reconciliation.
4. Continue until both card and manifest cursors are `null`. The endpoints do
   not hold a snapshot across HTTP requests; each fetch request has its own
   consistent read transaction. Changes arriving during paging are detected on
   the following sync. Interrupted downloads can safely restart.

Only a manifest `404`/`405` selects the older-backend fallback: call
`GET /sync/download` without `since` and reconcile the full response. Other
errors fail the sync for retry. A device-clock checkpoint can miss late offline
uploads, so the updated frontend does not use it to filter reconciliation.
Account changes stop further work; only acknowledged queue operations are removed.

### Upload Changes
`POST /sync/upload`

Request body:
```json
{
  "decks": [
    {
      "id": "uuid",
      "user_id": "uuid",
      "title": "Operating Systems",
      "description": "Short OS review deck",
      "is_public": false,
      "created_at": "2026-03-24T10:00:00Z",
      "updated_at": "2026-03-24T10:00:00Z",
      "version": 1,
      "is_deleted": false
    }
  ],
  "cards": [
    {
      "id": "uuid",
      "deck_id": "uuid",
      "front": "What does a mutex do?",
      "back": "It provides mutual exclusion for critical sections.",
      "state": "review",
      "interval": 6,
      "ease_factor": 2.5,
      "repetition_count": 3,
      "due_timestamp": "2026-03-30T10:00:00Z",
      "last_reviewed_at": "2026-03-24T10:00:00Z",
      "created_at": "2026-03-21T10:00:00Z",
      "updated_at": "2026-03-24T10:00:00Z",
      "version": 4,
      "is_deleted": false
    }
  ],
  "review_logs": [
    {
      "id": "uuid",
      "user_id": "uuid",
      "card_id": "uuid",
      "rating": "good",
      "previous_interval": 2,
      "new_interval": 6,
      "reviewed_at": "2026-03-24T10:00:00Z",
      "device_id": null,
      "created_at": "2026-03-24T10:00:00Z"
    }
  ]
}
```

Response `200 OK`:
```json
{
  "status": "synced",
  "decks_processed": 1,
  "cards_processed": 1,
  "review_logs_processed": 1,
  "server_time": "2026-03-24T10:00:01Z"
}
```

Errors:
- `400 Bad Request`: invalid payload/UUID, missing required fields, unauthorized
  references, cross-account deck/card/review-log ID collisions, review-log
  `user_id` mismatch, or a deck exceeding the 50-active-card limit
- `401 Unauthorized`: invalid or missing JWT
- `500 Internal Server Error`: server/database error while applying sync

Upload behavior:
- Omitted entity arrays are treated as empty. Deck ownership comes from the
  authenticated account; a deck's supplied `user_id` is not used to assign ownership.
  Review-log `user_id` defaults to that account when omitted and must match when supplied.
- Deck IDs, card IDs/parent deck IDs, and review-log IDs/card IDs are required
  UUIDs. Active decks require a title; active cards require front and back.
  Reviews require a rating (`again`, `hard`, `good`, or `easy`) and may supply
  a nullable `device_id` UUID. Reuse the same review-log ID when retrying.
- Supply valid RFC3339 timestamps with fractional precision as needed. Current
  normalization substitutes server time for missing/malformed `created_at`,
  `updated_at`, and review timestamps; malformed optional card dates become
  `null`. Clients should preserve valid original timestamps for conflict resolution.
- Each request is atomic: accepted deck/card changes, new review logs, affected
  progress, and relevant analytics commit together. Failed requests roll back;
  concurrent uploads for the same account are serialized. Separate HTTP batches
  are separate transactions, so a later failed batch does not undo earlier acknowledgments.
- Stale or equal-timestamp deck/card changes are ignored with a successful
  response. `*_processed` counts describe input records, including ignored
  conflicts and duplicate logs; they are not counts of inserted/changed rows.
  Reconciliation is necessary to read the resolved server state.
- A repeated review-log ID for the same account/card is an idempotent no-op,
  not an update to its rating or history. New logs and accepted edits to reviewed
  cards recompute affected progress; duplicate logs skip expensive recomputation.
- Only an accepted authorized deck deletion cascades to active child cards.
  Whole-deck child tombstones can additionally send `from_deck_deletion: true`;
  these are ignored while their parent is active, protecting separately batched
  children after a rejected/undone deck deletion. Individual-card deletes omit
  the marker. It is not stored in the database or returned in downloads.
- Restore a deleted deck through a newer `is_deleted=false` deck mutation.
  Restoring the deck does not automatically restore its cards: upload newer
  card mutations explicitly after the deck. An active card change against a
  deleted parent is ignored if stale relative to the parent, otherwise rejected.
- A lost response can be retried with the original IDs and timestamps. An
  upload response's `server_time` is UTC at whole-second precision; it is not
  a safe cross-device reconciliation checkpoint.

### Download Changes
`GET /sync/download?since=2026-03-21T00:00:00Z`

Response `200 OK`:
```json
{
  "decks": [
    {
      "id": "uuid",
      "user_id": "uuid",
      "title": "Operating Systems",
      "description": "Short OS review deck",
      "is_public": false,
      "created_at": "2026-03-21T10:00:00Z",
      "updated_at": "2026-03-24T10:00:00Z",
      "version": 3,
      "is_deleted": false
    }
  ],
  "cards": [
    {
      "id": "uuid",
      "deck_id": "uuid",
      "front": "What does a mutex do?",
      "back": "It provides mutual exclusion for critical sections.",
      "state": "review",
      "interval": 6,
      "ease_factor": 2.5,
      "repetition_count": 3,
      "due_timestamp": "2026-03-30T10:00:00Z",
      "last_reviewed_at": "2026-03-24T10:00:00Z",
      "created_at": "2026-03-21T10:00:00Z",
      "updated_at": "2026-03-24T10:00:00Z",
      "version": 4,
      "is_deleted": false
    }
  ]
}
```

Query notes:
- `since` accepts RFC3339 timestamps, including fractional seconds. Invalid
  nonblank values return `400`; omitted/blank values use the Unix epoch.
- Returns owned deck/card records whose individual `updated_at` is strictly
  greater than `since`, including deleted rows and cards in deleted decks.
  Omission therefore returns all post-epoch owned state. Public decks owned by
  someone else are not included.
- Decks and cards are each ordered by `updated_at`, `created_at`, then UUID.
  Empty arrays are `[]`; the response is not paginated and has no review logs.
- Both record lists share one consistent read transaction. Response timestamps
  preserve available fractional precision in UTC RFC3339 form.
- `401` indicates invalid/missing authentication; database/transaction failures
  return `500`.

Sync rules:
- local database is the source of truth while offline,
- the client uploads queued mutations first, then downloads server updates,
- `is_deleted=true` is part of normal sync state,
- conflict resolution is last-write-wins using `updated_at`,
- if timestamps are equal, server data wins,
- direct edit routes increment version numbers; sync writes carry the supplied
  version, and existing database triggers may refresh `updated_at`. Preserve the
  server's returned revisions rather than assuming payload timestamps survive,
- delete beats stale non-delete updates,
- deleted deck/card rows may continue syncing until all devices converge.

---

## ANALYTICS APIs

### Dashboard
`GET /analytics/dashboard?range_days=7|30|90`

Returns the analytics dashboard payload for the authenticated user.

Response shape:
- `username`
- `range_days`
- `generated_at`
- current card/deck counters from the cloud database:
  - `total_decks`
  - `total_cards`
  - `learned_cards`
  - `mature_cards`
  - `new_cards`
  - `learning_cards`
  - `review_cards`
  - `due_now`
  - `due_next_24_hours`
- range metrics from persisted analytics rollups:
  - `reviews_today`
  - `reviews_in_range`
  - `active_days_in_range`
  - `average_study_load`
  - `retention_rate`
  - `best_day_count`
- long-term indicators:
  - `current_streak`
  - `longest_interval_days`
- `rating_breakdown`
- `review_activity`
- `accuracy_trend`
- `deck_insights`

Notes:
- dashboard data is server-backed,
- chart data is sourced from persisted 7 / 30 / 90 day rollups,
- current due/card counters are computed from live deck/card rows,
- the endpoint accepts only `7`, `30`, or `90`.

Omitting `range_days` selects `30`. Invalid/non-integer values return `400`;
authentication failures return `401`, and database failures return `500`.
New review logs accepted through sync refresh persisted analytics in the same
upload transaction. Duplicate-log retries do not repeat that refresh.

### Daily Review Count
`GET /analytics/daily-review-count?from=YYYY-MM-DD&to=YYYY-MM-DD`

Returns number of reviews per day from persisted daily analytics rows.

### Average Session Length
`GET /analytics/average-session-length?from=YYYY-MM-DD&to=YYYY-MM-DD`

Returns average daily review load across active study days in the selected range.

### Accuracy Trends
`GET /analytics/accuracy-trends?from=YYYY-MM-DD&to=YYYY-MM-DD`

Returns correctness percentage over time.

### Deck Performance
`GET /analytics/deck-performance?deck_id=<UUID>`

Returns all-time performance per deck using persisted `user_progress` rows.

### Analytics persistence notes
- `review_logs` remain the global synced source of truth for review history,
- `user_progress` stores per-user, per-deck summary progress,
- `user_card_progress` stores per-user, per-card score/state snapshots,
- `analytics_daily_stats` stores daily aggregated review history,
- `analytics_rollups` stores the current 7 / 30 / 90 day dashboard rollups.

### Midnight UTC maintenance
At `00:00 UTC`, the backend recomputes analytics daily rows and dashboard rollups for active users.

---

## Error Format

```json
{
  "error": "error message"
}
```

### Session restore behavior
- The client persists the JWT and `user_id` locally after a successful login.
- On app launch, the splash flow first checks for a stored session and re-enters the app without prompting for credentials again.
- The login screen should only reappear after an explicit logout or when `GET /me` returns an authentication failure such as `401 Unauthorized` / `403 Forbidden`.
- Temporary connectivity failures must not be treated as logout events by the client.
