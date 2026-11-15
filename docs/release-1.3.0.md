# Release 1.3.0

Flashstep Microlearner 1.3.0 adds public bug reporting and clears deleted study content when you sign in.

## New Features

- **Report a bug from Settings.** Choose **Settings → Report a Bug**, or open it just below **Open-source licenses** in **Legal**. Describe the problem, what you expected, and what happened. You can include steps to reproduce it. Before you submit, the app asks you to confirm that your text can appear in a public GitHub issue.
- **Daily cleanup of deleted cards and decks.** On your first successful login each UTC day, Flashstep permanently removes your account’s deleted cards and decks from the server. You can use Undo while the deleted content is still recoverable. Your past reviews continue to count toward your study history.

## Improvements

- **Offline sync.** A device returning online can learn which cards and decks were permanently removed. An old edit cannot bring back their contents.
- **Offline analytics.** If a refresh fails, the last saved dashboard stays visible. Deleting an account also removes its saved analytics from that device.
- **Clearer error messages.** The app explains when to sign in again, correct an entry, wait, or retry. The API limits request size and concurrent work and checks ownership before accepting changes.
- **Artwork attribution.** Open-source licenses now points to the asset license on the project’s main branch.

## Compatibility

Existing clients can continue using the deck, card and sync endpoints. Operators must apply the PostgreSQL migrations before deploying the backend. Public bug reporting also requires the GitHub workflow and its backend credential. [Installation and upgrade instructions](../INSTALL.md) · [Bug reporting setup](bug_reporting.md)
