import base64
import sys
from playwright.sync_api import sync_playwright

NAMES = {"A": "Aperture", "B": "Shutter", "C": "Ascend"}


def uri(path):
    return "data:image/svg+xml;base64," + base64.b64encode(open(path, "rb").read()).decode()


def card(k):
    icon, mark = uri(f"icon_{k}.svg"), uri(f"mark_{k}.svg")
    return f"""
    <div class="card">
      <div class="label">{k} &middot; {NAMES[k]}</div>
      <img class="big" src="{icon}">
      <div class="row">
        <div class="cell"><img class="i80" src="{icon}"><span>home screen</span></div>
        <div class="cell"><img class="i40" src="{icon}"><span>settings</span></div>
        <div class="cell shield"><img class="m" src="{mark}"><span>blocker</span></div>
      </div>
    </div>"""


html = f"""<html><head><style>
body {{ margin:0; background:#0A0D12; font-family:-apple-system,Helvetica,Arial,sans-serif; color:#E8F6FB; }}
.wrap {{ display:flex; gap:28px; padding:34px; }}
.card {{ background:#111722; border:1px solid #1E2A3C; border-radius:22px; padding:24px; width:380px; }}
.label {{ font-size:22px; font-weight:700; letter-spacing:.5px; margin-bottom:18px; }}
.big {{ width:332px; height:332px; border-radius:74px; display:block; margin:0 auto 22px; box-shadow:0 10px 40px rgba(0,0,0,.5); }}
.row {{ display:flex; justify-content:space-between; align-items:flex-end; }}
.cell {{ display:flex; flex-direction:column; align-items:center; gap:8px; font-size:12px; color:#7F93A8; }}
.i80 {{ width:80px; height:80px; border-radius:18px; }}
.i40 {{ width:40px; height:40px; border-radius:9px; }}
.shield {{ background:#0E0F10; border-radius:14px; padding:10px 16px; }}
.m {{ width:66px; height:66px; }}
</style></head><body><div class="wrap">{''.join(card(k) for k in NAMES)}</div></body></html>"""

with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page(device_scale_factor=2, viewport={"width": 1320, "height": 640})
    pg.set_content(html)
    pg.wait_for_timeout(300)
    h = pg.evaluate("document.querySelector('.wrap').getBoundingClientRect().height")
    pg.screenshot(path=sys.argv[1] if len(sys.argv) > 1 else "sheet.png",
                  clip={"x": 0, "y": 0, "width": 1320, "height": h})
    b.close()
