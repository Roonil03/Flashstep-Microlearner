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
    - Repitition = 0
- Hard:
    - Interval: previous_interval x 1.2
- Good:
    - Interval: previous_interval x EF
- Easy:
    - Interval: previous_internal x EF x 1.3

#### Ease Factor Updates:
- Initial EF = 2.5
```
EF' = EF + (0.1 - (5 - quality) x (0.08 + (5 - quality) x 0.02))
```
- Here:
    - quality belongs to [0-5]
    - constrainted such that EF >= 1.3 (min bound)

#### Due Date:
- Due Date = Current Time + Interval
- Stored as timestamp
- Used to determine which cards are "due"

### Adapted Scheduler Design:
#### Card States:
Each card exists in one of the following states:
1. New:
    - Never Reviewed
    - Introduced gradually
2. Learning:
    - Recently introduced
    - Short Intervals
3. Review:
    - Long Term Retention Phase
    - SM-2 Scheduling
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

### Sync Stratergy Design:
#### Sync Principles:
- Local DB is source of truth during offline usage
- Sync is eventual consistency-based
- Operations are: 
    - Logged locally
    - Replayed to server

#### Upload (Client -> Server):
- Review Logs:
    - All user interactions
    - Used for analytics + state reconstruction
- Updated Cards:
    - Edited Cards
    - Scheduling Updates
- Deck Changes:
    - Created/updated/deleted decks

#### Download (Server -> Client):
- New decks (public or collaborative [collaborative is editing already premade decks that are uploaded])
- Updated Cards
- Deleted Records

#### Sync Trigger Condititions:
- App Launch
- Network Reconnect
- Periodic Background Job

### Conflict Resolution Strategy
Due to offline-first design, conflicts may occur when the same data is modified on multiple devices.

#### Selected Strategy: Hybrid Approach
A combination of:
1. Last-Write-Wins (Primary)
    - Based on updated_at timestamp
    - Fast and simple

2. Versioning (Secondary Safety)
    - Each record includes version
    - Incremented on update

3. Server-Assisted Merge (For Critical Data)
    - Used for:
        - Collaborative decks
        - Shared edits

#### Conflict Handling Rules:
| Scenario                | Resolution       |
| ----------------------- | ---------------- |
| Local newer than server | Overwrite server |
| Server newer than local | Overwrite local  |
| Same timestamp          | Prefer server    |
| Deleted vs updated      | Deletion wins    |

#### Soft Delete Strategy
Instead of removing records:
```JSON
"is_deleted": true
```
Ensures:
- Sync consistency
- Recovery capability

### Sync Data Model
#### Metadata Fields (Required)
Each record must include:
- `id`
- `updated_at`
- `version`
- `is_deleted`
#### Sync Queue (Client-Side)
Local table:
```JSON
{
  "operation_id": "uuid",
  "type": "create | update | delete | review",
  "payload": {},
  "created_at": timestamp,
  "synced": false
}
```