"""Shared companion kit: everything every species wears or does the same way.

Every species artboard is assembled from:
  species-specific art  -- head, face, ears/extras, body colours, tail
  shared kit            -- hood/cloak (4 Solos), boots, arms, augments, eyes slot,
                           the state machine and all animations

so any cloak, pair of eyes, boots or augment a player owns fits every
companion, and the app drives every artboard through the same inputs:
  wave (trigger), calm (bool), eyes, cloak, boots, augment (numbers)
  skin, hair (numbers, human artboards only)

Coordinates: the Character node sits at the feet (FEET_X, FEET_Y); art is
authored in that local space with y up negative. First-declared child draws
on top.
"""
import math
from rivegen import (Shape, Node, Ellipse, Rect, Path, Fill, Stroke, LinGrad, RadGrad, Solid,
                     rid, fmt)

W, H = 400, 460
FEET_X, FEET_Y = 200, 424
NECK = (20, -228)

# ------------------------------------------------------------------ cosmetics (index = app input value)
CLOAKS = {
    "Forest":    dict(main="FF2F7A3F", shade="FF1C5028", hi="FF52A65A", lining="FF143A1D",
                      trim="FF6CBD6E", gem="FFC6E052", gemglow="FFB8E04A"),
    "Storm":     dict(main="FF1F3B70", shade="FF11234A", hi="FF3561A8", lining="FF0A1530",
                      trim="FF4FD6EE", gem="FF8BEBFA", gemglow="FF3FD0F0"),
    "Ember":     dict(main="FF2E2929", shade="FF191515", hi="FF4A4040", lining="FF0F0C0C",
                      trim="FFE8652A", gem="FFEF4B2B", gemglow="FFFF6A2A"),
    "Celestial": dict(main="FFEDE3CA", shade="FFC9BB98", hi="FFFFFBEF", lining="FF6A4BBE",
                      trim="FFDDB44A", gem="FFF2CF55", gemglow="FFFFD76A"),
    "Cyan":      dict(main="FF1B6573", shade="FF0E3D46", hi="FF2E93A4", lining="FF08272D",
                      trim="FF3EE6FF", gem="FF9FF4FF", gemglow="FF3EE6FF"),
    "Slate":     dict(main="FF3E4044", shade="FF26282B", hi="FF5B5E63", lining="FF151618",
                      trim="FF9AA6B2", gem="FFC4D0DB", gemglow="FF9FB0C0"),
}
EYES = {
    "Amber":  dict(iris="FFFFBE3D", core="FFFFE7A6", glow="CCFF9D1F"),
    "Cyan":   dict(iris="FF5CE6FF", core="FFD4F9FF", glow="CC23C4F0"),
    "Orange": dict(iris="FFFF8A2A", core="FFFFD2A1", glow="CCFF5A10"),
    "Violet": dict(iris="FFB98BFF", core="FFEBDDFF", glow="CC8A55F0"),
    "Green":  dict(iris="FF5CFF9D", core="FFD6FFE6", glow="CC2FE07A"),
    "Crimson": dict(iris="FFFF4D5E", core="FFFFD0D5", glow="CCFF2040"),
    "White":  dict(iris="FFF4F8FF", core="FFFFFFFF", glow="CCBFDFFF"),
}
BOOTS = {
    "Brown":  dict(main="FF6B4127", cuff="FF8E5D3C", sole="FF2E1C12", lace="FFD2AE80"),
    "Silver": dict(main="FF7F8894", cuff="FFC3CAD3", sole="FF32363D", lace="FFE9EEF3"),
    "Bronze": dict(main="FF93602F", cuff="FFC08B4A", sole="FF3A2415", lace="FFF0CC86"),
    "Gold":   dict(main="FFEEE4C8", cuff="FFD8B04A", sole="FF8A7440", lace="FFB08A2A"),
}
AUGMENTS = ["None", "Leaf", "Crystal", "Flame", "Star"]
SKINS = {"Porcelain": "FFF4D9C6", "Light": "FFE9BC98", "Medium": "FFC98E68",
         "Tan": "FFA96E47", "Brown": "FF7E4F31", "Deep": "FF55341F"}
HAIRS = {"Black": "FF1E1B1E", "Dark Brown": "FF3B2619", "Brown": "FF6B4226",
         "Auburn": "FF8E3B22", "Blonde": "FFD9B25E", "Silver": "FFC9CCD3"}

