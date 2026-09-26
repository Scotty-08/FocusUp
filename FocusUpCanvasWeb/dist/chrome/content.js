// Only ever runs on an origin the user explicitly granted -- registered
// dynamically by background.js, never declared as a static content
// script in manifest.json, so it never touches any other site.
//
// Deliberately thin: the actual Canvas fetch + Supabase push lives in
// background.js. This just pings it every time the page loads;
// background.js applies its own short dedupe guard (not a cooldown), so
// every real page load results in a real sync.
const ext = globalThis.browser ?? globalThis.chrome; // content scripts can't import modules
console.log("[FocusUp] content script running on", location.origin);
(async () => {
    try {
        const response = await ext.runtime.sendMessage({ type: "syncOrigin", origin: location.origin });
        console.log("[FocusUp] sync response:", response);
    } catch (error) {
        console.log("[FocusUp] auto-sync skipped:", error);
    }
})();
