import sys
from playwright.sync_api import sync_playwright
from PIL import Image
pairs = sys.argv[1:]
outs = []
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={"width": 400, "height": 460})
    for src in pairs:
        pg.set_content(f"<html><body style='margin:0'>{open(src).read()}</body></html>")
        dst = src.replace(".svg", ".png"); pg.screenshot(path=dst); outs.append(dst)
    b.close()
ims = [Image.open(o) for o in outs]
cols = min(len(ims), 6); rows = (len(ims) + cols - 1) // cols
sheet = Image.new("RGB", (400 * cols, 460 * rows))
for i, im in enumerate(ims): sheet.paste(im, ((i % cols) * 400, (i // cols) * 460))
sheet.save("sheet.png"); print("sheet", sheet.size)
