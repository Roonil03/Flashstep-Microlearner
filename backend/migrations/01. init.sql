BEGIN;

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS decks (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    title VARCHAR(255) NOT NULL,
    description TEXT,

    is_public BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS cards (
    id UUID PRIMARY KEY,
    deck_id UUID NOT NULL REFERENCES decks(id) ON DELETE CASCADE,

    front TEXT NOT NULL,
    back TEXT NOT NULL,

    state VARCHAR(20) NOT NULL DEFAULT 'new'
        CHECK (state IN ('new', 'learning', 'review')),

    "interval" DOUBLE PRECISION NOT NULL DEFAULT 0,
    ease_factor DOUBLE PRECISION NOT NULL DEFAULT 2.5,
    repetition_count INT NOT NULL DEFAULT 0,
    due_timestamp TIMESTAMPTZ,
    last_reviewed_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    version INT NOT NULL DEFAULT 1,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS review_logs (
    id UUID PRIMARY KEY,

    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    card_id UUID NOT NULL REFERENCES cards(id) ON DELETE CASCADE,

    rating VARCHAR(10) NOT NULL
        CHECK (rating IN ('again', 'hard', 'good', 'easy')),

    previous_interval DOUBLE PRECISION,
    new_interval DOUBLE PRECISION,

    reviewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    device_id UUID,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_progress (
    id UUID PRIMARY KEY,

    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    deck_id UUID NOT NULL REFERENCES decks(id) ON DELETE CASCADE,

    total_reviews INT NOT NULL DEFAULT 0,
    correct_reviews INT NOT NULL DEFAULT 0,

    current_streak INT NOT NULL DEFAULT 0,
    longest_streak INT NOT NULL DEFAULT 0,

    last_review_date DATE,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    version INT NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS deck_collaborators (
    id UUID PRIMARY KEY,

    deck_id UUID NOT NULL REFERENCES decks(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    role VARCHAR(20) NOT NULL DEFAULT 'viewer'
        CHECK (role IN ('viewer', 'editor', 'owner')),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

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