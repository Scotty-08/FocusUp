# FocusUp backend (Supabase)

Accounts, player cards, friends, cheers and the friends leaderboard live
in a Supabase project (managed Postgres + auth). The iOS app talks to it
directly over HTTPS -- see `FocusUpSpike/FocusUpSpike/BackendClient.swift`
(no SDK, nothing to add in Xcode). The app is local-first: quests and
app blocking never depend on the server.

`FocusUpBackend/` (Node + Express + Postgres) is the earlier, unused
attempt; Supabase replaces it.

## One-time setup

1. **Create a project** at supabase.com (free tier is fine).
2. **Run the schema:** Dashboard -> SQL Editor -> New query -> paste all of
   `supabase/schema.sql` -> Run. Safe to re-run.
3. **Sign in with Apple:** Authentication -> Providers -> Apple -> enable,
   and put the app's bundle id `com.scottgray.FocusUpSpike` in
   *Authorized Client IDs*. (Native sign-in needs no Apple key/secret.)
4. **Email/password:** Authentication -> Providers -> Email is on by
   default. For the demo, turn **off** "Confirm email" so new accounts can
   sign in immediately (otherwise the app shows "Check your email...").
5. **Point the app at it:** Project Settings -> API. In
   `FocusUpSpike/FocusUpSpike/`, copy `BackendSecrets.swift.example` to
   `BackendSecrets.swift` and paste in the *Project URL* and the *anon
   public* key. That file is gitignored, so **every developer (and every
   fresh clone) has to create their own copy or the app won't build.**
   The anon key is public by design -- Row Level Security protects the
   data. **Never** put the `service_role` key in the app or the repo.

## What the app uses

| Thing | How |
|---|---|
| Player card (handle, avatar, level, EXP, streak, quests cleared) | `profiles` table, own row only for writes |
| Add friend by `@username`, accept, decline, unfriend | `send_friend_request`, `accept_friend_request`, `remove_friendship` |
| Friends + pending requests | `list_friends()` |
| Cheers (friend nudges) | `send_cheer`, `my_cheers`, `mark_cheers_seen` (1/min per friend) |
| Leaderboard | computed in the app from `list_friends()` + your own live stats |

Cheers are an **in-app inbox** (fetched when the app opens/refreshes), not
push notifications -- real push needs APNs setup and a sender service.

## Known limits (fine for the demo, worth knowing)

- Players write their own level/EXP, so leaderboard numbers aren't
  tamper-proof. A real fix means computing rewards server-side.
- Any signed-in user can look up any profile by username (handle, avatar,
  level, streak only -- no email, birthday or app data).
- No account deletion yet (App Store review will want one before release).
- Untested against a live project: the SQL and the client were written
  without a database or Xcode. Expect a first-run debugging pass.
