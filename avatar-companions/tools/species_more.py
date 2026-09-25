"""Waves 2-4: seventeen more companions built from reusable parts.

Every animal is an `Animal(cfg)`: head outline template + muzzle/nose/mouth +
ears (or horns/gills/eye-bumps) over the hood + face markings under it +
body silhouette/colours + arms + optional tail/back pieces. Shared cloak,
boots, eyes slot, augments and animations come from kit.py.
"""
import math
from rivegen import Shape, Node, Ellipse, Rect, Path, Fill, Stroke, LinGrad, RadGrad
from species_wave1 import (Species, pointed_ear, round_ear, grad_v, ROUND_BODY, ROUND_BELLY, SLIM_BODY,
                           FOX_HEAD, FOX_TAIL, FOX_TAIL_TIP)

ROT = 15
E = (0.42, 0, 0.58, 1)

HEAD_ROUND = [(2, -346, -38, 0, 38, 0), (64, -334, -20, -8, 16, 10), (92, -306, -6, -14, 4, 10),
              (104, -284, -4, -8, 2, 10), (104, -264, 2, -8, -4, 8), (86, -244, 12, -6, -14, 6),
              (24, -228, 24, -2, -24, 0), (-38, -238, 20, 8, -12, -12), (-60, -286, 0, 22, 0, -26),
              (-38, -330, -12, 12, 14, -8)]
HEAD_LONG = [(0, -348, -36, 0, 34, 0), (52, -334, -18, -6, 16, 8), (92, -306, -12, -10, 12, 8),
             (122, -286, -4, -6, 3, 8), (116, -268, 6, -4, -12, 2), (86, -256, 12, -4, -10, 6),
             (62, -238, 10, -8, -14, 6), (26, -228, 14, -2, -18, 0), (-38, -240, 22, 8, -14, -12),
             (-60, -292, 2, 24, -2, -26), (-38, -334, -10, 12, 14, -8)]
HEAD_FLAT = [(2, -330, -40, 0, 40, 0), (76, -322, -22, -6, 16, 10), (108, -294, -2, -14, 2, 14),
             (110, -262, 2, -12, -6, 12), (84, -238, 18, -6, -22, 6), (20, -228, 26, 0, -26, 0),
             (-40, -238, 20, 8, -12, -12), (-60, -282, 0, 20, 0, -22), (-40, -318, -12, 10, 14, -8)]
HEAD_BIRD = [(4, -350, -40, 0, 40, 0), (70, -336, -22, -8, 16, 12), (98, -300, -2, -16, 2, 18),
             (96, -264, 4, -14, -8, 14), (74, -238, 18, -6, -20, 6), (18, -226, 26, 0, -26, 0),
             (-40, -238, 20, 8, -12, -12), (-62, -288, 0, 22, 0, -28), (-40, -334, -12, 12, 14, -8)]
HEAD_SNOUT = [(-2, -348, -38, 0, 40, 0), (60, -330, -22, -8, 14, 6), (98, -304, -8, -10, 6, 8),
              (112, -272, 2, -14, -2, 12), (96, -244, 10, -8, -16, 6), (28, -224, 24, -2, -26, 1),
              (-36, -236, 24, 5, -18, -7), (-60, -284, 3, 21, -2, -26), (-40, -332, -12, 12, 14, -9)]

SLIM_BELLY = [(30, -192, 0, 0, 16, 10), (56, -134, 0, -24, 0, 24), (40, -88, 12, -4, -16, 2),
              (10, -92, 8, 6, -4, -26), (14, -160, -4, 16, 4, -14)]
W_MOUTH = [(84, -258, 0, 0, 3, 5), (91, -255, -3, 2, 3, -2), (98, -259, -3, 4, 0, 0)]
SMILE = [(74, -254, 0, 0, 8, 6), (96, -258, -8, 4, 0, 0)]


def whiskers(color="99FFFFFF", at=(96, -266)):
    x, y = at
    return [Shape(f"Whisker {i}", 0, 0, Path([(x, y + dy), (x + 30, y + dy + dy2)], closed=False), [Stroke(color, 1.6)])
            for i, (dy, dy2) in enumerate(((-4, -6), (2, 0), (8, 6)))]


def stripe(name, pts, color, w=5):
    return Shape(name, 0, 0, Path(pts, closed=False), [Stroke(color, w)])


