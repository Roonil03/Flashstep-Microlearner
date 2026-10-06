# Release 1.1.0

## New Features

- **Guided Navigation**: A nine-step guide explains the main learning workflows with highlighted controls, directional arrows, navigation paths, and safe examples. Public-deck usage has two substeps within step 5, so the guide keeps nine numbered steps.
- **New Account Onboarding**: Accounts registered in this installation start the guide after their first successful login. Signup still leads to the login screen. Existing users are not automatically enrolled.
- **Replay from Settings**: Choose **Settings → Relearn app navigation** to restart the guide at step 1. Finishing, skipping, or exiting returns to the screen that opened it.
- **Saved Tour Progress**: Interrupted guides resume locally. Finish, Skip tour, and explicit exit suppress automatic reopening. Progress is isolated by account and tour version; logout does not erase it.

## Navigation Guide

1. **Create a deck**: Home → Create deck. Give the deck a title before adding cards.
2. **Make individual cards**: Open a deck, enter Front and Back, then Save card.
3. **Import CSV**: Open a deck → Import CSV. Use the `Front,Back` header and check the preview before confirming. Existing cards count toward the 50-card deck capacity.
4. **Browse decks**: Home → Browse decks. Search your library and open a deck to view its cards.
5. **Use public decks**: Browse decks → Browse public decks → Add to my decks creates a personal copy. To publish your own deck, use Make this deck public during creation or editing, then save and sync.
6. **Customize a public copy**: Open your downloaded copy and use the deck or card actions menu to edit it. Changes affect your copy, not the original.
7. **Review decks**: Home → Start review. Choose a deck, reveal the answer, and rate Again, Hard, Good, or Easy.
8. **View analytics**: Home → Analytics. Select 7, 30, or 90 days to inspect synced learning progress.
9. **Adjust daily limits**: Home → Settings → System Settings. Change cards per day, selective deck review, or Review all cards. Review all cards overrides daily limits and due dates.

The guide is a presentation-only preview: it never saves example decks/cards, invokes sync, downloads public decks, opens file pickers, or records reviews. Underlying preview actions are blocked. Back, Next, Skip tour, and Finish control the guide; keyboard users can use Tab/Enter, left/right arrows, and Escape.

## Improvements

- Registration now follows the selected app theme, validates fields inline, allows password visibility control, and preserves input after errors.
- Dashboard actions use keyboard-accessible Material buttons, clearer labels, and generous touch targets. They stack on narrow screens or with enlarged text; the sync badge wraps its text without overflowing.
- Deck creation and card entry use consistent field styling and explanatory hints. Saves are guarded against duplicate submissions, and failed saves retain entered content.
- Public-deck actions explicitly describe adding an editable personal copy. Publication controls explain visibility after sync.
- Empty-library and empty-card messages now explain how to get started.
- System Settings scrolls on small screens and with enlarged text. Daily-limit text explains the Review all cards override.
- Analytics range controls share their presentation with the guide and wrap consistently.
- Login proceeds to Home without the previous artificial welcome delay.
- Theme preference loading retains a usable default if device storage fails and avoids updating a disposed theme controller.
- The app package and Settings display now report version **1.1.0** (build **2**).

## Technical Notes

- Frontend-only release: backend APIs, PostgreSQL migrations, Drift schema, deck/card repositories, CSV parsing, sync services, review scheduler, and review repository are unchanged. No backend deployment or database migration is required.
- Registration reads the user ID already returned by the existing API; it does not use the signup token to change authentication behavior.
- Tour state uses existing device secure storage, keyed by account and tour version. It does not sync across devices. Accounts registered elsewhere can replay the guide manually. Reinstallation or unavailable local metadata can remove automatic eligibility.
- Tour-storage failures are nonfatal. Missing or malformed progress does not enroll an existing account or block login.
- Highlight and arrow geometry follows the current layout. Large previews remain scrollable so instructions and controls stay reachable. The guide introduces no timers or global layout listeners during ordinary app use.
- Frontend `test/` and `integration_test/` suites are ignored and remain available locally; previously tracked tests were removed from Git without deleting local files. Generated Kotlin build caches remain ignored.
- Local Android device tests can opt into the separate `.uitest` application ID with `flashstepDeviceTest=true` in `android/gradle.properties`. The committed default is `false`, and release builds always retain the regular application ID. The integration-test dependency is development-only.

## Validation

- `flutter test --no-pub`: **24 tests passed**, with the optional local screenshot-capture test skipped in ordinary runs.
- Additional visual QA: all 10 guide scenes rendered and inspected in both light and dark themes (20 screens), with proper text and icon fonts. Capture outputs remain outside the repository.
- Connected Motorola Edge 20 Fusion (Android 13): **21 device tests passed**, with two host-only file checks skipped. The device layout matrix exercised all 10 guide scenes across portrait/landscape, light/dark themes, and text scales 1.0/1.5/2.0: 120 scene visits without layout exceptions. An ADB screenshot of the guide was visually inspected.
- Coverage includes tour completion and substeps, account isolation, resume, skip/back exit, duplicate-launch prevention, Settings replay, storage failure, keyboard navigation, enlarged-text layouts, signup response parsing, deck/card validation and failed-save recovery, public-copy confirmation, CSV cancellation/validation/capacity, analytics range selection, and saved review preferences.
- `flutter analyze --no-pub`: no errors; 42 pre-existing warnings/information notices remain, including the missing `flutter_lints` include, unused imports/cast, and existing Flutter deprecations. The obsolete counter test error was removed.
- Android debug builds succeed for the isolated device test package using a non-production API URL and for the restored default application configuration. Existing Android SDK/Java tooling warnings remain.
- Git diff checked for whitespace errors, unexpected backend/schema changes, and unrelated generated artifacts. No supplied documents or extracted course content were added.

## Verification Limits

TalkBack behavior, production frame-timing comparisons, and live production integration were not verified. Device tests use isolated fixtures rather than creating or modifying production accounts or learning data. Widget semantics and keyboard behavior were tested, and the existing scheduling/sync implementations were preserved. Before publishing, smoke-test live sign-in, sync, reviews, deletion/Undo, and TalkBack on the intended device; no production deployment was performed as part of this change.