SEL = dict(cloak="Forest", eyes="Amber", boots="Brown", augment="None", skin="Medium", hair="Dark Brown")


def reset_selection():
    SEL.update(cloak="Forest", eyes="Amber", boots="Brown", augment="None", skin="Medium", hair="Dark Brown")


# recolour registry for the artboard being built: role -> [SolidColor keys]
RECOLOR = {}


def tone(role, palette, suffix=""):
    """A Solid whose colour follows a recolour slot (skin/hair)."""
    keys = RECOLOR.setdefault(role, [])
    key = f"{role}_{len(keys)}"
    keys.append(key)
    names = SKINS if role == "skin" else HAIRS
    return Solid(names[SEL[role]], key=key)


# ------------------------------------------------------------------ hood + cloak
HOOD_SHELL = [
    (-50, -366, 0, 0, 24, -4), (30, -358, -30, -4, 20, 6), (78, -326, -8, -14, -4, 6),
    (42, -314, 14, -4, -14, 5), (12, -280, 6, -14, -3, 17), (6, -236, 0, -16, 3, 10),
    (24, -214), (-46, -208, 26, 0, -24, -10), (-88, -292, 0, 38, 2, -40),
]
HOOD_TRIM = [(78, -326, 0, 0, -12, 4), (42, -314, 14, -4, -14, 5), (12, -280, 6, -14, -3, 17),
             (6, -236, 0, -16, 0, 0)]
HOOD_SHADOW = [(66, -318, 0, 0, -12, 3), (32, -304, 12, -4, -12, 6), (8, -276, 5, -12, -2, 14), (4, -244, 0, -12, 0, 0)]
HOOD_LINING = [(-44, -358, -18, 0, 30, -4), (64, -336, -24, -8, 18, 12), (92, -300, 0, -14, 0, 14),
               (74, -222, 14, 4, -40, 6), (-40, -218, 30, 4, -14, -12), (-66, -290, 0, 26, 2, -30)]
BACK_CAPE = [
    (-30, -236, 0, 0, -30, 6), (-100, -200, 18, -16, -22, 24), (-146, -120, 10, -30, -8, 26),
    (-172, -66, 4, -12, 12, 6), (-130, -76, -14, 2, 12, 10), (-94, -58, -12, 2, 12, -4),
    (-58, -72, -10, -6, 10, 8), (0, -52), (70, -62), (114, -56, -12, 4, 10, -2),
    (150, -74, -8, 10, -4, -24), (124, -150, 8, 26, -6, -24), (80, -210, 20, 18, -18, -14),
    (20, -234, 24, 0, -20, 0),
]
CAPE_FOLDS = [
    [(-122, -150, 0, 0, -4, 26), (-134, -92, 0, 0, 0, 0), (-110, -96, 0, 0, 0, 0), (-108, -150, -4, 30, 0, 0)],
    [(-82, -170, 0, 0, -2, 30), (-86, -80, 0, 0, 0, 0), (-72, -84, 0, 0, 0, 0), (-70, -160, 0, 24, 0, 0)],
    [(120, -140, 0, 0, 6, 26), (134, -72, 0, 0, 0, 0), (124, -64, 0, 0, 0, 0), (114, -130, 4, 26, 0, 0)],
]
DRAPE_NEAR = [(22, -216, 0, 0, 24, 0), (88, -206, -18, -8, 18, 12), (120, -150, -4, -24, 4, 26),
              (134, -86, -4, -20, 0, 0), (100, -92, 10, 2, -8, -18), (76, -150, 6, 22, -6, -22),
              (38, -200, 12, 10, 0, 0)]
DRAPE_FAR = [(8, -218, 0, 0, -26, 0), (-80, -210, 22, -6, -20, 12), (-118, -150, 6, -24, -4, 26),
             (-136, -86, 4, -20, 0, 0), (-98, -92, -10, 2, 8, -18), (-72, -150, -6, 22, 6, -22),
             (-20, -200, -12, 10, 0, 0)]
NEAR_EDGE = [(38, -200, 0, 0, 12, 10), (76, -150, -6, -22, 6, 22), (100, -92, -8, -18, 0, 0)]
FAR_EDGE = [(-20, -200, 0, 0, -12, 10), (-72, -150, 6, -22, -6, 22), (-98, -92, 8, -18, 0, 0)]
BROOCH_AT = (18, -194)


