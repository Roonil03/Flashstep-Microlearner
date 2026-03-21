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