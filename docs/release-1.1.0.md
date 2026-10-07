# Release 1.1.0

Flashstep Microlearner 1.1.0 introduces guided navigation, a more consistent interface, and improved synchronization across devices. This release makes it easier to learn the app, manage your decks, and keep your study data up to date.

## New Features

- **Guided Navigation**: A nine-step walkthrough introduces the main learning workflows using highlighted controls, directional arrows, and clear navigation paths.
- **New Account Onboarding**: Accounts created on your device are introduced to the guide after their first successful login.
- **Replay from Settings**: Choose **Settings → Relearn app navigation** to revisit the walkthrough at any time, starting from the first step.
- **Saved Guide Progress**: An interrupted walkthrough resumes where you left off. Finishing, skipping, or exiting the guide prevents it from reopening automatically. Progress is saved separately for each account on your device.
- **Selective Deck Sync**: Sync checks for changes across your library and downloads only missing or changed decks, improving efficiency for larger collections and repeated syncs.

## Navigation Guide

The walkthrough covers these nine workflows:

1. **Create a deck**: Find **Home → Create deck** and enter a deck title.
2. **Add individual cards**: Open a deck, enter **Front** and **Back**, then choose **Save card**.
3. **Import CSV**: Find **Import CSV** in deck details, learn the `Front,Back` format, and check the preview and remaining card capacity before importing.
4. **Browse your decks**: Use **Home → Browse decks** to explore and search your library.
5. **Use public decks**: Add a public deck as a personal copy, or share your own deck using its public visibility setting.
6. **Customize a public copy**: Edit a downloaded deck and its cards for your own study needs while the original shared deck remains unchanged.
7. **Review decks**: Use **Home → Start review**, select a deck, reveal answers, and rate cards **Again**, **Hard**, **Good**, or **Easy**.
8. **View analytics**: Use **Home → Analytics** to explore your progress over **7**, **30**, or **90 days**.
9. **Adjust review limits**: Find **Home → Settings → System Settings** to configure daily card limits, deck selection, and **Review all cards**.

The guide uses sample screens so you can explore the controls without changing your saved decks or review history. **Back**, **Next**, **Skip tour**, and **Finish** let you move through it at your own pace. Keyboard navigation and scrollable previews help keep instructions and controls accessible.

## Improvements

- **Consistent Themes and Forms**: Registration follows your selected theme, with clearer validation, password visibility controls, and input preserved after errors. Deck and card forms use more consistent styling and helpful hints.
- **Clearer Home Navigation**: Dashboard actions use explicit labels such as **Create deck**, **Browse decks**, and **Start review**, with larger touch targets and keyboard-accessible controls.
- **Responsive Layouts**: Dashboard actions adapt to narrow screens and larger text. System Settings remains scrollable, and analytics date-range controls wrap to fit the available space.
- **Helpful Empty States**: Empty deck libraries and decks without cards explain how to get started.
- **Clearer Public-Deck Actions**: Download and visibility controls explain personal copies, editing, and sharing after sync.
- **Safer Form Submission**: Save actions prevent duplicate submissions and retain entered content when a save fails.
- **Clearer Review Settings**: Daily-limit descriptions explain how **Review all cards** overrides daily limits and due dates.
- **Quicker Login Navigation**: Successful login opens Home without the previous welcome delay.
- **More Resilient Theme Loading**: The app keeps a usable default theme if a saved preference cannot be loaded.

## Sync and Reliability

- **Late Offline Changes**: Sync checks the full deck library for changes, helping other devices receive edits made offline even when those edits carry older timestamps.
- **Efficient Uploads**: Pending changes are sent in manageable batches, and repeated edits to the same deck or card are combined while preserving individual review records.
- **Coordinated Sync Requests**: Manual and automatic sync share an ongoing operation for the same account, avoiding overlapping work.
- **Reliable Retries**: Failed uploads retain pending changes for another attempt. Retried review records are handled without duplicating review history.
- **Protected Local Edits**: Changes still waiting to upload are preserved while server updates are merged. Switching accounts stops further work for the previous session.
- **Safer Deletion and Undo**: Improved conflict handling prevents rejected deck deletions from removing child cards and keeps deletion, restoration, and card-capacity checks consistent during concurrent updates.
- **Consistent Progress and Analytics**: Accepted review uploads update related progress and analytics together.

## Compatibility

Existing decks, cards, and review scheduling remain supported. The updated sync interfaces retain compatibility with earlier clients, and this release requires no database migration. Settings now displays version **1.1.0**.
