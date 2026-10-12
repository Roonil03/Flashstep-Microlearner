# Privacy Policy

Draft for Flashstep Microlearner, published under the Roonil03 project label.

This draft is for information only, is not legal advice, and must be reviewed by a qualified privacy attorney before publication or reliance as a binding notice.

Open items: [DECISION NEEDED] legal operator identity, privacy contact and mailing address, effective date, hosting and database processor identities and locations, log retention, international transfer arrangements, and regional rights procedures. [LAWYER REVIEW] legal bases, children's privacy, retention, and cross-border compliance.

## Quick summary

Flashstep helps you create, share, sync, and review flashcards. It uses your account details, deck and card content, review activity, and preferences to provide those features. Some information stays on your device; account and synced study data are sent to the hosted service. Public decks can be viewed and copied by other users. You can edit your content and request account deletion in the app. Details and unresolved items appear below.

## 1. Who this covers

This policy describes the Flashstep Microlearner mobile app and its hosted API. The project is labeled Roonil03. [DECISION NEEDED] Identify the legal data controller, its address, privacy contact, effective date, and countries where the service is offered.

## 2. Information you provide

Registration collects a username, email address, and password. The server stores a password hash rather than the password itself. You provide deck names and descriptions, card fronts and backs, CSV contents selected for import, public visibility choices, and review ratings. If you contact the project outside the app, the information you send through that channel may also be received; [DECISION NEEDED] identify the support channel and its retention.

## 3. Information created while you use the app

The app and service record review history, card scheduling and progress, analytics summaries, account and content identifiers, update times, deletion flags used for sync, and settings such as daily review limits. The app stores a sign-in token, an app device identifier, onboarding state, theme preference, and account-specific local data. The API's standard request logger records requests, which may include network information such as IP address, route, response status, and timing. [DECISION NEEDED] Confirm hosting logs and their retention with the provider.

## 4. How information is collected

We receive data when you register, sign in, edit content, import a CSV, review cards, change settings, or sync. The app reads only a CSV file that you select for import. It stores a local account-specific database for offline use and sends queued changes to the hosted API when syncing. The API also creates operational request logs. The inspected app has no advertising, payment, or third-party behavior-tracking SDK; review this statement again whenever integrations change.

## 5. Why information is used

Account details authenticate you and keep study data tied to your account. Decks, cards, review history, and preferences support studying, sync, progress displays, and analytics. Public visibility enables other users to browse and make their own copies of a shared deck. Operational logs help run and troubleshoot the API. [LAWYER REVIEW] Confirm the applicable legal basis for each purpose in each jurisdiction; do not treat account creation as consent for unrelated processing.

## 6. Public decks and sharing

When you mark a deck public, its deck details and cards are available to other signed-in users through public browsing. They can make personal copies. Editing a copy does not edit the original. Do not put private information in content you make public. [LAWYER REVIEW] Confirm whether public author or account identifiers are exposed by the current API response before publication.

## 7. Service providers and transfers

The production API uses a Render-hosted address and a PostgreSQL database. [DECISION NEEDED] Verify the actual hosting and database providers, storage regions, subprocessor list, and any international transfers or safeguards before publication. The app also uses open-source libraries; their licenses are available from Settings. We may disclose information if required by valid law. This draft does not claim that data is never sold or shared for every legal definition of those terms; [DECISION NEEDED] verify the service's practices and make the required regional disclosures.

## 8. Retention and deletion

Account and synced study records remain while an account is active unless you delete content. Deleted decks and cards can remain as sync tombstones so devices converge. Deleting an account marks the server account deleted immediately and removes that account's local database on the device used; a scheduled server cleanup attempts to purge deleted users daily at 00:00 UTC. Successful final removal can take longer if the service or cleanup is unavailable, and backups or host logs may have separate retention. Signing out clears the active session but does not erase the local account database. [DECISION NEEDED] Set verified retention periods for logs, backups, tombstones, and support messages.

## 9. Your choices and rights

You can update your username, password, decks, cards, public visibility, and review settings in the app. You can delete your account in Account Settings. Access, correction, deletion, portability, objection, restriction, and complaint rights may apply where you live. [DECISION NEEDED] Provide a privacy contact and verified process for requests the app cannot handle directly. [LAWYER REVIEW] Confirm regional rights, verification, and response deadlines before publication.

## 10. Local storage, cookies, and security

The mobile app uses a local database, app storage, and secure storage for study data, preferences, and the sign-in token. It does not use browser cookies for its normal app flow. Connections to the default production API use HTTPS. The server stores password hashes and authenticates protected API routes. No system can guarantee perfect security. [LAWYER REVIEW] Confirm hosting encryption, access controls, incident practices, and any web-client cookie disclosures before making broader security claims.

## 11. Children

The intended audience is age 13 and above. The app does not currently verify age or collect parental authorization. Rules for teenagers differ by location. [LAWYER REVIEW] Decide where the service may be offered and what age checks or parental authorization may be necessary before publication.

## 12. Policy changes and contact

We may update this policy when data practices change. [DECISION NEEDED] Set an effective date, a contact email and mailing address, and a method for notifying users about material changes. Until those details are completed, users should not rely on this draft as a final privacy notice.

This draft requires review and approval by a qualified privacy attorney before publication. It is not legal advice.
