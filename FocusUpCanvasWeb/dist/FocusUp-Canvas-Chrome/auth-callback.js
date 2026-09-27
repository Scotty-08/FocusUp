// Landing page for Safari's tab-based Sign in with Apple (see
// signInWithApple in auth.js). Supabase redirects here with the session
// in the URL fragment; background.js stores it.
import { ext } from "./ext.js";

const title = document.getElementById("title");
const msg = document.getElementById("msg");
const url = location.href;
// Keep the tokens out of the tab's history.
history.replaceState(null, "", location.pathname);

(async () => {
    let result;
    try {
        result = await ext.runtime.sendMessage({ type: "completeAppleSignIn", url });
    } catch (error) {
        result = { ok: false, error: String(error?.message ?? error) };
    }
    if (result?.ok) {
        title.textContent = "You're signed in";
        msg.textContent = "Close this tab and open FocusUp for Canvas from the toolbar.";
        setTimeout(() => window.close(), 2500);
    } else {
        title.textContent = "Sign-in didn't finish";
        msg.textContent = result?.error || "Close this tab and try again.";
    }
})();
