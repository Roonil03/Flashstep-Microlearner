# Release 1.0.0-pre

## New Features
- **Public Deck Search**: You can now search through public decks seamlessly with a new Bloom Filter-powered search bar on the backend.
- **Home Page Limiting**: The dashboard now limits your displayed decks to 5. You can tap "Explore all" to expand the list inline.
- **Review Shuffling**: Added a shuffle button to the review session page, allowing you to shuffle the remaining cards dynamically.
- **Review All Cards (Ignore Limits)**: Added a new "Review all cards" toggle in system settings that bypasses daily limits and due dates, making all cards in a deck available for study immediately.
- **Change Username**: Added the ability to change your username directly from Account Settings. Changes sync properly with the backend.

## Improvements
- Improved offline experience when browsing public decks by showing an appropriate "No Internet" UI.
- Upgraded app version to 1.0.0-pre.

## Technical Notes
- Backend introduced `github.com/bits-and-blooms/bloom/v3` for fast public deck prefix caching.
- Enhanced `SessionStorage` and Drift repositories for toggling strict SRS limits.