def hood_shell(name, c):
    return Node(f"Hood {name}", [
        Shape("Hood Trim", 0, 0, Path(HOOD_TRIM, closed=False), [Stroke(c["trim"], 3)]),
        Shape("Hood Shadow", 6, 2, Path(HOOD_SHADOW, closed=False), [Stroke("AA140A05", 14, feather=12)]),
        Shape("Hood Shell", 0, 0, Path(HOOD_SHELL),
              [Fill(LinGrad(30, -366, -70, -226, [(0, c["hi"]), (0.35, c["main"]), (1, c["shade"])]))]),
    ], key=f"hood_{name}")


def hood_lining(name, c):
    return Node(f"Hood Lining {name}", [Shape("Hood Lining", 0, 0, Path(HOOD_LINING), [Fill(c["lining"])])],
                key=f"lining_{name}")


def brooch(c):
    return Node("Brooch", [
        Shape("Gem Shine", -2, -3, Ellipse(4, 4), [Fill("EEFFFFFF")]),
        Shape("Gem", 0, 0, Rect(11, 11, 1.5), [Fill(c["gem"])], rot=math.pi / 4),
        Shape("Gem Setting", 0, 0, Rect(18, 18, 2.5), [Fill("FFD9A93A")], rot=math.pi / 4),
        Shape("Gem Glow", 0, 0, Ellipse(18, 18), [Stroke(c["gemglow"], 6, feather=9)]),
    ], x=BROOCH_AT[0], y=BROOCH_AT[1])


def cloak_front(name, c):
    return Node(f"Cloak Front {name}", [
        brooch(c),
        Shape("Near Edge Trim", 0, 0, Path(NEAR_EDGE, closed=False), [Stroke(c["trim"], 3)]),
        Shape("Drape Near", 0, 0, Path(DRAPE_NEAR),
              [Fill(LinGrad(60, -214, 120, -90, [(0, c["hi"]), (0.5, c["main"]), (1, c["main"])]))]),
        Shape("Far Edge Trim", 0, 0, Path(FAR_EDGE, closed=False), [Stroke(c["trim"], 3)]),
        Shape("Drape Far", 0, 0, Path(DRAPE_FAR),
              [Fill(LinGrad(-40, -214, -120, -90, [(0, c["main"]), (1, c["shade"])]))]),
    ], key=f"cloakF_{name}")


def cloak_back(name, c):
    folds = [Shape(f"Fold {i + 1}", 0, 0, Path(f), [Fill(c["shade"] if i < 2 else c["hi"])])
             for i, f in enumerate(CAPE_FOLDS)]
    return Node(f"Cloak Back {name}", folds + [
        Shape("Back Cape", 0, 0, Path(BACK_CAPE),
              [Fill(LinGrad(120, -200, -150, -70, [(0, c["hi"]), (0.45, c["main"]), (1, c["shade"])]))]),
    ], key=f"cloakB_{name}")


def solo(name, key, prefix, variants, builder):
    return Node(name, [builder(n, c) for n, c in variants.items()], key=key,
                solo_active=f"{prefix}_{SEL['cloak' if prefix in ('hood', 'lining', 'cloakF', 'cloakB') else prefix]}")


# ------------------------------------------------------------------ eyes
def eye(c, scale=1.0, w=14, h=17):
    return [
        Shape("Sparkle", -3 * scale, -4 * scale, Ellipse(4 * scale, 4 * scale), [Fill("FFFFFFFF")]),
        Shape("Core", 0, 0, Ellipse(w * 0.5 * scale, h * 0.53 * scale), [Fill(c["core"])]),
        Shape("Iris", 0, 0, Ellipse(w * scale, h * scale), [Fill(c["iris"])]),
        Shape("Glow", 0, 0, Ellipse((w + 1) * scale, (h + 1) * scale), [Stroke(c["glow"], 7 * scale, feather=8 * scale)]),
    ]


