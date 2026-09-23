// Only ever runs on an origin the user explicitly granted -- registered
// dynamically by background.js (never declared as a static content
// script in manifest.json), so it never touches any other site.
//
// Deliberately thin: the actual Canvas fetch + native-message hand-off
// lives in background.js now, so this just pings it every time the page
// loads. background.js applies its own throttle, so pinging on every
// load is cheap and safe.
(async () => {
    try {
        await browser.runtime.sendMessage({ type: "syncOrigin", origin: location.origin });
    } catch (error) {
        // Best-effort and silent -- this runs unattended on every page
        // load, so it should never interrupt the user's actual Canvas
        // page with an error of any kind.
        console.log("FocusUp auto-sync skipped:", error);
    }
})();
