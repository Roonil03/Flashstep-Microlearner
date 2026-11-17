# Release 1.3.0

Flashstep Microlearner 1.3.0 adds public bug reporting, timed notifications, and cleanup of deleted content while you use the app.

## New Features

- **Report a bug from Settings.** Choose **Settings → Report a Bug**, or open it just below **Open-source licenses** in **Legal**. Describe the problem, what you expected, and what happened. You can include steps to reproduce it. Before you submit, the app asks you to confirm that your text can appear in a public GitHub issue.
- **Cleanup when the service is active.** Deleted accounts become eligible for permanent removal after 24 hours, decks after 10 seconds, and individual cards after 2 seconds. Cleanup runs when requests reach the backend, including after it wakes from inactivity. Removal can happen later if the service is sleeping. The app offers Undo for 10 seconds after deleting a deck and 2 seconds after deleting a card.

## Improvements

- **Offline sync.** Updated devices reconcile records that have disappeared from the server and distinguish new offline content from edits to previously synced content.
- **Notifications that dismiss automatically.** Action messages close after their allotted time, with additional time available when accessibility navigation is enabled.
- **Offline analytics.** If a refresh fails, the last saved dashboard stays visible. Deleting an account also removes its saved analytics from that device.
- **Clearer error messages.** The app explains when to sign in again, correct an entry, wait, or retry. The API limits request size and concurrent work and checks ownership before accepting changes.
- **Artwork attribution.** Open-source licenses now points to the asset license on the project’s main branch.

## Compatibility

The backend uses the existing database design and requires no migration from version 1.2.0. Its existing relationships remove associated review logs when cards or decks are permanently deleted, which can change historical analytics. Public bug reporting requires the GitHub workflow and its backend credential. [Installation and upgrade instructions](../INSTALL.md) · [Bug reporting setup](bug_reporting.md)
