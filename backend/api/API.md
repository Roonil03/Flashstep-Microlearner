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

Payload:
{
  "decks": [],
  "cards": []
}

---

### Download Changes (Server → Client)
GET /sync/download?since=2026-03-21T00:00:00Z

Response:
{
  "decks": [],
  "cards": []
}

---

## SYNC RULES

- Uses **updated_at** for conflict resolution
- Last-write-wins
- Supports soft delete (`is_deleted`)
- Supports versioning

---

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