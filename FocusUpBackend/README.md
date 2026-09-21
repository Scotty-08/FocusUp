# FocusUp Backend

> **Superseded:** FocusUp's server is now Supabase -- see `../supabase/`. This Node backend is kept for reference and is not used by the app.

A real Node.js + TypeScript + PostgreSQL API for FocusUp: accounts
(Sign in with Apple, plus email/password) and task sync. Built
alongside the `FocusUpSpike` iOS project, but as its own thing — the
iOS app is not wired up to call it yet (see "Status" below).

## Why this stack

Chosen to match what actually shows up in 2026 SWE-intern and
full-stack job postings, not what's flashiest: Node.js + TypeScript +
React + PostgreSQL is the single most-quoted combination across
current listings, with cloud deployment (AWS) and CI/CD treated as
table stakes rather than extras. This project covers the backend half
of that (Node/TS/Postgres/CI), deliberately kept framework-light
(Express, not Nest or similar) so the actual engineering — schema
design, auth, testing, request validation — stays visible instead of
hidden behind a framework's conventions.

## What's actually implemented, not just scaffolded

- **Two real auth paths**: Sign in with Apple (verifies the identity
  token against Apple's public keys via `jose`, does not just trust
  it) and email/password (`bcryptjs` hashing, timing-safe-ish login
  that hashes even on a nonexistent email so response time doesn't
  leak account existence).
- **App-issued session tokens** (JWT, `jsonwebtoken`) separate from
  Apple's identity token — the identity token proves who someone is
  once, at sign-in; the session token is what every later request
  actually uses.
- **The same active-task rule as the iOS app**, ported on purpose:
  earliest due date first, same-day ties broken randomly, no due date
  = least urgent, and an in-progress task never gets bumped by
  something newer becoming due sooner. See `src/utils/activeTask.ts`
  and compare with `TaskStore.swift` in the iOS project — if these
  two ever drift apart, the app and the account will disagree about
  what's "active".
- **Request validation** with `zod` on every route that takes a body.
- **Real tests**, not placeholders: a pure unit-test suite for the
  active-task picker (no DB needed) and an integration suite that
  exercises the whole HTTP + Postgres stack with `supertest` against
  a real (test) database.
- **CI** (`.github/workflows/ci.yml`): typecheck, lint, build, and the
  full test suite, against a real Postgres service container — not a
  mocked DB.

## What's NOT done yet

- The iOS app doesn't call any of this. `AuthView.swift`'s Sign in
  with Apple button and the email/password form are both still local
  to the app. Wiring the app to actually hit `/auth/apple` or
  `/auth/signup` + storing the session token + calling `/tasks`
  instead of (or alongside) the local `TaskStore` is real work,
  deliberately not done here without asking first.
- No deployment yet. Free-tier-friendly options once this is ready:
  AWS (Lambda + RDS/DynamoDB, per the free-tier numbers already
  discussed), or Render/Railway, which are simpler to stand up for a
  project this size.
- No migration framework — `schema.sql` is applied idempotently via
  `npm run migrate`. Fine now; swap in something like
  `node-pg-migrate` once the schema needs to change without being
  re-run wholesale.
- No rate limiting / brute-force protection on `/auth/login`.

## Running it locally

```bash
npm install
cp .env.example .env        # then fill in JWT_SECRET etc.

# Postgres: either...
docker compose up -d        # if you have Docker Desktop, or:
brew install postgresql@16 && brew services start postgresql@16 \
  && createdb focusup

npm run migrate              # applies src/db/schema.sql
npm run dev                  # http://localhost:3000
```

Health check: `curl http://localhost:3000/health`

## Running the tests

```bash
npm test
```

Needs the same `DATABASE_URL` as above (tests run against a real
Postgres, truncating tables between tests — see
`src/__tests__/setup.ts`). CI provisions its own throwaway Postgres
via a GitHub Actions service container, so nothing local is required
for CI to pass.
