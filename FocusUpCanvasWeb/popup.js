import { ext } from "./ext.js";
import { APPLE_WEB_SIGNIN_ENABLED } from "./config.js";
const authSection = document.getElementById("authSection");
const syncSection = document.getElementById("syncSection");
const emailInput = document.getElementById("email");
const passwordInput = document.getElementById("password");
const signInButton = document.getElementById("signInButton");
const authError = document.getElementById("authError");
const accountLine = document.getElementById("accountLine");
const statusEl = document.getElementById("status");
const actionButton = document.getElementById("actionButton");
const offButton = document.getElementById("offButton");
const signOutButton = document.getElementById("signOutButton");
const appleButton = document.getElementById("appleButton");
if (!APPLE_WEB_SIGNIN_ENABLED) {
    appleButton.hidden = true;
    document.querySelector(".divider")?.setAttribute("hidden", "");
}

function scriptIdFor(origin) {
    return "focusup-canvas-autosync:" + origin;
}

function showError(message) {
    statusEl.textContent = message;
    statusEl.className = "error";
}

let currentOrigin = null;
let currentOriginPattern = null;
let isEnabled = false;

// Runs every time the popup opens. Checks sign-in first, then -- same
// self-healing idea as the Safari extension's popup.js -- notices if
// this site already has host access (granted through Chrome's own
// per-site extension controls instead of our button) and finishes
// wiring it up right here rather than leaving it half-set-up.
async function refreshUI() {
    const session = await ext.runtime.sendMessage({ type: "getSession" });
    if (!session) {
        authSection.style.display = "block";
        syncSection.style.display = "none";
        // An Apple sign-in that failed while this popup was closed.
        const { "focusUp.lastAppleResult": last } = await ext.storage.local.get("focusUp.lastAppleResult");
        if (last && !last.ok && Date.now() - last.at < 2 * 60 * 1000) {
            authError.textContent = last.error;
        }
        return;
    }
    authSection.style.display = "none";
    syncSection.style.display = "block";
    accountLine.textContent = session.email ? `Signed in as ${session.email}` : "Signed in";

    const [tab] = await ext.tabs.query({ active: true, currentWindow: true });

    let origin;
    try {
        origin = new URL(tab.url).origin;
    } catch {
        showError("Open your Canvas dashboard first, then reopen this.");
        actionButton.style.display = "none";
        offButton.style.display = "none";
        return;
    }
    currentOrigin = origin;
    currentOriginPattern = origin + "/*";

    const hasPermission = await ext.permissions.contains({ origins: [currentOriginPattern] });
    if (!hasPermission) {
        isEnabled = false;
        statusEl.textContent = "Open your Canvas dashboard, then turn on auto-sync so new assignments import every time you visit.";
        statusEl.className = "";
        actionButton.textContent = "Enable Auto-Sync";
        actionButton.style.display = "block";
        offButton.style.display = "none";
        return;
    }

    statusEl.textContent = "Setting up auto-sync…";
    statusEl.className = "";
    actionButton.style.display = "none";
    offButton.style.display = "none";

    const response = await ext.runtime.sendMessage({ type: "enableAutoSync", origin: currentOrigin });
    isEnabled = true;
    if (response?.skipped) {
        statusEl.textContent = "Auto-sync is on for this site. New assignments import automatically every time you open Canvas here.";
        statusEl.className = "success";
    } else if (response?.ok) {
        const n = response.count ?? 0;
        statusEl.textContent = `Auto-sync is on. Imported ${n} assignment${n === 1 ? "" : "s"}. New ones will keep importing automatically.`;
        statusEl.className = "success";
    } else {
        statusEl.textContent = "Auto-sync is on for this site, but the last import didn't go through. It'll try again next time you're here.";
        statusEl.className = "";
    }
    actionButton.textContent = "Sync Now";
    actionButton.style.display = "block";
    offButton.style.display = "block";
}

async function enableAutoSync() {
    actionButton.disabled = true;
    statusEl.textContent = "Requesting access to this site…";
    statusEl.className = "";

    // Fires as the very first thing after the click, nothing awaited
    // ahead of it, so it stays inside the tap the browser expects for
    // a permission prompt.
    const granted = await ext.permissions.request({ origins: [currentOriginPattern] });
    if (!granted) {
        showError("FocusUp needs access to this site to auto-sync. You can try again anytime.");
        actionButton.disabled = false;
        return;
    }

    actionButton.disabled = false;
    await refreshUI();
}

async function syncNow() {
    actionButton.disabled = true;
    statusEl.textContent = "Reading your Canvas assignments…";
    statusEl.className = "";

    const response = await ext.runtime.sendMessage({ type: "syncOrigin", origin: currentOrigin, force: true });
    if (response?.ok) {
        const n = response.count ?? 0;
        statusEl.textContent = `Imported ${n} assignment${n === 1 ? "" : "s"}. Open FocusUp to see your Quest Log.`;
        statusEl.className = "success";
    } else {
        showError("Couldn't read Canvas's assignment list. Try again from your Canvas dashboard.");
    }
    actionButton.disabled = false;
}

async function turnOff() {
    await ext.scripting.unregisterContentScripts({ ids: [scriptIdFor(currentOrigin)] }).catch(() => {});
    await ext.permissions.remove({ origins: [currentOriginPattern] });
    isEnabled = false;
    await refreshUI();
}

actionButton.addEventListener("click", () => {
    if (isEnabled) {
        syncNow();
    } else {
        enableAutoSync();
    }
});

offButton.addEventListener("click", turnOff);

signInButton.addEventListener("click", async () => {
    signInButton.disabled = true;
    authError.textContent = "";
    const email = emailInput.value.trim();
    const password = passwordInput.value;
    if (!email || !password) {
        authError.textContent = "Enter your FocusUp email and password.";
        signInButton.disabled = false;
        return;
    }
    const result = await ext.runtime.sendMessage({ type: "signIn", email, password });
    signInButton.disabled = false;
    if (!result?.ok) {
        authError.textContent = result?.error || "Sign-in failed. Try again.";
        return;
    }
    passwordInput.value = "";
    await refreshUI();
});

appleButton.addEventListener("click", async () => {
    authError.textContent = "";
    appleButton.disabled = true;
    // Handled in background.js -- this popup usually closes as soon as
    // the Apple window opens; reopening it shows you signed in.
    const result = await ext.runtime.sendMessage({ type: "signInWithApple" });
    appleButton.disabled = false;
    if (result?.pending) {
        // Safari: sign-in continues in a new tab; reopen this afterwards.
        authError.textContent = "Finish signing in with Apple in the new tab, then open FocusUp again.";
        return;
    }
    if (!result?.ok) {
        authError.textContent = result?.error || "Apple sign-in didn't finish. Try again.";
        return;
    }
    await refreshUI();
});

signOutButton.addEventListener("click", async () => {
    await ext.runtime.sendMessage({ type: "signOut" });
    await refreshUI();
});

refreshUI();
