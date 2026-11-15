BEGIN;

-- No report text, email, username, token, device data or learning data is stored.
CREATE TABLE IF NOT EXISTS bug_report_submissions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content_hash TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'retry')),
    attempts INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_attempt_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, content_hash)
);
CREATE INDEX IF NOT EXISTS bug_reports_created_idx ON bug_report_submissions(created_at);
CREATE INDEX IF NOT EXISTS bug_reports_last_attempt_idx ON bug_report_submissions(last_attempt_at);

-- Each reserved dispatch has its own timestamp; lifetime counters cannot express
-- rolling windows after retries. Events expire after 24 hours during submissions.
CREATE TABLE IF NOT EXISTS bug_report_attempts (
    submission_id UUID NOT NULL REFERENCES bug_report_submissions(id) ON DELETE CASCADE,
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (submission_id, attempted_at)
);
CREATE INDEX IF NOT EXISTS bug_report_attempts_time_idx ON bug_report_attempts(attempted_at);
-- Preserve the known latest attempt if this migration is rerun over an earlier
-- pre-release schema. Earlier lifetime attempts have no recoverable timestamps.
INSERT INTO bug_report_attempts(submission_id, attempted_at)
    SELECT id, last_attempt_at FROM bug_report_submissions
    WHERE last_attempt_at > NOW() - INTERVAL '24 hours'
    ON CONFLICT DO NOTHING;

COMMIT;