def eyes_node(spec):
    """spec: dict(at=(x,y), eyes=[(dx, dy, scale)], size=(w,h))"""
    w, h = spec.get("size", (14, 17))
    variants = []
    for name, c in EYES.items():
        parts = []
        for dx, dy, sc in spec["eyes"]:
            parts.append(Node("Eye", eye(c, sc, w, h), x=dx, y=dy))
        variants.append(Node(f"Eyes {name}", parts, key=f"eyes_{name}"))
    return Node("Eyes", [Node("Eye Color", variants, key="eye_solo", solo_active=f"eyes_{SEL['eyes']}")],
                x=spec["at"][0], y=spec["at"][1], key="eyes")


# ------------------------------------------------------------------ boots
BOOT = [(-18, -62), (18, -62), (20, -24, 0, -8, 4, 4), (36, -15, -8, -2, 4, 2), (42, -5, 0, -5, -1, 4),
        (36, 0), (-20, 0), (-23, -10, 0, 5, 0, -6)]


def boot(name, x, c, scale=1.0):
    return Node(name, [
        Shape("Lace 3", 12, -26, Rect(15, 2.6, 1), [Fill(c["lace"])], rot=-0.25),
        Shape("Lace 2", 12, -34, Rect(15, 2.6, 1), [Fill(c["lace"])], rot=-0.25),
        Shape("Lace 1", 12, -42, Rect(15, 2.6, 1), [Fill(c["lace"])], rot=-0.25),
        Shape("Cuff", 0, -60, Rect(44, 16, 7), [Fill(c["cuff"])]),
        Shape("Sole", 10, -3, Rect(64, 8, 3), [Fill(c["sole"])]),
        Shape("Boot", 0, 0, Path(BOOT),
              [Fill(LinGrad(-22, -60, 42, 0, [(0, c["cuff"]), (0.35, c["main"]), (1, c["main"])]))]),
    ], x=x, sx=scale, sy=scale)


def boots_variant(name, c):
    return Node(f"Boots {name}", [boot("Boot Near", 36, c), boot("Boot Far", -44, c, 0.93)], key=f"boots_{name}")


# ------------------------------------------------------------------ arms
ARM = [(-15, -4, 0, -10, 0, 0), (15, -4, 0, 0, 0, 8), (17, 38, 0, -14, 0, 10), (0, 62, 12, 0, -12, 0),
       (-17, 38, 0, 10, 0, -14)]
WING = [(-14, -4, 0, -8, 8, -4), (16, -2, -8, -4, 6, 14), (22, 40, 0, -18, -2, 20), (6, 88),
        (-6, 64, 2, 10, -4, -12), (-18, 24, 0, 14, 0, -12)]
REST_ARM_NEAR, REST_ARM_FAR = -0.22, 0.25
ARM_NEAR_AT, ARM_FAR_AT = (70, -196), (-62, -194)


def arm(name, at, rot, style, key=None, near=True):
    """style: dict(kind='paw'|'hand'|'wing', fur=Paint, dark=color, hand=Paint)"""
    style = {k: (v() if callable(v) else v) for k, v in style.items()}   # fresh paints per arm (recolour keys must be unique)
    kind = style.get("kind", "paw")
    fur = style["fur_near"] if near else style["fur_far"]
    if kind == "wing":
        parts = [
            Shape("Feather Stripe 2", 0, 0, Path([(-4, 30, 0, 0, 8, 10), (12, 58, 0, 0, 0, 0)], closed=False),
                  [Stroke(style.get("stripe", "66FFFFFF"), 3)]),
            Shape("Feather Stripe 1", 0, 0, Path([(-8, 12, 0, 0, 10, 10), (14, 36, 0, 0, 0, 0)], closed=False),
                  [Stroke(style.get("stripe", "66FFFFFF"), 3)]),
            Shape("Wing", 0, 0, Path(WING), [Fill(fur)]),
        ]
    else:
        hand_paint = style["hand"]
        hand = (Shape("Hand", 0, 56, Ellipse(26, 24), [Fill(hand_paint)]) if kind == "hand"
                else Shape("Paw", 0, 56, Ellipse(32, 24), [Fill(hand_paint)]))
        parts = [hand, Shape("Arm", 0, 0, Path(ARM), [Fill(fur)])]
    return Node(name, parts, x=at[0], y=at[1], rot=rot, key=key)


# ------------------------------------------------------------------ augments
LEAF = [(0, -16, 0, 0, 10, 6), (0, 16, 10, -6, -10, -6)]


