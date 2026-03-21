# Flashcards Backend API Documentation

Base URL:
http://localhost:8080/api/v1

---

## Authentication APIs

### Register User

POST /auth/register

Request:
{
  "username": "string",
  "email": "string",
  "password": "string (min 8 chars)"
}

Response:
201 Created
{
  "user": {
    "id": "uuid",
    "username": "string",
    "email": "string",
    "created_at": "timestamp",
    "updated_at": "timestamp"
  },
  "token": "jwt_token"
}

Errors:
- 400 Bad Request
- 409 Email already exists

---

### Login User

POST /auth/login

Request:
{
  "email": "string",
  "password": "string"
}

Response:
200 OK
{
  "user": {
    "id": "uuid",
    "username": "string",
    "email": "string",
    "created_at": "timestamp",
    "updated_at": "timestamp"
  },
  "token": "jwt_token"
}

Errors:
- 401 Invalid credentials

---

### Get Current User

GET /me

Headers:
Authorization: Bearer <token>

Response:
200 OK
{
  "id": "uuid",
  "username": "string",
  "email": "string",
  "created_at": "timestamp",
  "updated_at": "timestamp"
}

Errors:
- 401 Unauthorized

---

## Deck APIs

### Create Deck
POST /decks

### Get Decks
GET /decks

### Update Deck
PUT /decks/:id

### Delete Deck
DELETE /decks/:id

---

## Card APIs

### Create Card
POST /cards

### Get Cards
GET /cards?deck_id=<id>

### Update Card
PUT /cards/:id

### Delete Card
DELETE /cards/:id

---

## Review APIs (Upcoming)

POST /reviews
- Submit review log
- Update scheduling

---

## Sync APIs (Upcoming)

POST /sync/upload
GET /sync/download?since=<timestamp>

---

## Analytics APIs (Upcoming)

GET /analytics/daily-reviews
GET /analytics/accuracy
GET /analytics/streaks

---

## Authentication Notes

- JWT required for all protected routes
- Token format:
  Authorization: Bearer <token>

---

## Status Codes

200 OK
201 Created
400 Bad Request
401 Unauthorized
404 Not Found
409 Conflict
500 Internal Server Error