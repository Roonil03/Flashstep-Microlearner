# API Documentation

## Base URL
http://localhost:8080/api/v1

---

## AUTH

### Register
POST /auth/register

### Login
POST /auth/login

### Get Current User
GET /me

---

## DECK APIs

### Create Deck
POST /decks

### Get Decks (Private + Public)
GET /decks

### Update Deck
PUT /decks/:id

### Delete Deck (Soft Delete)
DELETE /decks/:id

---

## CARD APIs

### Create Card
POST /cards

### Get Cards of Deck
GET /decks/:deck_id/cards

### Update Card
PUT /cards/:id

### Delete Card (Soft Delete)
DELETE /cards/:id

---

## SYNC APIs (CRITICAL)

### Upload Changes (Client → Server)
POST /sync/upload

Authorization: Bearer <JWT_TOKEN>
Content-Type: application/json

Payload:
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

Response (200):
{
  "status": "synced",
  "decks_processed": 1,
  "cards_processed": 1,
  "review_logs_processed": 1,
  "server_time": "2026-03-24T10:00:01Z"
}

Errors:
- 400 Bad Request: invalid payload, invalid UUID, missing required fields, missing deck/card references, or deck exceeds 50-card limit
- 401 Unauthorized: invalid or missing JWT
- 500 Internal Server Error: server/database error while applying sync

### Download Changes (Server → Client)
GET /sync/download?since=2026-03-21T00:00:00Z

Authorization: Bearer <JWT_TOKEN>

Response (200):
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
  ],
  "server_time": "2026-03-24T10:00:01Z"
}

Rules:
- local database is the source of truth while offline
- the client uploads queued mutations first, then downloads server updates
- conflict resolution is last-write-wins using `updated_at`
- if timestamps are equal, server data wins
- soft delete is respected through `is_deleted`
- version numbers must increment on every logical update

## AUTH HEADER

Authorization: Bearer <JWT_TOKEN>

---

## ANALYTICS APIs

### Daily Review Count
GET /analytics/daily-reviews

Returns number of reviews per day.

---

### Average Session Length
GET /analytics/average-session

Returns average study session duration.

---

### Accuracy Trends
GET /analytics/accuracy

Returns correctness percentage over time.

---

### Deck Performance
GET /analytics/deck-performance

Returns performance per deck (accuracy + total reviews).

---

### Streak Stats
GET /analytics/streak

Returns current and longest streak.

---

---

## AUTH

### Change Password
PUT /auth/change-password

- Protected route (requires JWT)
- Request body must include old and new passwords

Payload:
{
  "old_password": "current_password",
  "new_password": "new_secure_password"
}

Response (200):
{
  "message": "password updated"
}

Errors:
- 400 Bad Request: invalid request (missing fields)
- 401 Unauthorized: old password incorrect

---

### Delete Account
DELETE /auth/delete-account

- Protected route (requires JWT)

Response (200):
{
  "message": "account deleted"
}

Errors:
- 500 Internal Server Error: could not delete account