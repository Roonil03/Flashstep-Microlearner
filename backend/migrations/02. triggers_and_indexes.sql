BEGIN;

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_progress_user_deck
    ON user_progress(user_id, deck_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_deck_collaborators_deck_user
    ON deck_collaborators(deck_id, user_id);

CREATE INDEX IF NOT EXISTS idx_decks_user_id
    ON decks(user_id);

CREATE INDEX IF NOT EXISTS idx_cards_deck_id
    ON cards(deck_id);

CREATE INDEX IF NOT EXISTS idx_cards_due_timestamp
    ON cards(due_timestamp);

CREATE INDEX IF NOT EXISTS idx_review_logs_user_id
    ON review_logs(user_id);

CREATE INDEX IF NOT EXISTS idx_review_logs_card_id
    ON review_logs(card_id);

CREATE INDEX IF NOT EXISTS idx_review_logs_reviewed_at
    ON review_logs(reviewed_at);

COMMIT;

BEGIN;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_decks_updated_at ON decks;
CREATE TRIGGER trg_decks_updated_at
BEFORE UPDATE ON decks
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_cards_updated_at ON cards;
CREATE TRIGGER trg_cards_updated_at
BEFORE UPDATE ON cards
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_user_progress_updated_at ON user_progress;
CREATE TRIGGER trg_user_progress_updated_at
BEFORE UPDATE ON user_progress
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;