# ------------------------------------------------------------------ tails (pivot at the lower back)
def tail_bushy(top, bottom, tip, scale=1.0, rings=None):
    parts = []
    if rings:
        for i, (a, b) in enumerate(((-46, -34), (-92, -74), (-108, -126))):
            parts.append(Shape(f"Ring {i}", 0, 0, Path([a if isinstance(a, tuple) else (a, -10 - 30 * i), b if isinstance(b, tuple) else (b + 30, -40 - 40 * i)], closed=False),
                               [Stroke(rings, 16, cap="butt")]))
    parts = ([Shape("Tail Tip", 0, 0, Path(FOX_TAIL_TIP), [Fill(tip)])] if tip else []) + parts
    parts.append(Shape("Tail", 0, 0, Path(FOX_TAIL), [Fill(LinGrad(0, 0, -110, -170, [(0, bottom), (1, top)]))]))
    return Node("Tail", parts, x=-70, y=-108, sx=scale, sy=scale, key="tail")


def tail_ringed(top, ring, scale=1.0):
    """Bushy tail with dark bands (red panda, raccoon): a banded gradient along the tail."""
    stops = [(0, top)]
    for a in (0.2, 0.45, 0.7):
        stops += [(a, top), (a + 0.01, ring), (a + 0.11, ring), (a + 0.12, top)]
    stops.append((1, top))
    return Node("Tail", [Shape("Tail Tip", 0, 0, Path(FOX_TAIL_TIP), [Fill(ring)]),
                         Shape("Tail", 0, 0, Path(FOX_TAIL), [Fill(LinGrad(0, 0, -96, -176, stops))])],
                x=-70, y=-108, sx=scale, sy=scale, key="tail")


def tail_thin(color, width=12, stripes=None, tip=None):
    curve = [(0, 0, 0, 0, -30, 10), (-80, -10, 20, 14, -18, -16), (-104, -80, 6, 22, -2, -22), (-84, -128, -12, 6, 0, 0)]
    parts = []
    if tip:
        parts.append(Shape("Tail Tip", -84, -128, Ellipse(width + 2, width + 2), [Fill(tip)]))
    if stripes:
        for i, (x, y) in enumerate(((-60, -4), (-94, -40), (-104, -86))):
            parts.append(Shape(f"Stripe {i}", x, y, Rect(width + 4, 4, 1), [Fill(stripes)], rot=0.9 - 0.5 * i))
    parts.append(Shape("Tail", 0, 0, Path(curve, closed=False), [Stroke(color, width)]))
    return Node("Tail", parts, x=-66, y=-96, key="tail")


def tail_flat(color, dark):
    paddle = [(0, 0, 0, 0, -30, -4), (-76, -4, 20, -4, -20, 4), (-126, 22, 4, -10, -4, 10), (-80, 32, -24, 0, 24, 0), (0, 22, -20, 0, 0, 0)]
    return Node("Tail", [Shape("Tail", 0, 0, Path(paddle), [Fill(LinGrad(0, 0, -126, 0, [(0, color), (1, dark)]))])],
                x=-56, y=-82, rot=0.35, key="tail")


def tail_dragon(color, dark, spike):
    body = [(0, 0, 0, 0, -30, 6), (-80, -6, 26, 10, -26, -14), (-120, -72, 4, 26, -2, -20), (-110, -110), (-100, -72, -2, -16, -4, 12),
            (-70, -28, -12, -8, 20, 6), (2, -26, -24, 0, 0, 0)]
    spikes = [Shape(f"Spike {i}", x, y, Path([(-6, 0), (0, -12), (6, 0)]), [Fill(spike)], rot=r)
              for i, (x, y, r) in enumerate(((-40, -8, -0.5), (-78, -24, -0.9), (-104, -60, -1.3)))]
    tip = Shape("Tail Tip", -110, -114, Path([(-12, 6), (0, -18), (12, 6), (0, 0)]), [Fill(spike)])
    return Node("Tail", [tip] + spikes + [Shape("Tail", 0, 0, Path(body), [Fill(LinGrad(0, 0, -120, -100, [(0, dark), (1, color)]))])],
                x=-60, y=-100, key="tail")


