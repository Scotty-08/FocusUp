// Signs the extension into the same Supabase project the FocusUp app
// uses (see BackendClient.swift for the app's side of this), storing
// the access/refresh token pair in this extension's own local storage
// -- separate from the app, since they run on different devices.
//
// Only background.js touches this module. popup.js never handles a
// raw token; it just asks background.js "am I signed in" / "sign in
// with this email+password" and gets back a plain yes/no, so there's
// one place tokens actually live.
import { SUPABASE_URL, SUPABASE_ANON_KEY } from "./config.js";

const SESSION_KEY = "focusUp.session";

async function readSession() {
    const stored = await chrome.storage.local.get(SESSION_KEY);
    return stored[SESSION_KEY] ?? null;
}

async function writeSession(session) {
    await chrome.storage.local.set({ [SESSION_KEY]: session });
}

async function clearSession() {
    await chrome.storage.local.remove(SESSION_KEY);
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
