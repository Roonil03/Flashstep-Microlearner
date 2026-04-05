# The Algorithm Design
## Anki's SM-2 Algorithm:
### Concepts:
- Interval
- Ease Factor (EF)
- Repetition Count
- Due Date

#### Interval
- Fail:
    - Interval: 1 Day
    - Repetition = 0
- Hard:
    - Interval: previous_interval x 1.2
- Good:
    - Interval: previous_interval x EF
- Easy:
    - Interval: previous_interval x EF x 1.3

#### Ease Factor Updates:
- Initial EF = 2.5
```
EF' = EF + (0.1 - (5 - quality) x (0.08 + (5 - quality) x 0.02))
```
- Here:
    - quality belongs to [0-5]
    - constrained such that EF >= 1.3 (min bound)

#### Due Date:
- Due Date = Current Time + Interval
- Stored as timestamp
- Used to determine which cards are "due"

### Adapted Scheduler Design:
#### Card States:
Each card exists in one of the following states:
1. New:
    - Never reviewed
    - Introduced gradually
2. Learning:
    - Recently introduced
    - Short intervals
3. Review:
    - Long-term retention phase
    - SM-2 scheduling

#### Variables:
Each card will store:
- `id`
- `deck_id`
- `state`
- `interval`
- `ease_factor`
- `repetition_count`
- `due_timestamp`
- `last_reviewed_at`
- `updated_at`
- `is_deleted`

### Sync Strategy Design
#### Sync Principles:
- The local Drift database is the source of truth during offline usage.
- Every user session works against that user's own local database file.
- Local writes happen first.
- Sync is eventual-consistency based.
- Operations are:
    - logged locally
    - replayed to the server later

#### Local User Isolation Rules:
- The app uses a separate local SQLite database per signed-in user.
- Logging into a different account switches the active Drift database file instead of reusing the previous account's local cache.
- Logging out switches the app to a guest-local database, so decks from one user cannot appear inside another user's account on the same device.
- Public deck downloads are imported into the currently signed-in user's local database only.

#### Upload (Client -> Server):
- Review logs:
    - all user interactions
    - used for analytics + state reconstruction
- Updated cards:
    - edited cards
    - scheduling updates
- Deck changes:
    - created / updated / deleted decks

#### Download (Server -> Client):
- the signed-in user's latest decks
- the signed-in user's latest cards
- deleted records needed for convergence

#### Sync Order:
1. Save to the local Drift database first.
2. Queue the change locally.
3. If network is available, upload pending local changes.
4. Download latest server changes.
5. Merge them into the current user's local database.

#### Sync Trigger Conditions:
- app launch
- manual sync
- network reconnect / background sync trigger

### Conflict Resolution Strategy
Due to offline-first design, conflicts may occur when the same data is modified on multiple devices.

#### Selected Strategy: Hybrid Approach
A combination of:
1. Last-Write-Wins (Primary)
    - based on `updated_at`
    - fast and simple
2. Versioning (Secondary Safety)
    - each record includes `version`
    - incremented on update
3. Server-Assisted Merge (For Critical Data)
    - reserved for future collaborative deck flows

#### Conflict Handling Rules:
| Scenario                | Resolution       |
| ----------------------- | ---------------- |
| Local newer than server | Overwrite server |
| Server newer than local | Overwrite local  |
| Same timestamp          | Prefer server    |
| Deleted vs updated      | Deletion wins    |

#### Soft Delete Strategy
Instead of removing records immediately from sync state:
```json
"is_deleted": true
```
Ensures:
- sync consistency
- recovery capability
- multi-device convergence

### Sync Data Model
#### Metadata Fields (Required)
Each record must include:
- `id`
- `updated_at`
- `version`
- `is_deleted`

#### Sync Queue (Client-Side)
Local table:
```json
{
  "operation_id": "uuid",
  "type": "create | update | delete | review",
  "payload": {},
  "created_at": "timestamp",
  "synced": false
}
```

#### Per-User Sync Cursor
- `last_sync_at` is stored per user, not globally.
- Switching accounts on the same device must not reuse another user's sync cursor.

## Daily review limit and local scheduler
- The client uses an SM-2 style local scheduler for card reviews.
- The default daily review limit is 25 cards, configurable from System Settings.
- Daily card selection is enforced locally before a review session begins.