def dragon_wings(membrane, bone):
    wing = [(0, 0), (-40, -60, 0, 0, 0, 0), (-110, -86), (-92, -56, -6, -8, 6, 8), (-78, -40), (-66, -20, -4, -8, 4, 8), (-48, -4)]
    def one(name, x, y, sx, key):
        return Node(name, [Shape("Wing Bone", 0, 0, Path([(0, 0), (-40, -60), (-110, -86)], closed=False), [Stroke(bone, 5)]),
                           Shape("Wing", 0, 0, Path(wing), [Fill(membrane)])], x=x, y=y, sx=sx, key=key)
    return [one("Wing Near", 64, -214, -1, "wing_near"), one("Wing Far", -52, -218, 1, "wing_far")]


# ------------------------------------------------------------------ generic animal
class Animal(Species):
    def __init__(self, **cfg):
        self.c = cfg
        self.ARTBOARD = cfg["name"]

    def head(self):
        c = self.c
        face_top, face_under, over = list(c.get("face_top", [])), list(c.get("face_under", [])), list(c.get("over_hood", []))
        if c.get("mouth"):
            face_top.insert(0, Shape("Mouth", 0, 0, Path(c["mouth"], closed=False), [Stroke(c.get("mouth_color", "FF3A2416"), 2.4)]))
        if c.get("nose"):
            x, y, w, h, col, rot = c["nose"]
            face_top.insert(0, Shape("Nose", x, y, Ellipse(w, h), [Fill(col)], rot=rot))
        if c.get("muzzle"):
            m = c["muzzle"]
            geo = Path(m["path"]) if "path" in m else Ellipse(*m["size"])
            face_under.append(Shape("Muzzle", m.get("x", 0), m.get("y", 0), geo, [Fill(m["color"])], rot=m.get("rot", 0)))
        return dict(
            eyes=c.get("eyes", dict(at=(64, -300), eyes=[(8, 0, 1.0), (-20, -2, 0.8)], size=(12, 14))),
            face_top=face_top, over_hood=over, face_under=face_under,
            head=[Shape("Head", 0, 0, Path(c.get("head_pts", HEAD_ROUND)), key="head",
                        paints=[Fill(grad_v(c["top"], c["bottom"], -350, -226))])],
        )

    def body(self):
        c = self.c
        parts = list(c.get("body_extra", []))
        if c.get("tunic"):
            t = c["tunic"]
            parts += [Shape("Buckle", 24, -124, Rect(13, 13, 2), [Fill("FFD9A93A")], rot=math.pi / 4),
                      Shape("Belt", 0, -124, Rect(140, 13, 3), [Fill(t.get("belt", "FF4A2A18"))]),
                      Shape("Tunic", 0, 0, Path(SLIM_BODY), [Fill(LinGrad(-60, -150, 70, -150, [(0, t["bottom"]), (1, t["top"])]))])]
            return parts
        shape = SLIM_BODY if c.get("slim") else ROUND_BODY
        if c.get("belly"):
            parts.append(Shape("Belly", 0, 0, Path(SLIM_BELLY if c.get("slim") else ROUND_BELLY), [Fill(c["belly"])]))
        parts.append(Shape("Body", 0, 0, Path(shape), [Fill(LinGrad(-80, -150, 90, -120, [(0, c.get("body_dark", c["bottom"])), (1, c.get("body_top", c["top"]))]))]))
        return parts

    def legs(self):
        col = self.c.get("legs", self.c["bottom"])
        return [Shape("Leg Near", 36, -66, Rect(30, 30, 10), [Fill(col)]),
                Shape("Leg Far", -44, -66, Rect(28, 30, 10), [Fill(col)])]

    def back(self):
        return list(self.c.get("back", []))

    def front(self):
        return list(self.c.get("front", []))

    def arm_style(self):
        c = self.c
        if c.get("wings"):
            w = c["wings"]
            return dict(kind="wing", fur_near=LinGrad(0, 0, 0, 88, [(0, w[0]), (1, w[1])]),
                        fur_far=LinGrad(0, 0, 0, 88, [(0, w[1]), (1, w[1])]), stripe=w[2])
        arm_col = c.get("arm", c["top"])
        return self.paw_style(arm_col, c.get("arm_dark", c["bottom"]), c.get("paw", c.get("arm_dark", c["bottom"])))

    def idle_tracks(self):
        t = []
        if any(getattr(p, "key", None) == "tail" for p in self.back()):
            base = next(p for p in self.back() if getattr(p, "key", None) == "tail").rot
            t.append(("tail", ROT, [(base, 0, E), (base + self.c.get("tail_swing", 0.08), 100, None)]))
        if self.c.get("wing_flap"):
            t += [("wing_near", ROT, [(0, 0, E), (0.12, 100, None)]), ("wing_far", ROT, [(0, 0, E), (-0.12, 100, None)])]
        return t


