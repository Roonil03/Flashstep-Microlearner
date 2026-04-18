# Release 0.9.7 (Beta Build 4)

## Flashstep Microlearner for Android

Beta Build 4 extends the Beta Build 3 foundation with a stronger day-to-day study workflow, a more accurate and informative home dashboard, CSV-based deck import, more resilient analytics loading, and production-oriented backend configuration updates. The goal of this build is to make studying, managing decks, and using the app in real conditions feel smoother, more reliable, and more configurable.

## Included changes


### CSV deck import
- Deck detail now includes an **Import CSV** action.
- Users can import cards into a deck from a CSV file.
- Dedicated CSV import flow with preview before import.
- CSV validation rules are enforced before cards are created.
- Import flow is designed around the local-first architecture.
- After import, the app attempts to sync and communicates whether the cards were synced immediately or saved locally for later sync.

### Home dashboard improvements
- Home dashboard due counts now align more closely with the user-configured daily review behavior instead of only reflecting the raw total due count.
- Last sync information is presented more clearly for a better day-to-day user experience.
- Dashboard statistics are now backed by real review activity rather than placeholder values.
- Reviewed today, streak, and retention are surfaced in a more meaningful way on the home screen.
- Home dashboard behavior around refresh and deck selection has been tightened to better reflect the user’s actual review state.

### Review flow and system settings
- New system setting to control how Start Review chooses decks.
- Users can now switch between:
  - only the selective decks chosen by the review algorithm, or
  - all decks that currently have due cards.
- This review-mode preference is persisted as part of the app’s local settings.
- Start Review behavior and the deck list shown to the user now follow the configured review mode more consistently.

### Analytics reliability and error handling
- Analytics loading is more resilient when the device is offline or the server cannot be reached.
- Improved handling for timeout, connectivity, and network/client-side request failures.
- Analytics now surfaces clearer retry-oriented error states instead of failing with a less helpful landing experience.
- Offline analytics failures are distinguished more clearly from generic server-side failures.

### Account and form validation improvements
- Registration now validates password length more clearly.
- Users get earlier feedback when entering a password that is too short.
- This improves the account creation flow and reduces failed registration attempts caused by weak or invalid passwords.

### Settings and usability refinements
- System settings interaction has been refined for smoother daily review limit selection.
- Settings-related layouts and dialogs are more robust during interaction and scrolling.
- Overall settings flow is better aligned with repeated mobile use.

### Backend and deployment readiness
- Frontend API configuration now targets the hosted backend using an HTTPS base URL.
- Render deployment configuration has been added and refined for the backend service.
- Deployment setup includes health checks and environment-variable-driven backend configuration.
- These changes improve the project’s readiness for cloud-hosted testing and production-style deployment.

## What this build is about

Beta Build 4 is a stabilization-and-usability release on top of Beta Build 3. Instead of introducing an entirely new product direction, it strengthens the practical app experience in areas that matter during real usage: more trustworthy dashboard information, more flexible review entry behavior, easier deck population through CSV import, better analytics failure handling, stronger registration validation, and cleaner hosted-backend readiness.

In short, this build moves Flashstep Microlearner from a feature-complete beta toward a more polished and dependable study application for everyday Android use.
