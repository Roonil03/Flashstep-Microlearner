# Release 1.3.0

Flashstep Microlearner 1.3.0 adds public bug reporting, timed notifications, and safer sync for existing libraries.

## New Features

- **Report a bug from Settings.** Choose **Settings → Report a Bug**, or open it just below **Open-source licenses** in **Legal**. Describe the problem, what you expected, and what happened. You can include steps to reproduce it. Before you submit, the app asks you to confirm that your text can appear in a public GitHub issue.
- **Undo and sync across devices.** You have 10 seconds to undo a deck deletion and 2 seconds to undo a card deletion. The server keeps the deletion flag and associated review history so a device that was offline can catch up later.

## Improvements

- **Offline sync.** Updated devices reconcile records that have disappeared from the server and distinguish new offline content from edits to previously synced content.
- **Safer retries.** Sending the same card ID again keeps a single card. A retry without an edit timestamp needs a newer revision to replace an existing edit. Cards created separately keep their own study histories, even when their text matches.
- **Notifications that dismiss automatically.** Action messages close after their allotted time, with additional time available when accessibility navigation is enabled.
- **Offline analytics.** If a refresh fails, the last saved dashboard stays visible. Deleting an account also removes its saved analytics from that device.
- **Clearer error messages.** The app explains when to sign in again, correct an entry, wait, or retry. The API limits request size and concurrent work and checks ownership before accepting changes.
- **Artwork attribution.** Open-source licenses now points to the asset license on the project’s main branch.

## Compatibility

Existing libraries use the same PostgreSQL schema as version 1.2.0 and require no migration. Public bug reporting requires the GitHub workflow and its backend credential.

Deleting your account disables sign-in immediately. Its data remains on the server for at least 24 hours. A later background check permanently removes the account and its associated data when the service is active.
