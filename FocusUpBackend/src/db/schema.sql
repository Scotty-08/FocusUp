-- FocusUp backend schema.
-- Mirrors the FocusTask model already living in the iOS app's
-- TaskStore.swift (title, isCompleted, dueDate) so syncing is a
-- straight mapping, not a redesign.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Apple's "sub" claim from Sign in with Apple, or a placeholder
    -- identifier for the UI-only email/password flow. One or the
    -- other is required; both may exist if a user links both.
    apple_sub TEXT UNIQUE,
    email TEXT UNIQUE,
    password_hash TEXT,
    display_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT users_has_identity CHECK (apple_sub IS NOT NULL OR email IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    is_completed BOOLEAN NOT NULL DEFAULT false,
    due_date DATE,
    is_active BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Only one active task per user -- mirrors TaskStore.activeTaskID being
-- a single value, not a set, on the iOS side.
CREATE UNIQUE INDEX IF NOT EXISTS one_active_task_per_user
    ON tasks (user_id)
    WHERE is_active;

CREATE INDEX IF NOT EXISTS tasks_user_due_date_idx
    ON tasks (user_id, due_date NULLS LAST);