def leaf(name, x, y, rot, size=1.0, key=None):
    return Node(name, [
        Shape("Vein", 0, 0, Path([(0, -13 * size), (0, 13 * size)], closed=False), [Stroke("FF2F6B2C", 1.6 * size)]),
        Shape("Leaf", 0, 0, Path([(0, -16 * size, 0, 0, 12 * size, 6 * size), (0, 16 * size, 12 * size, -8 * size, -12 * size, -8 * size)]),
              [Fill(LinGrad(0, -16, 0, 16, [(0, "FF8EE06A"), (1, "FF3E9A3A")]))]),
    ], x=x, y=y, rot=rot, key=key)


def four_star(name, outer, inner, paint, x=0, y=0, key=None, glow=None):
    pts = []
    for i in range(8):
        r = outer if i % 2 == 0 else inner
        a = -math.pi / 2 + i * math.pi / 4
        pts.append((round(r * math.cos(a), 2), round(r * math.sin(a), 2)))
    shapes = [Shape(name, 0, 0, Path(pts), [Fill(paint)])]
    if glow:
        shapes.append(Shape(name + " Glow", 0, 0, Ellipse(outer * 1.2, outer * 1.2), [Stroke(glow, outer * 0.5, feather=outer * 0.7)]))
    return Node(name, shapes, x=x, y=y, key=key)


CRYSTAL = [(0, -34), (14, -10), (10, 22), (0, 34), (-10, 22), (-14, -10)]
FLAME = [(0, -46, 0, 0, 4, 14), (18, -4, 2, -16, 2, 14), (0, 26, 14, 0, -14, 0), (-18, -4, -2, 14, -2, -16),
         (-4, -28, -4, 10, 2, -8)]
STAR_ORBIT = dict(cx=0, cy=-196, rx=172, ry=38)


def augments():
    leaf_aug = Node("Augment Leaf", [
        leaf("Leaf Brooch", BROOCH_AT[0] + 2, BROOCH_AT[1] - 4, 0.7, 1.15),
        leaf("Floating Leaf 1", -150, -286, 0.4, 1.35, key="fx_leaf1"),
        leaf("Floating Leaf 2", 150, -236, -0.5, 1.2, key="fx_leaf2"),
        leaf("Floating Leaf 3", -120, -150, 0.9, 0.9, key="fx_leaf3"),
    ], key="aug_Leaf")
    crystal_aug = Node("Augment Crystal", [Node("Crystal Bob", [
        four_star("Spark 1", 7, 1.6, "FFE8FDFF", x=18, y=-30),
        four_star("Spark 2", 5, 1.2, "FFE8FDFF", x=-16, y=24),
        Shape("Facet", 0, 0, Path([(0, -34), (4, -8), (0, 34), (-4, -8)]), [Fill("66FFFFFF")]),
        Shape("Crystal", 0, 0, Path(CRYSTAL), [Fill(LinGrad(0, -34, 0, 34, [(0, "FFD9FBFF"), (0.5, "FF5FDDF5"), (1, "FF2A8FC8")]))]),
        Shape("Crystal Glow", 0, 0, Ellipse(40, 60), [Stroke("AA3FD0F0", 12, feather=14)]),
    ], key="fx_crystal")], x=152, y=-292, key="aug_Crystal")
    embers = [Shape(f"Ember {i + 1}", dx, 0, Ellipse(5, 5), [Fill("FFFFC45A")], key=f"fx_ember{i + 1}")
              for i, dx in enumerate((-8, 6, 0))]
    flame_aug = Node("Augment Flame", [
        Node("Embers", embers, y=-30),
        Node("Flame Flicker", [
            Shape("Flame Core", 0, 8, Path([(0, -20, 0, 0, 2, 8), (9, 2, 0, -8, 0, 8), (0, 14, 7, 0, -7, 0), (-9, 2, 0, 8, 0, -8)]),
                  [Fill("FFFFF1A8")]),
            Shape("Flame", 0, 0, Path(FLAME), [Fill(LinGrad(0, -46, 0, 26, [(0, "FFFFD04A"), (0.6, "FFFF7A1E"), (1, "FFE0401A")]))]),
            Shape("Flame Glow", 0, -6, Ellipse(44, 66), [Stroke("AAFF6A1A", 12, feather=16)]),
        ], key="fx_flame"),
    ], x=156, y=-178, key="aug_Flame")
    o = STAR_ORBIT
    dots = [Shape(f"Orbit Dot {i}", round(o["rx"] * math.cos(a), 1), round(o["cy"] + o["ry"] * math.sin(a), 1),
                  Ellipse(4, 4), [Fill("CCFFE08A")]) for i, a in enumerate([k * math.pi / 9 for k in range(18)])]
    star_aug = Node("Augment Star", [
        four_star("Orbiting Star", 17, 4.5, "FFFFD76A", x=o["rx"], y=o["cy"], key="fx_star", glow="AAFFC94D"),
        Node("Orbit Ring", dots),
    ], key="aug_Star")
    return Node("Augment", [Node("Augment None", [], key="aug_None"), leaf_aug, crystal_aug, flame_aug, star_aug],
                key="aug_solo", solo_active=f"aug_{SEL['augment']}")


