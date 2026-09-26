// Background is the one place that actually knows how to reach Canvas
// AND the one place allowed to call browser.runtime.sendNativeMessage,
// so it owns the whole sync: fetch assignments for an origin, hand them
// to SafariWebExtensionHandler.swift, remember when it last ran.
//
// Centralizing this here (instead of popup.js/content.js each doing
// their own fetch) also fixes a real bug: a user can grant a site
// access two different ways -- tapping "Enable Auto-Sync" in our own
// popup, OR using Safari's own per-extension "Always Allow on This
// Website" control on the toolbar icon. Only the first way used to run
// any of our code. Listening for permissions.onAdded here means BOTH
// paths end up registering the content script and running a first sync
// -- nothing is left half-set-up just because the user granted access
// through Safari's own UI instead of ours.

const THROTTLE_MS = 10 * 60 * 1000; // at most once every 10 minutes per site

function scriptIdFor(origin) {
    return "focusup-canvas-autosync:" + origin;
}

// With include[]=submission each assignment carries YOUR submission;
// "upcoming" alone still lists things you've already turned in.
function isDone(assignment) {
    const sub = assignment.submission;
    if (!sub) return false;
    if (sub.excused) return true;
    if (sub.submitted_at) return true;
    return ["submitted", "graded", "pending_review"].includes(sub.workflow_state);
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
                origin + `/api/v1/courses/${course.id}/assignments?bucket=upcoming&order_by=due_at&per_page=50&include[]=submission`,
                { credentials: "include" }
            );
            if (!aRes.ok) continue;
            const list = await aRes.json();
            for (const a of list) {
                if (isDone(a)) continue; // already turned in, graded, or excused
                assignments.push({ id: a.id, name: a.name, due_at: a.due_at, html_url: a.html_url });
            }
        }
        return { ok: true, assignments };
    } catch (error) {
        return { ok: false, error: String(error) };
    }
}

async function sendToApp(assignments) {
    return browser.runtime
        .sendNativeMessage({ assignments })
        .then((nativeResponse) => nativeResponse ?? { ok: false, error: "no-response" })
        .catch((error) => ({ ok: false, error: String(error) }));
}

async function ensureRegistered(origin) {
    const id = scriptIdFor(origin);
    const existing = await browser.scripting.getRegisteredContentScripts({ ids: [id] });
    if (existing.length === 0) {
        await browser.scripting.registerContentScripts([
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
    const key = "focusUp.lastAutoSync." + origin;
    if (!force) {
        const stored = await browser.storage.local.get(key);
        const last = stored[key] ?? 0;
        if (Date.now() - last < THROTTLE_MS) {
            return { ok: true, skipped: true };
        }
    }
    const result = await fetchCanvasAssignments(origin);
    if (!result.ok) return result;
    const response = await sendToApp(result.assignments);
    await browser.storage.local.set({ [key]: Date.now() });
    return { ok: response?.ok ?? false, count: result.assignments.length, error: response?.error };
}

// Fires when host access to a site is granted through ANY path -- ours
// or Safari's own extension menu. Safari may not always keep this
// background page alive to catch it, which is why popup.js also
// self-heals on open (see refreshUI there) -- this listener is the fast
// path, that one is the safety net.
if (browser.permissions?.onAdded) {
    browser.permissions.onAdded.addListener(async (permissions) => {
        for (const originPattern of permissions.origins ?? []) {
            const origin = originPattern.replace(/\/\*$/, "");
            await ensureRegistered(origin);
            await syncOrigin(origin, { force: true });
        }
    });
}

browser.runtime.onMessage.addListener((request) => {
    if (request?.type === "syncOrigin") {
        return syncOrigin(request.origin, { force: request.force ?? false });
    }
    if (request?.type === "enableAutoSync") {
        return (async () => {
            await ensureRegistered(request.origin);
            return syncOrigin(request.origin, { force: true });
        })();
    }
});
