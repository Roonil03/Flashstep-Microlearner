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