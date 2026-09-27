// Signs the extension into the same Supabase project the FocusUp app
// uses (see BackendClient.swift for the app's side of this), storing
// the access/refresh token pair in this extension's own local storage
// -- separate from the app, since they run on different devices.
//
// Only background.js touches this module. popup.js never handles a
// raw token; it just asks background.js "am I signed in" / "sign in
// with this email+password" and gets back a plain yes/no, so there's
// one place tokens actually live.
import { ext } from "./ext.js";
import { SUPABASE_URL, SUPABASE_ANON_KEY } from "./config.js";

const SESSION_KEY = "focusUp.session";

async function readSession() {
    const stored = await ext.storage.local.get(SESSION_KEY);
    return stored[SESSION_KEY] ?? null;
}

async function writeSession(session) {
    await ext.storage.local.set({ [SESSION_KEY]: session });
}

async function clearSession() {
    await ext.storage.local.remove(SESSION_KEY);
}

function adoptSession(json) {
    if (!json?.access_token || !json?.refresh_token || !json?.user?.id) {
        return null;
    }
    return {
        accessToken: json.access_token,
        refreshToken: json.refresh_token,
        userId: json.user.id,
        email: json.user.email ?? null,
        expiresAt: Date.now() + (json.expires_in ?? 3600) * 1000,
    };
}

async function authRequest(grantType, body) {
    let res;
    try {
        res = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=${grantType}`, {
            method: "POST",
            headers: { apikey: SUPABASE_ANON_KEY, "Content-Type": "application/json" },
            body: JSON.stringify(body),
        });
    } catch (error) {
        return { ok: false, error: "Couldn't reach the FocusUp server. Check your connection." };
    }
    const json = await res.json().catch(() => ({}));
    if (!res.ok) {
        return { ok: false, error: json?.error_description || json?.msg || `Sign-in failed (${res.status}).` };
    }
    const session = adoptSession(json);
    if (!session) {
        return { ok: false, error: "Check your email for a confirmation link, then try again." };
    }
    await writeSession(session);
    return { ok: true, session };
}

export async function signIn(email, password) {
    return authRequest("password", { email, password });
}

// Sign in with Apple, through Supabase's hosted OAuth flow:
//   1. open Supabase's /authorize?provider=apple in the browser's own
//      auth window (identity.launchWebAuthFlow),
//   2. the user signs in on Apple's page (their own Apple ID -- the same
//      account they use in the FocusUp app),
//   3. Supabase redirects back to this extension's private redirect URL
//      with the session tokens in the URL fragment.
// Runs in background.js, not the popup: the popup closes the moment the
// Apple window takes focus, which would drop the result.
//
// The redirect URL (identity.getRedirectURL()) must be listed under
// Supabase -> Authentication -> URL Configuration -> Redirect URLs, or
// Supabase sends the user to the Site URL instead and this never
// completes. It's shown in the error text so it's easy to copy.
export function appleRedirectURL() {
    return ext.identity.getRedirectURL();
}

// Browsers without identity.launchWebAuthFlow (Safari) use a normal tab
// instead: Supabase sends it back to this extension's own
// auth-callback.html (declared web-accessible in the Safari manifest),
// which hands the URL to finishAppleSignIn via background.js. Safari's
// extension address is random per install, so Supabase's Redirect URLs
// needs the pattern safari-web-extension://** for this to be allowed.
export function supportsAuthWindow() {
    return typeof ext.identity?.launchWebAuthFlow === "function";
}

function authorizeURL(redirectTo) {
    return `${SUPABASE_URL}/auth/v1/authorize?provider=apple&redirect_to=${encodeURIComponent(redirectTo)}`;
}

export async function signInWithApple() {
    if (!supportsAuthWindow()) {
        await ext.tabs.create({ url: authorizeURL(ext.runtime.getURL("auth-callback.html")) });
        return { ok: false, pending: true };
    }
    const redirectTo = appleRedirectURL();
    let responseURL;
    try {
        responseURL = await ext.identity.launchWebAuthFlow({ url: authorizeURL(redirectTo), interactive: true });
    } catch (error) {
        const message = String(error?.message ?? error);
        if (/cancel|closed|did not approve/i.test(message)) {
            return { ok: false, error: "Apple sign-in was cancelled." };
        }
        return { ok: false, error: `Apple sign-in didn't finish. If this keeps happening, add ${redirectTo} to FocusUp's allowed redirect URLs.` };
    }
    return finishAppleSignIn(responseURL);
}

// Turns the URL Supabase redirected to (tokens in its #fragment) into a
// stored session.
export async function finishAppleSignIn(responseURL) {
    const fragment = new URL(responseURL).hash.replace(/^#/, "");
    const params = new URLSearchParams(fragment || new URL(responseURL).search);
    if (params.get("error")) {
        return { ok: false, error: params.get("error_description") || params.get("error") };
    }
    const accessToken = params.get("access_token");
    const refreshToken = params.get("refresh_token");
    if (!accessToken || !refreshToken) {
        return { ok: false, error: "Apple sign-in didn't return a session. Try again." };
    }
    // The fragment has the tokens but not who they belong to -- ask.
    let user;
    try {
        const res = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
            headers: { apikey: SUPABASE_ANON_KEY, Authorization: `Bearer ${accessToken}` },
        });
        user = await res.json();
        if (!res.ok) throw new Error(String(res.status));
    } catch {
        return { ok: false, error: "Couldn't reach the FocusUp server. Check your connection." };
    }
    const session = adoptSession({
        access_token: accessToken,
        refresh_token: refreshToken,
        expires_in: Number(params.get("expires_in") ?? 3600),
        user,
    });
    if (!session) {
        return { ok: false, error: "Apple sign-in didn't return a session. Try again." };
    }
    await writeSession(session);
    return { ok: true, session };
}

export async function signOut() {
    await clearSession();
}

export async function currentSession() {
    return readSession();
}

// Returns a still-valid access token, refreshing first if it's about
// to expire. Only a definitive rejection of the refresh token clears
// the stored session -- a network blip here shouldn't kick the user
// back to the sign-in form, same rule BackendClient.swift follows.
export async function validAccessToken() {
    const session = await readSession();
    if (!session) return null;
    if (session.expiresAt > Date.now() + 30_000) {
        return session.accessToken;
    }
    const result = await authRequest("refresh_token", { refresh_token: session.refreshToken });
    if (!result.ok) {
        await clearSession();
        return null;
    }
    return result.session.accessToken;
}
