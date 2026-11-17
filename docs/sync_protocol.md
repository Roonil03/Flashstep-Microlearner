# Deletion cleanup and device reconciliation

Version 1.3.0 uses the PostgreSQL schema from version 1.2.0. Deleted accounts become eligible for permanent removal after 24 hours, decks after 10 seconds, and individual cards after 2 seconds. Backend request activity triggers cleanup, including when the service resumes after sleeping. Each request processes a limited deletion batch, so a backlog can take multiple requests to clear. Candidate scans still depend on the size of the existing tables and their indexes.

Server timestamps start the deletion grace period. Repeated tombstone uploads do not restart it. Children of a deleted deck remain protected by the deck's grace period. Account locks serialize content cleanup with uploads, and cleanup operates only on the authenticated user's content. Deleted account cleanup runs across eligible accounts because deleted accounts can no longer authenticate.

The existing foreign keys cascade physical card deletion into its review logs and progress rows. Physical deck deletion also removes its cards and associated progress. Historical analytics derived from those logs can change. This design supplies no durable deletion receipt table.

## Updated client protocol

Manifest and fetch responses advertise `reconciliation_version: 1`. Uploads opt in with the same top-level field. Decks and cards use `allow_create: true` only when their original creation remains unacknowledged in the local queue. Ordinary edits to missing records are reported in the response instead of creating a row. The response identifies missing decks, cards, and reviews that could not be accepted.

Clients compare complete manifest and card-page results with local records. Partial or failed enumeration must not delete local data. Pending new creations, unsent reviews, and active Undo operations remain protected. A deck removed during pagination is explicitly identified in `missing_deck_ids`. Failed new creations and reviews remain pending with a visible sync warning.

The client holds pending deletions while the Undo notification is available, including extended accessibility interaction. Once the notification closes without Undo, synchronization can send the deletion. The server grace period begins when it accepts that deletion. Normal Undo windows are 10 seconds for decks and 2 seconds for individual cards.

Existing clients retain their legacy upsert behavior. They can recreate an absent UUID because permanent deletion history is unavailable. An unacknowledged new creation retried after it was accepted and later purged has the same ambiguity. The updated protocol improves ordinary edit reconciliation while preserving this documented limitation of the existing database design.

## Batching and account isolation

Deck titles accept up to 255 Unicode characters, matching PostgreSQL `VARCHAR(255)`. Description, front, and back retain their historical `TEXT` behavior within the HTTP request size limit. Sync batches target 1 MiB and 200 operations. Invalid JSON and oversized queued operations remain locally available. Atomic validation failures are split to isolate rejected operations so valid changes can proceed. Remaining rejected changes produce a warning and leave the last successful sync time intact.

Account metadata deletion invalidates active sync sessions and serializes manifest writes with removal of final and temporary files. A response from a deleted session cannot recreate that account's manifest.
