const statusEl = document.getElementById("status");
const actionButton = document.getElementById("actionButton");
const offButton = document.getElementById("offButton");

function scriptIdFor(origin) {
    return "focusup-canvas-autosync:" + origin;
}

function showError(message) {
    statusEl.textContent = message;
    statusEl.className = "error";
}

let currentTab = null;
let currentOrigin = null;
let currentOriginPattern = null;
let isEnabled = false;

// Runs every time the popup opens. It doesn't just read state -- it
// also FIXES it: if this origin already has host access (because the
// user granted it through Safari's own "Always Allow on This Website"
// extension menu instead of our button below), that grant never runs
// our registration/sync code on its own, so this notices and finishes
// the job right here.
async function refreshUI() {
    const [tab] = await browser.tabs.query({ active: true, currentWindow: true });
    currentTab = tab;

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

    const hasPermission = await browser.permissions.contains({ origins: [currentOriginPattern] });

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

    const response = await browser.runtime.sendMessage({ type: "enableAutoSync", origin: currentOrigin });

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

    // browser.permissions.request has to be the very first thing that
    // happens after the click -- nothing awaited ahead of it. Safari
    // only honors the request while it's still inside the tap that
    // triggered it; the old code awaited an executeScript round-trip
    // into the tab first to "check this looks like Canvas," and that
    // delay was very likely why the prompt just sat there and never
    // resolved.
    const granted = await browser.permissions.request({ origins: [currentOriginPattern] });
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

    const response = await browser.runtime.sendMessage({ type: "syncOrigin", origin: currentOrigin, force: true });

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
    await browser.scripting.unregisterContentScripts({ ids: [scriptIdFor(currentOrigin)] }).catch(() => {});
    await browser.permissions.remove({ origins: [currentOriginPattern] });
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

refreshUI();
