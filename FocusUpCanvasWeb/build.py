"""Packages the extension for each browser.

The code is shared; only manifest.json differs (Chrome uses a service
worker background + a fixed "key" so its extension id -- and its Apple
sign-in redirect URL -- never changes; Firefox uses a background script,
a fixed add-on id, and declares what data it sends).

    python3 build.py

writes
    dist/chrome/                      load unpacked in chrome://extensions
    dist/FocusUp-Canvas-Chrome.zip    same as dist/chrome, zipped (for sharing / testing)
    dist/FocusUp-Canvas-Store.zip     upload this to the Chrome Web Store and Edge Add-ons
                                      (no "key": the stores assign the id)
    dist/firefox/                     load via about:debugging
    dist/FocusUp-Canvas-Firefox.xpi   for addons.mozilla.org / signing
"""
import json
import os
import shutil
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
SHARED = ["background.js", "auth.js", "config.js", "content.js", "ext.js", "popup.html", "popup.css", "popup.js", "icons"]
DIST = os.path.join(HERE, "dist")


def build(name, manifest_path, archive, drop_key=False):
    out = os.path.join(DIST, name)
    if os.path.exists(out):
        shutil.rmtree(out)
    os.makedirs(out)
    for item in SHARED:
        src = os.path.join(HERE, item)
        (shutil.copytree if os.path.isdir(src) else shutil.copy2)(src, os.path.join(out, item))
    if drop_key:
        # The stores assign their own permanent key/id; they don't accept
        # one in the upload. See README "Publishing".
        manifest = json.load(open(manifest_path))
        manifest.pop("key", None)
        with open(os.path.join(out, "manifest.json"), "w") as f:
            json.dump(manifest, f, indent=4)
    else:
        shutil.copy2(manifest_path, os.path.join(out, "manifest.json"))
    with zipfile.ZipFile(os.path.join(DIST, archive), "w", zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(out):
            for f in sorted(files):
                full = os.path.join(root, f)
                z.write(full, os.path.relpath(full, out))
    print("built", name)


if __name__ == "__main__":
    build("chrome", os.path.join(HERE, "manifest.json"), "FocusUp-Canvas-Chrome.zip")
    build("store", os.path.join(HERE, "manifest.json"), "FocusUp-Canvas-Store.zip", drop_key=True)
    build("firefox", os.path.join(HERE, "firefox", "manifest.json"), "FocusUp-Canvas-Firefox.xpi")
