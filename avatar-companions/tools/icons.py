"""Shop icons + companion portraits for the app, as an asset-catalog folder.

Output: build_icons/Companions/<name>.imageset/{<name>.png, Contents.json}
  portrait_<speciesId>_<cloak>     head-and-shoulders portrait in that cloak
  portrait_human_<male|female>_<skinIndex>_<cloak>
  shop_eyes_<key>, shop_cloak_<key>, shop_boots_<key>, shop_augment_<key>
"""
import json
import math
import os
import shutil
from playwright.sync_api import sync_playwright
from PIL import Image
import rivegen
from rivegen import Node, Shape, Ellipse, Path, Fill, Stroke, to_svg
import kit
import companions

OUT = "build_icons/Companions"
SPECIES_IDS = {  # artboard -> app species id (CompanionCatalog in Swift)
    "HumanMale": "human.male", "HumanFemale": "human.female", "Capybara": "capybara", "Fox": "fox",
    "Axolotl": "axolotl", "Owl": "owl", "Cat": "cat", "Bunny": "bunny", "Frog": "frog", "RedPanda": "redpanda",
    "Penguin": "penguin", "Raccoon": "raccoon", "Wolf": "wolf", "BearCub": "bearcub", "Otter": "otter",
    "Panda": "panda", "Hedgehog": "hedgehog", "Deer": "deer", "Tiger": "tiger", "Koala": "koala",
    "Duck": "duck", "Mouse": "mouse", "BabyDragon": "babydragon",
}


def svg_of(nodes, cx, cy, scale, size=180):
    """Place `nodes` (authored around cx,cy) centered in a size x size canvas."""
    wrap = Node("Icon", nodes, x=size / 2 - cx * scale, y=size / 2 - cy * scale, sx=scale, sy=scale)
    return to_svg([wrap], size, size, bg="none")


def jobs():
    kit.reset_selection()
    out = []
    # portraits: one per cloak (and per skin tone for the humans), so the
    # picker and friends list show each companion in the cloak you wear
    for sp in companions.roster():
        sid = SPECIES_IDS[sp.ARTBOARD]
        for cloak in kit.CLOAKS:
            kit.SEL["cloak"] = cloak
            if sid.startswith("human"):
                for i, skin in enumerate(kit.SKINS):
                    kit.SEL["skin"] = skin
                    _, svg = companions.build_artboard(sp, 0)
                    out.append((f"portrait_{sid.replace('.', '_')}_{i}_{cloak.lower()}", svg, "portrait"))
                kit.SEL["skin"] = "Medium"
            else:
                _, svg = companions.build_artboard(sp, 0)
                out.append((f"portrait_{sid}_{cloak.lower()}", svg, "portrait"))
    kit.SEL["cloak"] = "Forest"
    rivegen.set_scope("icons")
    for key, c in kit.EYES.items():
        eyes = [Node("L", kit.eye(c, 2.8), x=-30), Node("R", kit.eye(c, 2.8), x=30)]
        out.append((f"shop_eyes_{key.lower()}", svg_of(eyes, 0, 0, 1.0), "icon"))
    for key, c in kit.CLOAKS.items():
        parts = [kit.cloak_front(key, c), kit.hood_shell(key, c), kit.hood_lining(key, c), kit.cloak_back(key, c)]
        out.append((f"shop_cloak_{key.lower()}", svg_of(parts, -10, -218, 0.5), "icon"))
    for key, c in kit.BOOTS.items():
        out.append((f"shop_boots_{key.lower()}", svg_of([kit.boots_variant(key, c)], 6, -34, 1.05), "icon"))
    aug = {
        "none": [Shape("None", 0, 0, Ellipse(70, 70), [Stroke("66FFFFFF", 4)]),
                 Shape("Slash", 0, 0, Path([(-24, 24), (24, -24)], closed=False), [Stroke("66FFFFFF", 4)])],
        "leaf": [kit.leaf("Leaf", 0, 0, 0.6, 3.2)],
        "crystal": [Node("C", [Shape("Crystal", 0, 0, Path(kit.CRYSTAL), [Fill(rivegen.LinGrad(0, -34, 0, 34, [(0, "FFD9FBFF"), (0.5, "FF5FDDF5"), (1, "FF2A8FC8")]))]),
                               Shape("Glow", 0, 0, Ellipse(40, 60), [Stroke("AA3FD0F0", 12, feather=14)])], sx=1.9, sy=1.9)],
        "flame": [Node("F", [Shape("Core", 0, 8, Path([(0, -20, 0, 0, 2, 8), (9, 2, 0, -8, 0, 8), (0, 14, 7, 0, -7, 0), (-9, 2, 0, 8, 0, -8)]), [Fill("FFFFF1A8")]),
                             Shape("Flame", 0, 0, Path(kit.FLAME), [Fill(rivegen.LinGrad(0, -46, 0, 26, [(0, "FFFFD04A"), (0.6, "FFFF7A1E"), (1, "FFE0401A")]))]),
                             Shape("Glow", 0, -6, Ellipse(44, 66), [Stroke("AAFF6A1A", 12, feather=16)])], y=8, sx=1.7, sy=1.7)],
        "star": [kit.four_star("Star", 46, 12, "FFFFD76A", glow="AAFFC94D"),
                 Shape("Ring", 0, 0, Ellipse(150, 40), [Stroke("99FFE08A", 3)], rot=-0.35)],
    }
    for key, parts in aug.items():
        out.append((f"shop_augment_{key}", svg_of(parts, 0, 0, 1.0), "icon"))
    return out


def main():
    if os.path.exists("build_icons"):
        shutil.rmtree("build_icons")
    os.makedirs(OUT)
    json.dump({"info": {"author": "xcode", "version": 1}}, open(f"{OUT}/Contents.json", "w"))
    todo = jobs()
    with sync_playwright() as p:
        b = p.chromium.launch()
        for name, svg, kind in todo:
            d = f"{OUT}/{name}.imageset"
            os.makedirs(d)
            png = f"{d}/{name}.png"
            if kind == "portrait":
                pg = b.new_page(viewport={"width": 400, "height": 460}, device_scale_factor=1.5)
                clear = svg.replace('fill="#0E1A33"', 'fill="none"')
                pg.set_content(f"<html><body style='margin:0;background:transparent'>{clear}</body></html>")
                pg.screenshot(path=png, omit_background=True, clip={"x": 60, "y": 0, "width": 280, "height": 280})
                pg.close()
                Image.open(png).resize((180, 180), Image.LANCZOS).save(png)
            else:
                pg = b.new_page(viewport={"width": 180, "height": 180})
                pg.set_content(f"<html><body style='margin:0;background:transparent'>{svg}</body></html>")
                pg.screenshot(path=png, omit_background=True)
                pg.close()
            json.dump({"images": [{"filename": f"{name}.png", "idiom": "universal", "scale": "3x"}],
                       "info": {"author": "xcode", "version": 1}}, open(f"{d}/Contents.json", "w"), indent=2)
        b.close()
    print(len(todo), "images")


if __name__ == "__main__":
    main()
