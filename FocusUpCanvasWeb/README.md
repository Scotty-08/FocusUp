# FocusUp for Canvas -- desktop/browser extension

The laptop counterpart to the Safari extension bundled in the FocusUp
iOS app. Same idea (reads your upcoming Canvas assignments off the
browser session you're already signed into, read-only), but for any
computer instead of just your phone: it signs into your FocusUp
account and pushes assignments to the server, and the app picks them
up from there next time it's opened -- no cable, no same-device
requirement.

Works in Chrome, Edge and Brave (anything Chromium-based) and in
Firefox 140+. The code is shared; only `manifest.json` differs, and
`python3 build.py` writes a ready-to-load copy for each browser into
`dist/`.

## Installing it

### Chrome / Edge / Brave (unpacked, for now)

1. Open `chrome://extensions` (or the equivalent in Edge/Brave).
2. Turn on "Developer mode" (top-right toggle).
3. Click "Load unpacked" and select `dist/chrome` (the top-level
   `FocusUpCanvasWeb` folder works too -- it has the Chrome manifest).
4. Pin the extension to the toolbar if you want it visible (puzzle-piece
   icon -> pin).

The Chrome manifest carries a fixed `key`, so the extension id is always
`nkoidnlhkikljdedbcmjahoddmiafopo` on every computer. That keeps its
Apple sign-in return address stable:
`https://nkoidnlhkikljdedbcmjahoddmiafopo.chromiumapp.org/`.

### Firefox

For testing: open `about:debugging#/runtime/this-firefox`, click "Load
Temporary Add-on...", and pick `dist/firefox/manifest.json`. Firefox
removes temporary add-ons when it quits.

For a permanent install, upload `dist/FocusUp-Canvas-Firefox.xpi` to
addons.mozilla.org (Developer Hub -> Submit a New Add-on). "On your own"
distribution gets it signed without a public listing; Firefox then
installs the signed .xpi normally.

## Using it

1. Click the FocusUp icon and sign in -- "Sign in with Apple", or your
   FocusUp email/password (the same account the app uses). New accounts
   are created in the app on your phone.
2. Open your school's Canvas dashboard in a normal tab.
3. Click the FocusUp icon again, click "Enable Auto-Sync," and allow
   access when the browser asks. One-time per school/site.
4. From then on, every time you visit that Canvas site in this browser,
   new assignments import automatically -- open FocusUp on your phone
   to see them land in the Quest Log.

## Sign in with Apple (one-time setup, done by the developer)

The browser can't use the phone's native Apple sign-in, so the
extension opens Apple's web sign-in through Supabase
(`identity.launchWebAuthFlow`). That needs, once:

- Apple Developer: a Services ID with Sign in with Apple enabled,
  domain `lpruhipiailgdjzgjdsc.supabase.co`, return URL
  `https://lpruhipiailgdjzgjdsc.supabase.co/auth/v1/callback`, plus a
  Sign in with Apple key (.p8).
- Supabase -> Authentication -> Sign In / Providers -> Apple: Client IDs
  = `<Services ID>,com.scottgray.FocusUpSpike`, and the secret key made
  with Supabase's generator from the .p8. **That secret expires every 6
  months** -- regenerate and paste it again before then.
- Supabase -> Authentication -> URL Configuration -> Redirect URLs: each
  browser's return address. Chrome's is above; Firefox's is shown in the
  popup's error text the first time you try (it looks like
  `https://<hash>.extensions.allizom.org/`).
- The Apple button is always shown (`APPLE_WEB_SIGNIN_ENABLED` in
  `config.js`); until the setup above is done it just shows an error.

## How it fits together

- `background.js` does the actual work: reads assignments from Canvas's
  own API (riding on the cookie already in your browser for that site),
  and pushes them to the `canvas_pending_assignments` table in
  Supabase (see `/supabase/schema.sql` at the repo root).
- `content.js` is just a trigger -- registered to run on a Canvas site
  only after you grant it access, it pings `background.js` on every
  page load so assignments stay current without you doing anything.
- `ext.js` picks `browser` (Firefox) or `chrome` so the rest of the code
  is identical in both.
- `auth.js` signs into the same Supabase project the app uses (email or
  Apple)
  (`config.js` has the project URL + public anon key -- same values as
  `BackendSecrets.swift`, safe to be public since Row Level Security on
  the server is what actually protects the data).
- The app pulls its own rows down via
  `BackendClient.fetchPendingCanvasAssignments()` and deletes them once
  merged into the Quest Log, so nothing is ever delivered twice.

Nothing about a specific school is hardcoded anywhere -- it works for
whatever Canvas domain you have open, same as the Safari extension and
the original PAT-based sync.

## Publishing (Chrome Web Store / Edge Add-ons)

Upload `dist/FocusUp-Canvas-Store.zip` (built by `build.py`). It's the
Chrome build without the `key` line; each store assigns its own
permanent extension id. After the first upload, add each store's
`https://<store-id>.chromiumapp.org/` to Supabase -> Authentication ->
URL Configuration -> Redirect URLs, or Apple sign-in won't finish for
store installs. Raise `version` in both manifests for every update.
The listing text, images and privacy policy live in the store kit
(`FocusUp-Store-Kit`).