# ------------------------------------------------------------------ the roster
def cat():
    top, bottom, white = "FF7A8291", "FF545B68", "FFF2F0EC"
    return Animal(name="Cat", top=top, bottom=bottom, belly=white, slim=True,
                  muzzle=dict(x=86, y=-268, size=(40, 30), color=white),
                  nose=(99, -279, 10, 7, "FFE88C9A", 0.3), mouth=W_MOUTH,
                  over_hood=[pointed_ear("Ear Near", 38, -348, 0.4, 42, 16, top, "FFE8A0A8"),
                             pointed_ear("Ear Far", -14, -354, -0.2, 40, 15, bottom, "FFE8A0A8")],
                  face_top=whiskers(), face_under=[stripe("Brow Stripe 1", [(40, -330), (52, -320)], "88454B55", 4),
                                                   stripe("Brow Stripe 2", [(56, -334), (64, -322)], "88454B55", 4)],
                  back=[tail_thin(bottom, 13, tip=top)], paw=white)


def bunny():
    top, bottom, pink = "FFF4EFE8", "FFD6CDC2", "FFF2B6C4"
    def long_ear(name, x, y, r, col):
        return Node(name, [Shape("Ear Inner", 0, -34, Ellipse(10, 52), [Fill(pink)]),
                           Shape("Ear", 0, -36, Ellipse(22, 80), [Fill(col)])], x=x, y=y, rot=r)
    return Animal(name="Bunny", top=top, bottom=bottom, belly="FFFFFFFF",
                  nose=(100, -282, 10, 8, "FFF08CA4", 0.2), mouth=W_MOUTH,
                  face_top=[Shape("Teeth", 91, -250, Rect(8, 7, 1.5), [Fill("FFFFFFFF")])],
                  face_under=[Shape("Blush", 82, -268, Ellipse(18, 9), [Fill("66F7A1B8")])],
                  over_hood=[long_ear("Ear Near", 34, -346, 0.25, top), long_ear("Ear Far", -12, -350, -0.2, bottom)],
                  paw="FFE7DDD0", legs=bottom)


def frog():
    top, bottom, belly = "FF74C46E", "FF3F8E49", "FFDDEFB9"
    bump = lambda name, x, y, s: Node(name, [Shape("Bump", 0, 0, Ellipse(34 * s, 30 * s), [Fill(grad_v(top, bottom, -15, 15))])], x=x, y=y)
    return Animal(name="Frog", top=top, bottom=bottom, belly=belly, head_pts=HEAD_FLAT,
                  eyes=dict(at=(40, -346), eyes=[(30, 2, 1.0), (-14, -4, 0.85)], size=(13, 14)),
                  over_hood=[bump("Eye Bump Near", 70, -344, 1.0), bump("Eye Bump Far", 26, -350, 0.85)],
                  mouth=[(56, -262, 0, 0, 16, 10), (104, -270, -12, 8, 0, 0)], mouth_color="FF2C5C33",
                  face_under=[Shape("Blush", 90, -272, Ellipse(18, 9), [Fill("77F79AA8")]),
                              Shape("Spot 1", 20, -312, Ellipse(9, 7), [Fill("AA3F8E49")])],
                  paw=belly, legs=bottom)


