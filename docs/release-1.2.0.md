# Release 1.2.0

Flashstep Microlearner 1.2.0 makes it easier to see when your study data has synced and to adjust the app for comfortable reading.

## New Features

- **Clear Sync Status**: Home shows whether a sync is running, has completed, or needs attention. It keeps the time of your last successful sync visible and offers a labeled **Retry sync** button when you need to try again.
- **App-Wide Font Size**: Choose **Settings → System Settings → Appearance** to set Small, Device default, Large, or Extra large text. Each choice works with your device's text-size setting.
- **Legal Information in One Place**: Choose **Settings → Legal** to read the Privacy Policy, Terms of Service, and open-source licenses.
- **Review History Across Devices**: Sync now brings earlier review ratings to another signed-in device, keeping daily review counts, streaks, and the remaining daily allowance in step.

## Improvements

- **Honest Offline Feedback**: If the device cannot reach the server, Home explains that changes remain on the device. A failed attempt does not appear as a completed sync.
- **Simpler System Settings**: Appearance and Review controls are grouped separately. Theme choices use clear buttons, and the existing daily-card-limit picker remains available.
- **More Accessible Study Flows**: Deck actions and account controls have clearer screen-reader labels. Deck browsing, review controls, and analytics are easier to use with larger text.
- **Smoother Large Libraries**: Home calculates deck and due-card summaries more efficiently, keeping large collections easier to browse.

This release also includes bug fixes for deck-row accessibility, analytics text layout, Home review totals, due-now labels, and Back navigation within Settings.

## Compatibility

Existing decks, cards, and review scheduling continue to work as before. Your theme, font size, and review choices stay on your device. The navigation guide does not restart just because the app was updated. Deploy the v1.2.0 backend before distributing the updated app so review history can sync to other devices. Earlier app versions keep using their existing sync routes. No database migration is required. Settings displays version **1.2.0**.
