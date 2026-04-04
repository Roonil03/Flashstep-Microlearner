# Database Design:
### users:
```sql
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
```sql
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
```sql
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
> Critical for sync + analytics
```sql
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
> Analytics optimization
```sql
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
> Optional future table
```sql
CREATE TABLE deck_collaborators (
    id UUID PRIMARY KEY,

    deck_id UUID REFERENCES decks(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,

    role VARCHAR(20) CHECK (role IN ('viewer', 'editor', 'owner')) DEFAULT 'viewer',

    created_at TIMESTAMP DEFAULT NOW()
);
```

# Local Database Design
## Isolation Model
The client now uses a **user-oriented local database design**:
- one Drift SQLite database file per signed-in user
- one guest-local database file when no user is signed in
- account switching changes the active local database file
- decks, cards, review logs, and sync queue items never mix between users on the same device

### Local Database File Naming
Example shape:
```text
app_guest_v2.sqlite
app_user_<sanitized_user_id>_v2.sqlite
```

This means local isolation is enforced by **database-file separation**, not just by clearing rows on logout.

## Local Deck Model
```dart
class DeckModel {
  String id;
  String userId;

  String title;
  String? description;
  bool isPublic;

  DateTime createdAt;
  DateTime updatedAt;
  int version;
  bool isDeleted;
}
```

## Local Card Model
```dart
class CardModel {
  String id;
  String deckId;

  String front;
  String back;

  String state; // new | learning | review
  double interval;
  double easeFactor;
  int repetitionCount;

  DateTime? dueTimestamp;
  DateTime? lastReviewedAt;

  DateTime createdAt;
  DateTime updatedAt;
  int version;
  bool isDeleted;
}
```

## Local Review Log Model
```dart
class ReviewLog {
  String id;
  String userId;
  String cardId;

  String rating;
  double previousInterval;
  double newInterval;

  DateTime reviewedAt;
  String deviceId;

  String syncStatus; // pending | synced | failed
}
```

## Local Sync Queue
> Local only
```dart
class SyncQueueItem {
  String operationId;
  String type; // create | update | delete | review
  String entity;

  Map<String, dynamic> payload;

  DateTime createdAt;
  bool synced;
}
```

## Local Session Rules
- login switches to that user's database file
- logout switches to the guest database file
- delete-account removes the deleted user's local database file after server-side deletion succeeds
- `last_sync_at` is tracked per user so one user's sync cursor does not affect another user's merge window