def augment_fx_tracks():
    """(key, prop, frames) for the always-running augment loop (240 frames)."""
    X, Y, ROT, SX, SY, OP = 13, 14, 15, 16, 17, 18
    E = (0.42, 0, 0.58, 1)
    t = [
        ("fx_leaf1", Y, [(-286, 0, E), (-298, 120, E), (-286, 240, None)]),
        ("fx_leaf1", ROT, [(0.4, 0, E), (0.05, 120, E), (0.4, 240, None)]),
        ("fx_leaf2", Y, [(-236, 0, E), (-226, 120, E), (-236, 240, None)]),
        ("fx_leaf2", ROT, [(-0.5, 0, E), (-0.15, 120, E), (-0.5, 240, None)]),
        ("fx_leaf3", Y, [(-150, 0, E), (-140, 120, E), (-150, 240, None)]),
        ("fx_leaf3", ROT, [(0.9, 0, E), (1.3, 120, E), (0.9, 240, None)]),
        ("fx_crystal", Y, [(0, 0, E), (-12, 120, E), (0, 240, None)]),
        ("fx_crystal", ROT, [(-0.08, 0, E), (0.08, 120, E), (-0.08, 240, None)]),
        ("fx_flame", SY, [(1, 0, E), (1.12, 40, E), (0.95, 90, E), (1.08, 150, E), (0.97, 200, E), (1, 240, None)]),
        ("fx_flame", SX, [(1, 0, E), (0.94, 40, E), (1.04, 90, E), (0.96, 150, E), (1.02, 200, E), (1, 240, None)]),
    ]
    for i, off in enumerate((0, 40, 80)):
        t.append((f"fx_ember{i + 1}", Y, cycle_keys(off, 120, 0, -58)))
        t.append((f"fx_ember{i + 1}", OP, cycle_keys(off, 120, 1, 0)))
    o = STAR_ORBIT
    xs, ys, ss, ops = [], [], [], []
    for k in range(25):
        f = k * 10
        a = 2 * math.pi * f / 240
        s = math.sin(a)
        xs.append((round(o["rx"] * math.cos(a), 2), f, None))
        ys.append((round(o["cy"] + o["ry"] * s, 2), f, None))
        ss.append((round(0.8 + 0.25 * s, 3), f, None))
        ops.append((round(0.7 + 0.3 * s, 3), f, None))
    t += [("fx_star", X, xs), ("fx_star", Y, ys), ("fx_star", SX, ss), ("fx_star", SY, ss), ("fx_star", OP, ops)]
    return t


def cycle_keys(offset, period, v0, v1, total=240):
    """Linear v0->v1 ramps every `period` frames, starting `offset` frames in,
    snapping back with a hold key at each wrap."""
    keys = []
    def val(f):
        ph = ((f - offset) % period) / period
        return v0 + (v1 - v0) * ph
    wraps = sorted({(offset + k * period) % total for k in range(total // period + 1)})
    frames = sorted(set([0, total] + wraps + [w - 1 for w in wraps if w > 0]))
    for f in frames:
        if f == total and (total - offset) % period == 0:
            keys.append((round(v1, 3), f, None))
        elif f in wraps and f > 0:
            keys.append((round(v0, 3), f, None))
        elif f + 1 in wraps and f + 1 > 0:
            keys.append((round(v1, 3), f, "hold"))
        else:
            keys.append((round(val(f), 3), f, None))
    return keys
