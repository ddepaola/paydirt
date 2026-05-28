-- paydirt_scores migration
-- Run idempotently: this creates the table and index if they don't exist.
-- PostgreSQL 12+

CREATE TABLE IF NOT EXISTS paydirt_scores (
    id          BIGSERIAL PRIMARY KEY,
    initials    CHAR(3)     NOT NULL,
    score       INTEGER     NOT NULL CHECK (score >= 0 AND score <= 9999999),
    depth       INTEGER     NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_paydirt_scores_score
    ON paydirt_scores (score DESC, created_at ASC);