def red_panda():
    rust, dark, white = "FFD0582C", "FF3A1E16", "FFF6EEE6"
    ear = lambda name, x, y, r, col: Node(name, [Shape("Ear Rim", 0, 0, Path([(-15, 4, 0, 0, 0, -14), (0, -34, -10, 6, 10, 6), (15, 4, 0, -14, 0, 0)]), [Stroke(white, 4)]),
                                                 Shape("Ear", 0, 0, Path([(-15, 4, 0, 0, 0, -14), (0, -34, -10, 6, 10, 6), (15, 4, 0, -14, 0, 0)]), [Fill(col)])], x=x, y=y, rot=r)
    return Animal(name="RedPanda", top=rust, bottom="FFA8401E", belly=dark, arm=dark, arm_dark=dark, paw="FF24130E", legs=dark,
                  muzzle=dict(x=88, y=-266, size=(40, 30), color=white),
                  nose=(101, -279, 10, 8, "FF24130E", 0.3), mouth=W_MOUTH,
                  face_under=[Shape("Brow Patch", 64, -318, Ellipse(12, 8), [Fill(white)]),
                              stripe("Tear Mark", [(70, -290), (74, -262)], "FF8E3418", 5)],
                  over_hood=[ear("Ear Near", 40, -346, 0.3, rust), ear("Ear Far", -14, -352, -0.25, "FFA8401E")],
                  back=[tail_ringed(rust, "FF7A2A12")])


def penguin():
    black, white, beak = "FF28323F", "FFF4F6F8", "FFF29A38"
    face = [(24, -318, 0, 0, 20, -10), (70, -324, -16, -2, 16, 6), (96, -296, -4, -12, 2, 14), (92, -262, 2, -10, -6, 10),
            (70, -242, 12, -2, -14, 2), (36, -252, 10, 8, -8, -8), (22, -284, 0, 16, 0, -14)]
    return Animal(name="Penguin", top="FF36414F", bottom=black, belly=white, head_pts=HEAD_BIRD,
                  eyes=dict(at=(60, -292), eyes=[(10, 0, 1.0), (-16, -2, 0.82)], size=(12, 14)),
                  face_under=[Shape("Face Patch", 0, 0, Path(face), [Fill(white)])],
                  face_top=[Shape("Beak", 0, 0, Path([(88, -280, 0, 0, 10, 0), (116, -270), (90, -262, 6, 2, 0, 0)]), [Fill(beak)])],
                  wings=(black, "FF1C242F", "33FFFFFF"), legs=beak)


def raccoon():
    grey, dark, white = "FF8E9098", "FF2D2F36", "FFEDEDED"
    mask = [(26, -312, 0, 0, 20, -4), (82, -306, -14, -4, 10, 6), (96, -290, 0, -8, -4, 8), (78, -282, 10, -2, -16, 0),
            (48, -290, 12, 2, -12, -2), (24, -288, 6, 4, 0, 0)]
    ear = lambda name, x, y, r, col: Node(name, [Shape("Ear Rim", 0, 0, Path([(-14, 4), (0, -30), (14, 4)]), [Stroke(white, 4, join="round")]),
                                                 Shape("Ear", 0, 0, Path([(-14, 4), (0, -30), (14, 4)]), [Fill(col)])], x=x, y=y, rot=r)
    return Animal(name="Raccoon", top=grey, bottom="FF6A6C74", belly="FFB9BAC0", paw=dark,
                  muzzle=dict(x=90, y=-266, size=(38, 28), color=white),
                  nose=(102, -278, 11, 8, dark, 0.3), mouth=W_MOUTH,
                  face_under=[Shape("Brow", 58, -318, Ellipse(40, 10), [Fill(white)], rot=-0.1),
                              Shape("Mask", 0, 0, Path(mask), [Fill(dark)])],
                  over_hood=[ear("Ear Near", 38, -346, 0.35, grey), ear("Ear Far", -14, -352, -0.25, "FF6A6C74")],
                  tunic=dict(top="FF3A3F4A", bottom="FF23262D", belt="FF1A1C21"),
                  back=[tail_ringed(grey, dark)])


