# Database Design:
### users:
```SQL
CREATE TABLE users (
    id UUID PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,

    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

    -- Sync metadata
    version INT DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE
);
```
### decks:
```SQL
CREATE TABLE decks (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,

    title VARCHAR(255) NOT NULL,
    description TEXT,

    is_public BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    version INT DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE
);
```
### cards
> Core Table
```SQL
CREATE TABLE cards (
    id UUID PRIMARY KEY,
    deck_id UUID REFERENCES decks(id) ON DELETE CASCADE,

    front TEXT NOT NULL,
    back TEXT NOT NULL,

    -- Scheduler fields
    state VARCHAR(20) CHECK (state IN ('new', 'learning', 'review')) DEFAULT 'new',
    interval FLOAT DEFAULT 0,
    ease_factor FLOAT DEFAULT 2.5,
    repetition_count INT DEFAULT 0,
    due_timestamp TIMESTAMP,
    last_reviewed_at TIMESTAMP,

    -- Metadata
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    version INT DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE
);
```
### review_logs
> CRITICAL FOR SYNC + ANALYTICS
```SQL
CREATE TABLE review_logs (
    id UUID PRIMARY KEY,

    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    card_id UUID REFERENCES cards(id) ON DELETE CASCADE,

    rating VARCHAR(10) CHECK (rating IN ('again', 'hard', 'good', 'easy')),

    previous_interval FLOAT,
    new_interval FLOAT,

    reviewed_at TIMESTAMP NOT NULL,

    device_id UUID,

    created_at TIMESTAMP DEFAULT NOW()
);
```
### user_progress
> ANALYTICS OPTIMIZATION
```SQL
CREATE TABLE user_progress (
    id UUID PRIMARY KEY,

    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    deck_id UUID REFERENCES decks(id) ON DELETE CASCADE,

    total_reviews INT DEFAULT 0,
    correct_reviews INT DEFAULT 0,

    current_streak INT DEFAULT 0,
    longest_streak INT DEFAULT 0,

    last_review_date DATE,

    updated_at TIMESTAMP DEFAULT NOW(),

    version INT DEFAULT 1
);
```
### deck_collaborators 
> OPTIONAL BUT POWERFUL
```SQL
CREATE TABLE deck_collaborators (
    id UUID PRIMARY KEY,

    deck_id UUID REFERENCES decks(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,

    role VARCHAR(20) CHECK (role IN ('viewer', 'editor', 'owner')) DEFAULT 'viewer',

    created_at TIMESTAMP DEFAULT NOW()
);
```
# Local Database Design:
### Card Model:
```Dart
class CardModel {
  String id;
  String deckId;

  String front;
  String back;

  String state; // new | learning | review
  double interval;
  double easeFactor;
  int repetitionCount;

  DateTime dueTimestamp;
  DateTime? lastReviewedAt;

  DateTime updatedAt;
  int version;
  bool isDeleted;

  // LOCAL ONLY
  String syncStatus; // pending | synced | failed
  DateTime? lastSyncedAt;
}
```
### Review Log Model:
```Dart
class ReviewLog {
  String id;
  String userId;
  String cardId;

  String rating;
  double previousInterval;
  double newInterval;

  DateTime reviewedAt;
  String deviceId;

  String syncStatus;
}
```
### Sync Queue:
> Local Only
```Dart
class SyncQueueItem {
  String operationId;
  String type; // create | update | delete | review

  Map<String, dynamic> payload;

  DateTime createdAt;
  bool synced;
}
```