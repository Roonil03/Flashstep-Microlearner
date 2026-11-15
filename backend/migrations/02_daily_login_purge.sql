-- Run after 01_init.sql, before deploying v1.3.0. Safe to run again.
BEGIN;
CREATE TABLE IF NOT EXISTS login_cleanup_days (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    last_day DATE NOT NULL
);
-- Permanent ID-only receipts prevent offline devices from recreating purged data.
-- parent_id is the historical deck of a card; no content is retained.
CREATE TABLE IF NOT EXISTS purged_entities (
    receipt_id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    entity TEXT NOT NULL CHECK (entity IN ('deck','card')),
    entity_id UUID NOT NULL,
    parent_id UUID,
    purged_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(entity, entity_id)
);
CREATE INDEX IF NOT EXISTS idx_purged_entities_user_receipt ON purged_entities(user_id,receipt_id);
CREATE INDEX IF NOT EXISTS idx_decks_deleted_user_id ON decks(user_id,id) WHERE is_deleted;
CREATE INDEX IF NOT EXISTS idx_cards_deleted_deck_id ON cards(deck_id,id) WHERE is_deleted;

-- Reviews are immutable history, independent of the continued existence of content.
ALTER TABLE review_logs ADD COLUMN IF NOT EXISTS deck_id UUID;
UPDATE review_logs rl SET deck_id=c.deck_id FROM cards c WHERE c.id=rl.card_id AND rl.deck_id IS NULL;
ALTER TABLE review_logs DROP CONSTRAINT IF EXISTS review_logs_card_id_fkey;
CREATE INDEX IF NOT EXISTS idx_review_logs_user_deck ON review_logs(user_id,deck_id);
CREATE OR REPLACE FUNCTION validate_review_history_owner() RETURNS TRIGGER AS $$
DECLARE history_deck UUID;
BEGIN
    SELECT c.deck_id INTO history_deck FROM cards c JOIN decks d ON d.id=c.deck_id
        WHERE c.id=NEW.card_id AND d.user_id=NEW.user_id;
    IF history_deck IS NULL THEN
        SELECT parent_id INTO history_deck FROM purged_entities
            WHERE entity='card' AND entity_id=NEW.card_id AND user_id=NEW.user_id;
    END IF;
    IF history_deck IS NULL THEN
        RAISE EXCEPTION 'invalid review owner or card reference';
    END IF;
    NEW.deck_id := history_deck;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trg_review_history_owner ON review_logs;
CREATE TRIGGER trg_review_history_owner BEFORE INSERT ON review_logs
    FOR EACH ROW EXECUTE FUNCTION validate_review_history_owner();
COMMIT;
