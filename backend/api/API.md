# API Documentation

## Base URL
`http://localhost:8080/api/v1`

## Auth Header
Protected routes require:

```http
Authorization: Bearer <JWT_TOKEN>
```

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
- `card_count` counts active cards only.

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
- attempting to download your own public deck should fail.

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
- `400 Bad Request`: invalid payload, invalid UUID, missing required fields, bad references, or deck exceeds 50-card limit
- `401 Unauthorized`: invalid or missing JWT
- `500 Internal Server Error`: server/database error while applying sync

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
- `since` must be an RFC3339 timestamp,
- if omitted, the server returns all visible deck/card state for that user.

Sync rules:
- local database is the source of truth while offline,
- the client uploads queued mutations first, then downloads server updates,
- `is_deleted=true` is part of normal sync state,
- conflict resolution is last-write-wins using `updated_at`,
- if timestamps are equal, server data wins,
- version numbers increment on every logical update,
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