def wolf():
    top, bottom, light = "FF8C97A6", "FF5E6776", "FFE8EBF0"
    muzzle = [(58, -284, 0, 0, 22, -6), (108, -290, -12, -2, 10, 2), (122, -286), (116, -268, 6, -4, -12, 2),
              (86, -256, 12, -4, -10, 6), (62, -238, 10, -8, -14, 4), (28, -228, 14, 0, -4, -10), (32, -256, -4, 12, 10, -14)]
    return Animal(name="Wolf", top=top, bottom=bottom, head_pts=HEAD_LONG,
                  eyes=dict(at=(64, -306), eyes=[(0, 0, 1.0), (-28, -3, 0.78)], size=(13, 15)),
                  muzzle=dict(path=muzzle, color=light),
                  nose=(120, -284, 14, 10, "FF22262D", 0.3),
                  mouth=[(86, -258, 0, 0, 6, 3), (102, -264, 0, 0, 0, 0)], mouth_color="FF22262D",
                  over_hood=[pointed_ear("Ear Near", 40, -350, 0.35, 50, 17, top, "FF3E4550"),
                             pointed_ear("Ear Far", -16, -356, -0.2, 46, 16, bottom, "FF3E4550")],
                  body_extra=[Shape("Chest Fluff", 0, 0, Path([(-4, -240, 0, 0, 24, 0), (48, -234, 0, 0, -6, 20), (22, -190, 10, -6, -10, -6)]), [Fill(light)])],
                  tunic=dict(top="FF5B4A3A", bottom="FF3A2E24", belt="FF22190F"),
                  legs=bottom, back=[tail_bushy(top, bottom, light)])


def bear():
    top, bottom, light = "FF94603A", "FF5E3A22", "FFD4A87C"
    return Animal(name="BearCub", top=top, bottom=bottom, belly="FFB7875C",
                  muzzle=dict(x=86, y=-266, size=(46, 34), color=light),
                  nose=(100, -280, 14, 10, "FF2A1A10", 0.25), mouth=W_MOUTH,
                  over_hood=[round_ear("Ear Near", 40, -350, 0.3, 30, 28, top, "FF4A2E1C"),
                             round_ear("Ear Far", -18, -354, -0.3, 28, 26, bottom, "FF4A2E1C")],
                  paw="FF4A2E1C", legs=bottom)


def otter():
    top, bottom, light = "FF7E5538", "FF563823", "FFDCC29E"
    face = [(40, -300, 0, 0, 30, -6), (100, -292, -10, -6, 6, 10), (104, -262, 4, -10, -8, 12), (80, -238, 14, -4, -16, 4),
            (36, -244, 12, 6, -8, -10), (30, -276, 0, 12, 0, -10)]
    return Animal(name="Otter", top=top, bottom=bottom, belly=light, slim=True,
                  muzzle=dict(path=face, color=light),
                  nose=(100, -281, 14, 9, "FF2A1A10", 0.2), mouth=W_MOUTH,
                  face_top=whiskers("AAFFFFFF", (98, -268)),
                  over_hood=[round_ear("Ear Near", 34, -344, 0.3, 18, 16, top, bottom),
                             round_ear("Ear Far", -18, -348, -0.3, 16, 14, bottom, bottom)],
                  paw="FF3E2818", back=[tail_flat(bottom, "FF3E2818")], tail_swing=0.06)


def panda():
    white, black = "FFF6F6F2", "FF23262C"
    patch = lambda name, x, y, s, r: Shape(name, x, y, Ellipse(22 * s, 16 * s), [Fill(black)], rot=r)
    return Animal(name="Panda", top=white, bottom="FFDCDCD6", belly="FFFFFFFF", arm=black, arm_dark=black, paw="FF15171B",
                  muzzle=dict(x=86, y=-268, size=(44, 32), color="FFFFFFFF"),
                  nose=(100, -280, 13, 9, black, 0.25), mouth=W_MOUTH, mouth_color=black,
                  eyes=dict(at=(64, -300), eyes=[(8, 0, 1.0), (-20, -2, 0.8)], size=(11, 13)),
                  face_under=[patch("Eye Patch Near", 72, -300, 1.0, 0.5), patch("Eye Patch Far", 44, -302, 0.85, -0.3)],
                  over_hood=[round_ear("Ear Near", 40, -350, 0.3, 30, 28, black, "FF3A3E46"),
                             round_ear("Ear Far", -18, -354, -0.3, 28, 26, black, "FF3A3E46")],
                  legs=black)


