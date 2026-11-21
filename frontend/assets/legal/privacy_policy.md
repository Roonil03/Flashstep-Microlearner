# Privacy Policy

Placeholder privacy information for Flashstep Microlearner. This page describes current app behavior and unresolved details. It is not a final privacy notice. The legal data controller, privacy contact, effective date, hosting details, retention periods, and regional rights process still need to be identified.

## Quick summary

Flashstep uses account details and study data to provide flashcards, sync, public decks, and analytics. An account-specific local database supports offline study. Account and synced study data are sent to the hosted service. Other signed-in users can browse and copy decks you make public. Account Settings offers a deletion request.

## 1. Information handled

Registration collects a username, email address, and password; the server stores a password hash. The app handles deck and card content, CSV files selected for import, review activity, scheduling and analytics data, settings, account identifiers, sync timestamps, and deletion flags. It stores a sign-in token and device identifier. Standard API request logs can include network details such as IP address, route, status, and timing.

## 2. How information is used and shared

Account details authenticate users and keep study data separate. Study data supports review, sync, progress, and analytics. Public decks and their cards are available to other signed-in users for browsing and copying. The production API uses a Render-hosted address and PostgreSQL. The actual hosting and database providers, regions, subprocessors, and transfer safeguards require verification. No advertising, payment, or third-party tracking SDK is currently included in the inspected app.

## 3. Local data, retention, and security

Report a Bug sends only the text you deliberately enter, after a separate confirmation to publish it publicly, to GitHub Actions and then to a public issue in Roonil03/Flashstep-Microlearner. Anyone can read or copy that issue. The app does not automatically attach your account details, logs, device identifiers, or study data. Remove private information from your report before confirming. The service verifies your account and keeps bounded abuse-prevention metadata in backend memory. This includes opaque account and report identifiers, submission status, and attempt timestamps. Report text is sent for publication and is not stored in the service database. In-memory submission metadata expires after 30 days, and quota attempt timestamps expire after 24 hours, with expired entries cleared during later submissions. Restarting the server clears this memory. An opaque report identifier derived from your account and report text helps the GitHub workflow detect duplicates across restarts. GitHub workflow event data and public issues have separate retention under GitHub's policies. Account deletion does not delete an already published issue or its copies; contact the repository maintainers about removing sensitive content.

The app keeps an account-specific database for offline use and sends queued changes to the API when syncing. Signing out clears the active session but leaves that local database. When you delete a deck or card, the server keeps a deletion flag and review history so other devices can update their libraries. Deleting your account removes its local database on that device and disables sign-in. The server keeps the account marked deleted for at least 24 hours. A later maintenance check permanently removes the account and its associated decks, cards, review history, and analytics. Backups, host logs, and support messages may have different retention periods that must be verified. The default production API uses HTTPS, and protected routes require authentication.

## 4. Choices and future notice

Users can edit study content and settings, control whether a deck is public, and request account deletion in Account Settings. Additional access, correction, deletion, portability, objection, restriction, and complaint rights may apply by location. A final notice must identify how to exercise those rights. Material changes to data practices will be communicated with appropriate notice; where consent is legally required, it will be requested through a separate affirmative choice. Creating an account under this placeholder does not grant consent to future practices.

## 5. Open decisions

The final notice must state the data controller and privacy contact, effective date, providers and processing locations, legal bases where applicable, verified retention periods, international transfer arrangements, children's privacy rules, and regional rights procedures. Users should consult the final notice when published for those details.
