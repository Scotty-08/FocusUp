"""Export the approved Shutter (B) logo to every size the project uses."""
import os
import re
from playwright.sync_api import sync_playwright
from PIL import Image
import logos

OUT = "export"
os.makedirs(OUT, exist_ok=True)
logos.write("B")
icon_svg = open("icon_B.svg").read()
# tight crop: the frame + blades span ~196..828, so the mark fills its box edge to edge
mark_svg = open("mark_B.svg").read().replace('viewBox="0 0 1024 1024"', 'viewBox="184 184 656 656"')
# rounded-tile version for browser extension icons (transparent corners)
tile_svg = (icon_svg.replace('<rect width="1024" height="1024" fill="url(#bg)"/>',
                             '<rect x="150" y="150" width="724" height="724" rx="160" fill="url(#bg)"/>')
            .replace('viewBox="0 0 1024 1024"', 'viewBox="150 150 724 724"'))


def render(svg, size, path, transparent=True):
    svg = re.sub(r'width="1024" height="1024"', f'width="{size}" height="{size}"', svg, count=1)
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page(viewport={"width": size, "height": size})
        pg.set_content(f"<html><body style='margin:0;background:transparent'>{svg}</body></html>")
        pg.screenshot(path=path, omit_background=transparent, clip={"x": 0, "y": 0, "width": size, "height": size})
        b.close()


render(icon_svg, 1024, f"{OUT}/AppIcon.png", transparent=False)
Image.open(f"{OUT}/AppIcon.png").convert("RGB").save(f"{OUT}/AppIcon.png")   # iOS icons must be opaque
render(mark_svg, 320, f"{OUT}/ShieldMark@2x.png")   # 160pt
render(mark_svg, 480, f"{OUT}/ShieldMark@3x.png")
for s in (16, 32, 48, 64, 96, 128, 256, 512):
    render(tile_svg, s, f"{OUT}/icon-{s}.png")

# Safari toolbar icon: single-colour template (Safari tints it), same silhouette.
blades = "".join(f'<path d="{logos.blade_path(90 * k)}"/>' for k in range(4))
toolbar = ('<?xml version="1.0" encoding="UTF-8"?>\n'
           '<svg version="1.1" xmlns="http://www.w3.org/2000/svg" viewBox="170 170 684 684">\n'
           f'  <g fill="#000">{blades}</g>\n'
           '  <circle cx="512" cy="512" r="118" fill="none" stroke="#000" stroke-width="44"/>\n'
           '  <circle cx="550" cy="472" r="30" fill="#000"/>\n'
           '</svg>\n')
open(f"{OUT}/toolbar-icon.svg", "w").write(toolbar)
render(toolbar.split("\n", 1)[1].replace('viewBox="170 170 684 684"', 'width="1024" height="1024" viewBox="170 170 684 684"'),
       128, f"{OUT}/_toolbar_preview.png")
print(sorted(os.listdir(OUT)))