def hedgehog():
    face_col, spine, spine_dark = "FFE8CBA4", "FF6A4A30", "FF4A3220"
    quills = [Shape(f"Quill {i}", x, y, Path([(-10, 6), (0, -24), (10, 6)]), [Fill(spine if i % 2 else spine_dark)], rot=r)
              for i, (x, y, r) in enumerate(((-40, -370, -0.4), (-62, -360, -0.8), (-80, -340, -1.1), (-92, -312, -1.4),
                                             (-96, -284, -1.7), (-92, -256, -2.0), (-16, -374, -0.15), (-76, -236, -2.3)))]
    return Animal(name="Hedgehog", top=face_col, bottom="FFC9A57C", head_pts=HEAD_SNOUT, belly="FFF1DEC4",
                  nose=(110, -272, 11, 9, "FF24160E", 0.3),
                  mouth=[(90, -254, 0, 0, 4, 3), (100, -258, 0, 0, 0, 0)],
                  over_hood=quills + [round_ear("Ear Near", 30, -350, 0.3, 16, 14, face_col, "FFB98C68")],
                  paw="FF6A4A30", legs="FFC9A57C", body_top="FFB08A62", body_dark=spine)


def deer():
    tan, dark, white = "FFC48D58", "FF9A6636", "FFF3E4CC"
    leaf_ear = lambda name, x, y, r, col: Node(name, [Shape("Ear Inner", 0, -16, Ellipse(9, 26), [Fill("FFF0C8B0")]),
                                                      Shape("Ear", 0, -18, Ellipse(18, 42), [Fill(col)])], x=x, y=y, rot=r)
    nub = lambda name, x, y, r: Node(name, [Shape("Antler", 0, -8, Rect(8, 18, 4), [Fill("FFE4D2B0")])], x=x, y=y, rot=r)
    spots = [Shape(f"Spot {i}", x, y, Ellipse(7, 6), [Fill("CCF7EBD8")]) for i, (x, y) in enumerate(((-70, -170), (-76, -140), (-60, -120), (74, -178)))]
    return Animal(name="Deer", top=tan, bottom=dark, belly=white,
                  muzzle=dict(x=88, y=-266, size=(40, 30), color=white),
                  nose=(101, -279, 12, 9, "FF2A1A10", 0.25), mouth=W_MOUTH,
                  over_hood=[nub("Antler Near", 22, -352, 0.2), nub("Antler Far", -10, -356, -0.2),
                             leaf_ear("Ear Near", 52, -340, 1.1, tan), leaf_ear("Ear Far", -40, -340, -1.1, dark)],
                  body_extra=spots, paw="FF3A2616", legs=dark)


def tiger():
    orange, dark, white, black = "FFF28A2C", "FFC96418", "FFF8F1E6", "FF2A1C14"
    return Animal(name="Tiger", top=orange, bottom=dark, belly=white,
                  muzzle=dict(x=86, y=-266, size=(46, 34), color=white),
                  nose=(100, -279, 12, 9, "FFE88C9A", 0.25), mouth=W_MOUTH, mouth_color=black,
                  face_top=whiskers(),
                  face_under=[stripe("Stripe 1", [(46, -334), (52, -318)], black, 5), stripe("Stripe 2", [(60, -334), (62, -320)], black, 5),
                              stripe("Cheek Stripe", [(96, -300), (82, -294)], black, 4)],
                  over_hood=[round_ear("Ear Near", 40, -350, 0.3, 26, 24, orange, white),
                             round_ear("Ear Far", -18, -354, -0.3, 24, 22, dark, white)],
                  body_extra=[stripe(f"Body Stripe {i}", pts, black, 5) for i, pts in enumerate((
                      [(-80, -160), (-60, -150)], [(-84, -120), (-62, -114)], [(84, -164), (66, -156)], [(86, -124), (68, -118)]))],
                  paw=white, back=[tail_thin(orange, 13, stripes=black, tip=black)])


def koala():
    grey, dark, fluff = "FF9FA6B0", "FF737B87", "FFEEF0F2"
    ear = lambda name, x, y, r, col: Node(name, [Shape("Fluff", 3, 2, Ellipse(26, 24), [Fill(fluff)]),
                                                 Shape("Ear", 0, 0, Ellipse(44, 40), [Fill(col)])], x=x, y=y, rot=r)
    return Animal(name="Koala", top=grey, bottom=dark, belly="FFDCE0E5",
                  nose=(100, -278, 18, 24, "FF34373E", 0.1), mouth=[(80, -250, 0, 0, 4, 3), (92, -252, 0, 0, 0, 0)],
                  face_under=[Shape("Chin", 84, -248, Ellipse(30, 14), [Fill(fluff)])],
                  over_hood=[ear("Ear Near", 52, -340, 0.3, grey), ear("Ear Far", -40, -344, -0.3, dark)],
                  paw="FF4E545D", legs=dark)


