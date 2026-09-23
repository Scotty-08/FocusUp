// Owns the whole desktop sync: fetch a Canvas origin's upcoming
// assignments (riding on the cookie already sitting in the browser for
// that site), push them to the same Supabase table the FocusUp app
// reads from, remember when it last ran. See canvas_pending_assignments
// in supabase/schema.sql for the table + Row Level Security this
// depends on, and CanvasClient.fetchPendingCanvasAssignments in the app
// for the pull side.
//
// This is the desktop counterpart to FocusUpCanvasExtension (the
// Safari extension bundled in the iOS app) -- same idea, same
// permission-driven auto-sync design, just delivering over the network
// instead of an on-device App Group, since a laptop and a phone are two
// different devices. See that extension's background.js for the
// permissions.onAdded reasoning this mirrors.
import { SUPABASE_URL, SUPABASE_ANON_KEY } from "./config.js";
import { signIn, signOut, currentSession, validAccessToken } from "./auth.js";

const DEDUPE_MS = 5 * 1000; // guards against a page firing content.js twice
// in the same instant (e.g. multiple frames) -- NOT a cooldown on real
// syncs. Every actual Canvas page load should sync for real, which is
// the whole point of "auto"; the periodic alarm below already only fires
// every 10 minutes on its own, so nothing here needs to throttle beyond
// this short guard.

function scriptIdFor(origin) {
    return "focusup-canvas-autosync:" + origin;
}

async function fetchCanvasAssignments(origin) {
    try {
        const meRes = await fetch(origin + "/api/v1/users/self", { credentials: "include" });
        if (!meRes.ok) {
            return { ok: false, error: "not-canvas" };
        }

        const coursesRes = await fetch(
            origin + "/api/v1/courses?enrollment_state=active&per_page=50",
            { credentials: "include" }
        );
        if (!coursesRes.ok) {
            return { ok: false, error: "courses-failed" };
        }
        const courses = await coursesRes.json();

        const assignments = [];
        for (const course of courses) {
            const aRes = await fetch(
                origin + `/api/v1/courses/${course.id}/assignments?bucket=upcoming&order_by=due_at&per_page=50`,
                { credentials: "include" }
            );
            if (!aRes.ok) continue;
            const list = await aRes.json();
            for (const a of list) {
                assignments.push({ id: a.id, name: a.name, due_at: a.due_at, html_url: a.html_url });
            }
        }
        return { ok: true, assignments };
    } catch (error) {
        return { ok: false, error: String(error) };
    }
}

async function pushAssignments(userId, assignments) {
    if (assignments.length === 0) {
        return { ok: true, count: 0 };
    }
    const token = await validAccessToken();
    if (!token) {
        return { ok: false, error: "not-signed-in" };
    }
    const rows = assignments.map((a) => ({
        user_id: userId,
        id: a.id,
        name: a.name,
        due_at: a.due_at,
        html_url: a.html_url,
    }));
    let res;
    try {
        res = await fetch(`${SUPABASE_URL}/rest/v1/canvas_pending_assignments?on_conflict=user_id,id`, {
            method: "POST",
            headers: {
                apikey: SUPABASE_ANON_KEY,
                Authorization: `Bearer ${token}`,
                "Content-Type": "application/json",
                Prefer: "resolution=merge-duplicates,return=minimal",
            },
            body: JSON.stringify(rows),
        });
    } catch (error) {
        return { ok: false, error: "Couldn't reach the FocusUp server." };
    }
    if (!res.ok) {
        return { ok: false, error: `Server rejected the sync (${res.status}).` };
    }
    return { ok: true, count: rows.length };
}

async function ensureRegistered(origin) {
    const id = scriptIdFor(origin);
    const existing = await chrome.scripting.getRegisteredContentScripts({ ids: [id] });
    if (existing.length === 0) {
        await chrome.scripting.registerContentScripts([
            {
                id,
                matches: [origin + "/*"],
                js: ["content.js"],
                runAt: "document_idle",
            },
        ]);
    }
}

