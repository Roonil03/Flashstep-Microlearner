# Release 0.9.1 (Beta Build 3)

## Flashstep Microlearner for Android

Release 0.9.1 brings the core Flashstep Microlearner experience together into a usable Android build focused on creating decks, learning with spaced repetition, syncing progress, and tracking study activity.

## Included features

### Account and app access
- Sign up with email, username, and password.
- Sign in to an existing account.
- Persistent session restore on app launch, so returning users are taken straight into the app when their saved session is still valid.
- Branded splash experience on launch.

### Home dashboard
- Personalized home screen with your name.
- Quick access to review, deck browsing, deck creation, analytics, and settings.
- Deck-of-the-day style entry point for starting review quickly.
- Due-card visibility from the dashboard.
- Pull-to-refresh behavior for reloading current data.

### Deck management
- Create decks with a title, description, and public/private visibility.
- Browse all of your own decks.
- Open deck details to inspect a deck and its cards.
- Rename and edit deck information.
- Change whether a deck is public or private.
- Delete decks.
- Undo deck deletion within the undo window before local removal is finalized.

### Card management
- Add cards to a deck.
- Edit the front and back of existing cards.
- Delete cards from a deck.
- Undo card deletion within the undo window before local removal is finalized.

### Public deck discovery
- Browse public decks shared by other users.
- View public deck title, description, owner, and card count.
- Download a public deck into your own account as a separate copy.
- Open a downloaded deck directly from the download confirmation flow.

### Review and learning flow
- Dedicated start-review page that lists decks with cards currently due.
- Review sessions with a visual 3–2–1 countdown before study begins.
- Card-by-card study flow with question and answer reveal.
- Review ratings for **Again**, **Hard**, **Good**, and **Easy**.
- Local spaced-repetition scheduling based on an SM-2 style algorithm.
- Review completion flow at the end of a session.
- Daily review cap support so the number of cards shown each day can be controlled.

### Sync and local-first behavior
- Local-first workflow so deck and card changes are saved on-device before cloud sync is attempted.
- Manual sync from the deck experience.
- Upload-then-download sync behavior for keeping server and device data aligned.
- Per-user local database isolation so different accounts on the same device do not mix decks or progress.
- Progress and review activity stored locally during use and then synchronized with the backend when available.

### Analytics
- Full analytics screen available from the home screen.
- Range-based analytics views for **7 days**, **30 days**, and **90 days**.
- Review activity tracking across the selected range.
- Accuracy and retention trend tracking.
- Due-now and upcoming workload visibility.
- Total cards, learned cards, mature cards, and learning pipeline breakdowns.
- Rating breakdown across Again / Hard / Good / Easy responses.
- Deck-level analytics insights, including workload and performance context.
- Neatly branded analytics hero section using the application identity.

### Settings and personalization
- Account settings section.
- Change password flow.
- Delete account flow with confirmation.
- System settings section.
- Theme switching between light mode and dark mode.
- Daily review limit control in settings.
- Sign out from within the app.

### Android user experience
- Mobile-oriented navigation flow for home, decks, review, analytics, and settings.
- App branding integrated into the splash and in-app experience.
- Release-ready feature set aimed at normal phone usage: sign in, create content, study, sync, and track learning.

## What this release is about
Release 0.9.1 is the first near-complete Android-focused feature release of Flashstep Microlearner. It combines account-based study, deck creation and sharing, public deck discovery, spaced repetition review, synchronized analytics, and user personalization into one phone-friendly workflow.
