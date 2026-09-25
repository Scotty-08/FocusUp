import sys
from playwright.sync_api import sync_playwright

src, dst = sys.argv[1], sys.argv[2]
scale = float(sys.argv[3]) if len(sys.argv) > 3 else 1.5
svg = open(src).read()
with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page(device_scale_factor=scale, viewport={"width": 400, "height": 460})
    pg.set_content(f"<html><body style='margin:0'>{svg}</body></html>")
    pg.screenshot(path=dst, clip={"x": 0, "y": 0, "width": 400, "height": 460})
    b.close()
