# Release 1.1.0

## New Features

- **Reliable Device Reconciliation**: Every successful sync checks a paged deck manifest, including deleted decks. Missing or changed decks download in bounded pages, so late offline changes are found even when their timestamps precede a device's last sync.
- **Bounded Uploads**: The frontend coalesces overlapping sync requests per account, compacts repeated deck/card edits, retains every distinct review log, and sends batches of at most 200 records and approximately 1 MiB. Failed batches retain pending operations.
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

- **Backend deployment is required. Deploy the additive backend before distributing this frontend.** PostgreSQL migrations, Drift schema, connection-pool defaults, cloud connection settings, and review scheduling remain unchanged. No database migration is required. Existing clients retain `/sync/upload` and `/sync/download` compatibility.
- New authenticated `/sync/manifest` and `/sync/fetch` interfaces use UUID pagination, existing indexes, and built-in PostgreSQL fingerprint functions. They include tombstones, preserve timestamp precision, and validate ownership. See [API reference](../backend/api/API.md) for payloads and limits.
- Sync uploads use request contexts, an account advisory lock, consistent parent-deck locks, bulk revision/capacity checks, and parameterized writes. Direct card creation shares the parent lock to enforce the existing 50-active-card limit under concurrent requests. Cross-account deck/card/review-log collisions are rejected.
- Timestamp-based last-write-wins and server-wins-on-equal remain in effect. A deck deletion cascades only when the authorized deletion wins. Child tombstones created by whole-deck deletion carry an optional causal marker, preventing a rejected parent deletion from later deleting cards in an active deck. Existing PostgreSQL timestamp and capacity triggers remain unchanged.
- Retried review logs are idempotent. Only affected reviewed cards and decks have progress recomputed; accepted review logs refresh analytics within the upload transaction. Duplicate uploads skip expensive progress/analytics work, and analytics failure cannot occur after the upload has committed.
- The frontend protects queued local edits while merging server state in bounded transactions. Account-specific fingerprint files live beside the local database and use atomic replacement. Missing/corrupt files trigger fresh reconciliation; a fingerprint is saved only after all card pages merge. Concurrent changes during pagination are detected on the following sync. Account changes stop further sync work.
- Only a manifest 404/405 selects the compatibility fallback, which downloads full server state without a device-clock checkpoint. This mode costs more bandwidth. Other failures retain pending work and report a retryable failure. Oversized individual upload records are retained rather than silently discarded.
- `API_BASE_URL` is a build-time override for isolated testing. Its default remains `https://flashstep-api.onrender.com/api/v1`; normal debug/release builds need no override. No new dependencies or request throttling were introduced. The suggested limiter, Go build-infrastructure package, and error-aggregation package were unnecessary for this implementation.
- Docker builds exclude secrets and local test artifacts from the context and copy the builder's certificate bundle into the runtime image.
- Registration reads the user ID already returned by the existing API; it does not use the signup token to change authentication behavior.
- Tour state uses existing device secure storage, keyed by account and tour version. It does not sync across devices. Accounts registered elsewhere can replay the guide manually. Reinstallation or unavailable local metadata can remove automatic eligibility.
- Tour-storage failures are nonfatal. Missing or malformed progress does not enroll an existing account or block login.
- Highlight and arrow geometry follows the current layout. Large previews remain scrollable so instructions and controls stay reachable. The guide introduces no timers or global layout listeners during ordinary app use.
- Frontend `test/` and `integration_test/` suites are ignored and remain available locally; previously tracked tests were removed from Git without deleting local files. Generated Kotlin build caches remain ignored.
- Local Android device tests can opt into the separate `.uitest` application ID with `flashstepDeviceTest=true` in `android/gradle.properties`. The committed default is `false`, and release builds always retain the regular application ID. The integration-test dependency is development-only.

## Validation

