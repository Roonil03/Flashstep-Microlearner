# Release 1.4.0

Flashstep Microlearner 1.4.0 updates the study flow and how the API handles busy periods.

## Study reviews

- On **Start review**, each deck shows its available card count and a full-width **Start review** button. If your decks or cards fail to load, use **Try again** on the same screen.
- Choose **Start now** to skip the countdown. During a review, you can see your progress and keep the question in view when you reveal its answer.
- Each rating includes a short description to help you choose. If saving fails, the card stays on screen so you can retry.

## Sync and compatibility

- During busy periods, the API limits simultaneous requests from one account and provides a retry interval. Pending offline changes stay on the device until the server acknowledges them.
- The API validates incoming records before writing them. Existing databases use the same schema and require no migration.
