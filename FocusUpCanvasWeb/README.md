# FocusUp for Canvas -- desktop/browser extension

The laptop counterpart to the Safari extension bundled in the FocusUp
iOS app. Same idea (reads your upcoming Canvas assignments off the
browser session you're already signed into, read-only), but for any
computer instead of just your phone: it signs into your FocusUp
account and pushes assignments to the server, and the app picks them
up from there next time it's opened -- no cable, no same-device
requirement.

Works in Chrome, Edge, and Brave (anything Chromium-based, same
extension, zero changes). Not packaged for Firefox.

## Installing it (unpacked, for now)

This isn't published to the Chrome Web Store, so it's loaded as an
"unpacked" extension:

1. Open `chrome://extensions` (or the equivalent in Edge/Brave).
2. Turn on "Developer mode" (top-right toggle).
3. Click "Load unpacked" and select this `FocusUpCanvasWeb` folder.
4. Pin the extension to the toolbar if you want it visible (puzzle-piece
   icon -> pin).

## Using it

1. Click the FocusUp icon, sign in with your FocusUp email/password
   (the same account the app uses).
2. Open your school's Canvas dashboard in a normal tab.
3. Click the FocusUp icon again, click "Enable Auto-Sync," and allow
   access when the browser asks. One-time per school/site.
4. From then on, every time you visit that Canvas site in this browser,
   new assignments import automatically -- open FocusUp on your phone
   to see them land in the Quest Log.

## How it fits together

- `background.js` does the actual work: reads assignments from Canvas's
  own API (riding on the cookie already in your browser for that site),
  and pushes them to the `canvas_pending_assignments` table in
  Supabase (see `/supabase/schema.sql` at the repo root).
- `content.js` is just a trigger -- registered to run on a Canvas site
  only after you grant it access, it pings `background.js` on every
  page load so assignments stay current without you doing anything.
- `auth.js` signs into the same Supabase project the app uses
  (`config.js` has the project URL + public anon key -- same values as
  `BackendSecrets.swift`, safe to be public since Row Level Security on
  the server is what actually protects the data).
- The app pulls its own rows down via
  `BackendClient.fetchPendingCanvasAssignments()` and deletes them once
  merged into the Quest Log, so nothing is ever delivered twice.

Nothing about a specific school is hardcoded anywhere -- it works for
whatever Canvas domain you have open, same as the Safari extension and
the original PAT-based sync.