- `flutter test --no-pub`: **35 tests passed**, with the optional local screenshot-capture test skipped. This includes 24 retained frontend tests and 11 temporary sync regression tests. Temporary tests cover batching/compaction, review-log retention, partial acknowledgments, interrupted pagination, pending-edit protection, account changes, metadata corruption/isolation/failure, compatibility fallback, unchanged downloads, and the deck-deletion marker.
- Eight temporary backend integration tests passed against disposable PostgreSQL, including ownership violations, stale/equal-timestamp conflicts, review retries, atomic rollback, cancelled requests, capacity races, deletion/Undo, paged tombstones, capacity-safe replacement order, and rejected parent deletions. `go test -race ./...` passed inside Linux Docker; `go vet ./...` passed. The host race invocation could not run because its CGO/GCC toolchain was unavailable; Docker provided the race-enabled check.
- Backend Docker images built successfully using the unchanged migration file. The Docker project used disposable credentials, a new volume, loopback-only host ports, and no production environment files or database volumes.
- Two additional connected-phone sync scenarios passed against Docker through ADB reversal. The workflow exercised real signup/login UI, individual card entry, CSV preview/import, offline/reconnect, edits in both directions between independent databases, deletion/Undo, reviews, analytics, public download, and personal-copy customization. Initial reconciliation of **1,000 decks / 55,000 cards** took **15,098 ms**; unchanged reconciliation took **464 ms** and fetched no card bodies. A late tombstone with a 2024 timestamp was found on the next sync and fetched in one card page.
- Additional visual QA: all 10 guide scenes rendered and inspected in both light and dark themes (20 screens), with proper text and icon fonts. Capture outputs remain outside the repository.
- Connected Motorola Edge 20 Fusion (Android 13): **21 device tests passed**, with two host-only file checks skipped. The device layout matrix exercised all 10 guide scenes across portrait/landscape, light/dark themes, and text scales 1.0/1.5/2.0: 120 scene visits without layout exceptions. An ADB screenshot of the guide was visually inspected.
- Coverage includes tour completion and substeps, account isolation, resume, skip/back exit, duplicate-launch prevention, Settings replay, storage failure, keyboard navigation, enlarged-text layouts, signup response parsing, deck/card validation and failed-save recovery, public-copy confirmation, CSV cancellation/validation/capacity, analytics range selection, and saved review preferences.
- `flutter analyze --no-pub`: no errors; 42 pre-existing warnings/information notices remain, including the missing `flutter_lints` include, unused imports/cast, and existing Flutter deprecations. The obsolete counter test error was removed.
- Android debug builds succeed for the isolated device test package using a non-production API URL and for the restored default application configuration. Existing Android SDK/Java tooling warnings remain.
- New backend tests, fixtures, benchmarks, and sync device harnesses were excluded from Git and removed after validation, together with their Docker containers/volume and ADB reversal. Previously existing local frontend tests were preserved.
- Git diff checked for whitespace errors, schema changes, secrets, testing files, local production defaults, and unrelated generated artifacts. No supplied documents or extracted course content were added. Version remains **1.1.0+2**.

## Local Performance Measurements

Measurements compare the previous backend with this implementation using the same disposable accounts: 10, 100, and 1,000 decks, each with 50 active cards and five tombstones. HTTP timings are local samples, not production latency guarantees; CPU contention and response precision affect comparisons.

- A 200-card accepted upload used **612 database statements before and 11 after**, at all three deck counts. Validation now operates on batches instead of issuing ownership/existence/capacity queries for every card.
- Sample HTTP upload latency for 10/100/1,000 decks was **330/227/254 ms before** and **73/78/103 ms after**. Ordinary full-download behavior remains available for older clients.
- Unchanged manifests transferred **980 / 9,530 / 95,094 bytes** for 10/100/1,000 decks, with **zero card-body bytes**. Previous full reconciliation transferred approximately **192 KB / 1.92 MB / 19.21 MB**. At 1,000 decks this reduces the sampled repeated-sync response bytes by about **99.5%**. Sample manifest times were **34/54/359 ms**.
- Three-iteration Go allocation benchmarks for a 200-card upload measured **1,314/1,245/1,293 ms per operation before** and **85/84/106 ms after** at the three sizes. Final allocations were approximately **2.52/2.77/2.92 MB per operation**, compared with **2.06/2.07/2.07 MB before**; allocation counts were **29,594/32,958/36,408**, versus **34,020/34,129/34,203**. Bulk validation trades some temporary memory for fewer database round trips; narrowed revision loading avoids materializing unrelated cards.
- Eight overlapping retries for one 1,000-deck account all succeeded. Sample total wall time was **3,243 ms before** and **272 ms after**. Account-level serialization prevents overlapping upload conflict decisions.

## Verification Limits

TalkBack behavior, production frame-timing comparisons, and live production integration were not verified. Device tests use isolated fixtures rather than creating or modifying production accounts or learning data. The CSV test supplies picker bytes through a plugin mock, then exercises the real preview, import, local repository, and sync; physical file-picker selection was not verified. The second device is modeled with a separate local database and metadata directory on the phone, not a second physical handset. Existing timestamp conflict semantics still depend on supplied timestamps; reconciliation removes checkpoint-related omissions, not all effects of clock skew. Before publishing, smoke-test the deployed backend with the intended client and TalkBack. No merge, tag, or production deployment was performed.
