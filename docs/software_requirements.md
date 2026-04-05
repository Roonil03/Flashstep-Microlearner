# Software Requirements

## Frontend
- Flutter SDK
- Riverpod
- Drift for local storage

## Backend
- Go (Gin)
- JWT authentication
- REST APIs
- Dockerized deployment

## Storage
- Drift local storage on device
- PostgreSQL on the backend

## System Architecture Flow
User -> Flutter App -> State Management (Riverpod) -> **User-scoped Drift Local Database** -> Sync Engine -> REST API (Go backend using Gin) -> PostgreSQL Database

## Functional Requirements
### User Authentication (JWT)
- sign up
- sign in
- session restore using `/me`
- sign out
- account deletion

### Deck and Card Management
- create / edit / delete decks
- add / edit / delete cards within decks
- browse public decks
- download a public deck as a copy into the current user's account
- view decks and cards

### Spaced Repetition Review
- cards are scheduled using spaced-repetition logic based on SM-2-style state transitions

### Offline DB First
- all user actions save locally first
- sync runs afterward when network is available
- local database remains usable offline

### Local User Isolation
- each signed-in user gets a different local Drift database file
- logging into a new account on the same device must not expose the previous user's decks or cards
- logout switches the app to a guest-local database
- sync cursors are tracked per user

### Background Sync
- sync runs manually and on future background/connectivity triggers
- detects whether a valid session exists
- pushes unsynced local changes first
- fetches updates from backend second
- merges data into the current user's local database only

### Basic Analytics Dashboard
- cards reviewed per day
- retention rates
- study streaks

## UI Pages
1. Analytics Page
2. Splash Screen
   - app logo
   - checks for JWT existence and local session validity
   - restores the correct local user database on startup
   - redirects to login or home
3. Login Page
   - email / password / login button / go-to-register button
4. Register Page
   - email / username / password / confirm password / register button
5. Home Dashboard
   - list of the current user's decks
   - deck of the day
   - quick actions: create deck, start review, browse decks
   - sync indicator
6. Create Deck Page
   - deck name / description / visibility / save button
7. Start Review Page
   - review subpage
   - end-of-review subpage
8. Browse Public Decks Page
   - public deck list
   - download manager
9. Settings
   - app settings page
   - profile settings page
   - sign out
10. Loading / Empty / Error States

## Analytics and review constraints
- Analytics pages must read synced server-side analytics rather than local-only counters.
- Daily review volume defaults to 25 cards per user per day and must be configurable.

### Stored session restore
- if a JWT and `user_id` already exist locally, app launch should restore the user session without asking for credentials again
- transient network failures during splash validation must not force a logout
- the login page should appear only after explicit logout or explicit backend authentication failure