def duck():
    white, grey, bill = "FFF7F4EC", "FFD9D4C8", "FFF2A23A"
    return Animal(name="Duck", top=white, bottom=grey, belly="FFFFFFFF", head_pts=HEAD_BIRD,
                  eyes=dict(at=(60, -298), eyes=[(8, 0, 1.0), (-18, -2, 0.82)], size=(11, 13)),
                  face_top=[Shape("Bill Line", 0, 0, Path([(86, -270), (120, -270)], closed=False), [Stroke("FFC77A20", 2)]),
                            Shape("Bill", 0, 0, Path([(84, -282, 0, 0, 20, -6), (124, -276, -6, -6, 4, 8), (118, -260, 6, 0, -20, 2), (84, -262, 0, 0, 0, 0)]),
                                  [Fill(bill)])],
                  face_under=[Shape("Blush", 76, -278, Ellipse(14, 8), [Fill("55F7A1B8")])],
                  wings=(white, grey, "44C9C2B4"), legs=bill)


def mouse():
    tan, dark, pink = "FFB8AA9C", "FF8E8074", "FFF2B4BF"
    return Animal(name="Mouse", top=tan, bottom=dark, belly="FFE8DFD4", head_pts=HEAD_SNOUT,
                  nose=(110, -273, 10, 8, "FFF08CA4", 0.3), mouth=[(92, -254, 0, 0, 4, 3), (102, -258, 0, 0, 0, 0)],
                  face_top=whiskers("AAFFFFFF", (104, -270)),
                  over_hood=[round_ear("Ear Near", 48, -346, 0.3, 42, 40, tan, pink),
                             round_ear("Ear Far", -34, -350, -0.3, 40, 38, dark, pink)],
                  paw=pink, legs=dark, back=[tail_thin(pink, 5)], tail_swing=0.12)


def dragon():
    green, dark, belly, gold = "FF3FAE86", "FF257A5C", "FFF2E3B0", "FFE8C35A"
    horn = lambda name, x, y, r: Node(name, [Shape("Horn", 0, 0, Path([(-7, 4, 0, 0, -2, -10), (4, -30, -8, 4, 0, 0), (8, 4, 2, -14, 0, 0)]), [Fill(gold)])], x=x, y=y, rot=r)
    fin = lambda name, x, y, r: Node(name, [Shape("Fin", 0, 0, Path([(-10, 6), (0, -22), (10, 6), (0, 0)]), [Fill("FF7FD9B6")])], x=x, y=y, rot=r)
    scales = [Shape(f"Belly Scale {i}", 30, -170 + 22 * i, Rect(64 - 6 * abs(i - 2), 3, 1.5), [Fill("99D8C08A")]) for i in range(5)]
    return Animal(name="BabyDragon", top=green, bottom=dark, belly=belly, head_pts=HEAD_SNOUT,
                  eyes=dict(at=(62, -300), eyes=[(4, 0, 1.05), (-24, -2, 0.82)], size=(13, 15)),
                  face_top=[Shape("Nostril", 100, -290, Ellipse(7, 5), [Fill("FF1F5A45")], rot=0.5),
                            Shape("Fang", 90, -246, Path([(-3, 0), (0, 6), (3, 0)]), [Fill("FFFFFFFF")])],
                  mouth=[(70, -250, 0, 0, 10, 4), (100, -254, 0, 0, 0, 0)], mouth_color="FF1F5A45",
                  over_hood=[horn("Horn Near", 30, -352, 0.35), horn("Horn Far", -10, -358, -0.3),
                             fin("Fin Near", 60, -330, 1.0)],
                  body_extra=scales, paw="FF1F5A45", legs=dark,
                  back=[tail_dragon(green, dark, gold)] + dragon_wings("CC2E8F6C", "FF1F5A45"), wing_flap=True)


ROSTER = [cat(), bunny(), frog(), red_panda(), penguin(), raccoon(), wolf(), bear(), otter(), panda(),
          hedgehog(), deer(), tiger(), koala(), duck(), mouse(), dragon()]
