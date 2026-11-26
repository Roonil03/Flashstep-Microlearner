# Release 1.4.0

Flashstep Microlearner 1.4.0 updates the study flow and how the API handles busy periods.

## Home and your library

- Home opens with today's available cards and **Start review**. You can open a deck, browse your library, create a deck, or check sync status from the same screen.
- Personal and public decks use a searchable list. Library search keeps the result for the latest text you enter, even when an earlier search finishes later.
- Analytics shows the date of the saved snapshot alongside your study progress. Sign-in, Settings, and the offline legal pages share the new light and dark palettes. Registration still uses the opposite theme to distinguish it from sign-in.

## Study reviews

- On **Start review**, each deck shows its available card count and a full-width **Start review** button. If your decks or cards fail to load, use **Try again** on the same screen.
- Choose **Start now** to skip the countdown. During a review, you can see your progress and keep the question in view when you reveal its answer.
- The four ratings appear in a single list with descriptions. **Show answer** gives brief tap feedback that respects reduced motion. If saving fails, the card stays on screen so you can retry.

## Sync and compatibility

- During busy periods, the API limits simultaneous requests from one account and provides a retry interval. Pending offline changes stay on the device until the server acknowledges them.
- The API validates incoming records before writing them. Existing databases use the same schema and require no migration.