async function syncOrigin(origin, { force = false } = {}) {
    console.log("[FocusUp] syncOrigin", origin, force ? "(forced)" : "");
    const session = await currentSession();
    if (!session) {
        console.log("[FocusUp] not signed in -- skipping");
        return { ok: false, error: "not-signed-in" };
    }

    const key = "focusUp.lastAutoSync." + origin;
    if (!force) {
        const stored = await chrome.storage.local.get(key);
        const last = stored[key] ?? 0;
        if (Date.now() - last < DEDUPE_MS) {
            console.log("[FocusUp] deduped -- synced", Date.now() - last, "ms ago");
            return { ok: true, skipped: true };
        }
    }
    console.log("[FocusUp] fetching assignments from", origin);
    const result = await fetchCanvasAssignments(origin);
    if (!result.ok) {
        console.log("[FocusUp] fetch failed:", result.error);
        return result;
    }
    console.log("[FocusUp] fetched", result.assignments.length, "assignments -- pushing to server");
    const response = await pushAssignments(session.userId, result.assignments);
    await chrome.storage.local.set({ [key]: Date.now() });
    console.log("[FocusUp] push result:", response);
    return { ok: response.ok, count: result.assignments.length, error: response.error };
}

// Fires when host access to a site is granted through ANY path -- our
// own popup button, or the browser's own per-extension site-access
// controls. Chrome may not always keep this service worker alive to
// catch it, which is why popup.js also self-heals on open -- this
// listener is the fast path, that's the safety net.
if (chrome.permissions?.onAdded) {
    chrome.permissions.onAdded.addListener(async (permissions) => {
        for (const originPattern of permissions.origins ?? []) {
            const origin = originPattern.replace(/\/\*$/, "");
            await ensureRegistered(origin);
            await syncOrigin(origin, { force: true });
        }
    });
}

// Real auto-sync, independent of the user doing anything: content.js
// only fires on an actual page load of a matched Canvas site, so
// sitting on an already-open tab (or the service worker having gone to
// sleep between visits) meant nothing happened until you reopened the
// popup yourself, which isn't "auto" at all. chrome.alarms wakes the
// service worker on a timer even when nothing else would -- this is
// what makes it real background sync instead of "only when the popup
// happens to run."
const PERIODIC_SYNC_ALARM = "focusup-canvas-periodic-sync";

chrome.alarms.create(PERIODIC_SYNC_ALARM, { periodInMinutes: 10 });

chrome.alarms.onAlarm.addListener(async (alarm) => {
    if (alarm.name !== PERIODIC_SYNC_ALARM) return;
    const session = await currentSession();
    if (!session) return;
    // Every site the user has actually enabled auto-sync for has a
    // registered content script -- that list IS the "which Canvas
    // sites am I watching" list, so there's nothing separate to store.
    const scripts = await chrome.scripting.getRegisteredContentScripts();
    for (const script of scripts) {
        if (!script.id.startsWith("focusup-canvas-autosync:")) continue;
        const origin = script.id.slice("focusup-canvas-autosync:".length);
        await syncOrigin(origin, { force: false }); // still respects the 10-minute throttle
    }
});

chrome.runtime.onMessage.addListener((request, _sender, sendResponse) => {
    (async () => {
        switch (request?.type) {
            case "syncOrigin":
                sendResponse(await syncOrigin(request.origin, { force: request.force ?? false }));
                break;
            case "enableAutoSync":
                await ensureRegistered(request.origin);
                sendResponse(await syncOrigin(request.origin, { force: true }));
                break;
            case "getSession":
                sendResponse(await currentSession());
                break;
            case "signIn":
                sendResponse(await signIn(request.email, request.password));
                break;
            case "signOut":
                await signOut();
                sendResponse({ ok: true });
                break;
            default:
                sendResponse(undefined);
        }
    })();
    return true; // keep the message channel open for the async sendResponse above
});
