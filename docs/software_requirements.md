# Software Requirements:

## Front End:
- Flutter SDK using Kotlin
    - Riverpod
    - BLoC

## Back End:
- GoLang (Gin for the main, Fibre for more speed)
- JWT Tokens in GoLang
- REST APIs
- Dockerize the Backend

## Storage:
- Drift Local Storage/ Isar for it based on net
- postgreSQL on firebase
    - Check for CI/CD for hosting it on firebase


## System Architecture Flow:
User    ->      Flutter App     ->      State Management (Riverpod & Bloc)      ->      Local Database (Isar/Drift)     ->      Sync Engine (Background Worker)     ->      REST API(Go Backend using GoFr, Gin and Fiber)      ->     PostgreSQL Database


## Functional Requirements:
### User Authentication (JWT)


### Deck and Call Management:
- Create, Edit, Download from the DB, Delete Decks
- Add/Edit/Delete cards within Decks
- View Decks and Cards

### Spaced Repitition Review:
- Cards are scheduled using spaced repitition algorithms (SM-2 and FSRS[Free Spaced Repitition Scheduler])

### Offline DB First:
- Work mainly with Isar, with Drift, if everything else fails

### Background Sync:
- Sync runs periodically or on connectivity change
    - Detect network availability
    - Push unsynced local changes
    - Fetch updates frmo backend
    - Merge Data into local DB

### Basic Analytics Dashboard
- Cards reviewed per day
- Retention Rates
- Study Streaks

## UI Pages:
1. Analytics Page
2. Splash Screen
    - App Logo
    - Checks for JWT existence and local session validity
    - Redirects either to login or home
3. Login Page
    - email/user; password; login button; *"go to register"* button
4. Register Page
    - email; username; password; confirm password; register button
5. Home Dashboard
    - List of Decks
    - Deck of the Day
    - Quick Actions - Create Deck, Start Review, Browse Decks
    - Sync Indicator
6. Create Decks Page:
    - Deck Name; Descriptiom; Save Button
7. Start Review Page
    - Review Subpage
    - End of Review Subpage
8. Browsing through all decks with description
    - Download Manager
9. Settings
    - App Settings Page
    - Profile Settings Page
10. Loading Pages:
    - Loading / Empty State Screens
    - Error Page

