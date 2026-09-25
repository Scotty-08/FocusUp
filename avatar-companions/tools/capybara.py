"""FocusUp capybara companion -- art + rig description.

Generates scene.rml (Rive) and an SVG preview from one description, so the art
can be iterated without a Rive install. The Rive CLI's own --verify and
--screenshot remain the source of truth.

Rig layout
  Character (at the feet)      idle breathing squash keeps the boots planted
    Head (pivot at the neck)   idle nod + wave tilt
      Head Art                 face, ear, eye slot, hood shell slot, hood lining slot
    Arm Near (pivot shoulder)  the waving arm
    Arm Far
    Cloak Front slot           drapes + brooch
    Body
    Boots slot
    Cloak Back slot            the long cape behind everything

Cosmetic slots are Solos. The cloak is split across four Solos (hood shell,
hood lining, front drapes, back cape) because those pieces sit at different
depths around the head and body; the app switches all four together.
"""
import math
import sys
from rivegen import (Shape, Node, Ellipse, Rect, Path, Fill, Stroke, LinGrad, RadGrad,
                     rid, to_svg, fmt)

W, H = 400, 460
FEET_X, FEET_Y = 200, 424
NECK = (20, -228)

# ------------------------------------------------------------------ palettes
FUR = dict(base_top="FFA87248", base_bot="FF74482A", dark="FF5C3923", belly="FFC0935F",
           paw="FF4A2E1C", ear="FF6B4329", ear_in="FF3E2616", nose="FF2A1A10", mouth="FF3A2416")

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
DEFAULTS = dict(cloak="Forest", eyes="Amber", boots="Brown")

# ------------------------------------------------------------------ head
HEAD_PTS = [
    (-4, -348, -38, 0, 40, 0),         # crown
    (64, -328, -24, -9, 14, 6),        # forehead sloping into snout
    (100, -300, -8, -10, 5, 8),        # nose bridge front
    (108, -262, 2, -14, -2, 13),       # blunt snout front
    (88, -234, 10, -8, -16, 7),        # chin
    (28, -222, 24, -2, -26, 1),        # jaw
    (-36, -236, 24, 5, -18, -7),       # cheek back
    (-60, -284, 3, 21, -2, -26),       # back of skull
    (-40, -332, -12, 12, 14, -9),
]
HOOD_SHELL = [
    (-50, -366, 0, 0, 24, -4),                 # soft hood peak, tipped back
    (30, -358, -30, -4, 20, 6),
    (78, -326, -8, -14, -4, 6),                # brim over the forehead
    (42, -314, 14, -4, -14, 5),
    (12, -280, 6, -14, -3, 17),                # opening edge behind the eye
    (6, -236, 0, -16, 3, 10),
    (24, -214),
    (-46, -208, 26, 0, -24, -10),
    (-88, -292, 0, 38, 2, -40),                # rounded back of the hood
]
HOOD_TRIM = [(78, -326, 0, 0, -12, 4), (42, -314, 14, -4, -14, 5), (12, -280, 6, -14, -3, 17),
             (6, -236, 0, -16, 0, 0)]
HOOD_FOLD = [(-58, -346, 0, 0, -10, 24), (-64, -262, 0, 0, 0, 0), (-50, -270, 0, 0, 0, 0), (-44, -340, -6, 22, 0, 0)]
HOOD_SHADOW = [(66, -318, 0, 0, -12, 3), (32, -304, 12, -4, -12, 6), (8, -276, 5, -12, -2, 14), (4, -244, 0, -12, 0, 0)]
HOOD_LINING = [(-44, -358, -18, 0, 30, -4), (64, -336, -24, -8, 18, 12), (92, -300, 0, -14, 0, 14),
               (74, -222, 14, 4, -40, 6), (-40, -218, 30, 4, -14, -12), (-66, -290, 0, 26, 2, -30)]


def eye_variant(name, c):
    return Node(f"Eyes {name}", [
        Shape("Sparkle", -3, -4, Ellipse(4, 4), [Fill("FFFFFFFF")]),
        Shape("Core", 0, 0, Ellipse(7, 9), [Fill(c["core"])]),
        Shape("Iris", 0, 0, Ellipse(14, 17), [Fill(c["iris"])]),
        Shape("Glow", 0, 0, Ellipse(15, 18), [Stroke(c["glow"], 7, feather=8)]),
    ], key=f"eyes_{name}")


def hood_shell(name, c):
    return Node(f"Hood {name}", [
        Shape("Hood Trim", 0, 0, Path(HOOD_TRIM, closed=False), [Stroke(c["trim"], 3)]),
        Shape("Hood Shadow", 6, 2, Path(HOOD_SHADOW, closed=False), [Stroke("AA140A05", 14, feather=12)]),
        Shape("Hood Shell", 0, 0, Path(HOOD_SHELL),
              [Fill(LinGrad(30, -366, -70, -226, [(0, c["hi"]), (0.35, c["main"]), (1, c["shade"])]))]),
    ], key=f"hood_{name}")


def hood_lining(name, c):
    return Node(f"Hood Lining {name}", [
        Shape("Hood Lining", 0, 0, Path(HOOD_LINING), [Fill(c["lining"])]),
    ], key=f"lining_{name}")


def head():
    art = [
        Node("Eyes", [Node("Eye Color", [eye_variant(n, c) for n, c in EYES.items()],
                           key="eye_solo", solo_active=f"eyes_{DEFAULTS['eyes']}")],
             x=62, y=-298, key="eyes"),
        Shape("Nostril", 97, -285, Ellipse(10, 6), [Fill(FUR["nose"])], rot=0.55),
        Shape("Mouth", 0, 0, Path([(66, -248, 0, 0, 6, 4), (82, -243, -7, 1, 6, -1), (94, -251, -4, 4, 0, 0)],
                                  closed=False), [Stroke(FUR["mouth"], 2.6)]),
        Node("Ear", [
            Shape("Ear Inner", 1, 1, Ellipse(12, 10), [Fill(FUR["ear_in"])]),
            Shape("Ear Outer", 0, 0, Ellipse(26, 22), [Fill(FUR["ear"])]),
        ], x=-14, y=-356, rot=-0.35),
        Node("Hood", [hood_shell(n, c) for n, c in CLOAKS.items()],
             key="hood_solo", solo_active=f"hood_{DEFAULTS['cloak']}"),
        Shape("Snout Highlight", 66, -314, Ellipse(62, 18), rot=0.38,
              paints=[Fill(RadGrad(0, 0, 31, 0, [(0, "99E0AE82"), (1, "00E0AE82")]))]),
        Shape("Jaw Shade", 30, -230, Ellipse(110, 22),
              paints=[Fill(RadGrad(0, 0, 55, 0, [(0, "55402614"), (1, "00402614")]))]),
        Shape("Head", 0, 0, Path(HEAD_PTS), key="head",
              paints=[Fill(LinGrad(0, -348, 0, -222, [(0, FUR["base_top"]), (1, FUR["base_bot"])]))]),
        Node("Hood Lining", [hood_lining(n, c) for n, c in CLOAKS.items()],
             key="lining_solo", solo_active=f"lining_{DEFAULTS['cloak']}"),
    ]
    return Node("Head", [Node("Head Art", art, x=-NECK[0], y=-NECK[1])],
                x=NECK[0], y=NECK[1], sx=1.12, sy=1.12, key="head_node")


# ------------------------------------------------------------------ cloak body
BACK_CAPE = [
    (-30, -236, 0, 0, -30, 6),
    (-100, -200, 18, -16, -22, 24),            # far shoulder
    (-146, -120, 10, -30, -8, 26),
    (-172, -66, 4, -12, 12, 6),                # far hem tip
    (-130, -76, -14, 2, 12, 10),               # hem waves
    (-94, -58, -12, 2, 12, -4),
    (-58, -72, -10, -6, 10, 8),
    (0, -52),
    (70, -62),
    (114, -56, -12, 4, 10, -2),
    (150, -74, -8, 10, -4, -24),               # near hem tip
    (124, -150, 8, 26, -6, -24),
    (80, -210, 20, 18, -18, -14),              # near shoulder
    (20, -234, 24, 0, -20, 0),
]
CAPE_FOLDS = [
    [(-122, -150, 0, 0, -4, 26), (-134, -92, 0, 0, 0, 0), (-110, -96, 0, 0, 0, 0), (-108, -150, -4, 30, 0, 0)],
    [(-82, -170, 0, 0, -2, 30), (-86, -80, 0, 0, 0, 0), (-72, -84, 0, 0, 0, 0), (-70, -160, 0, 24, 0, 0)],
    [(120, -140, 0, 0, 6, 26), (134, -72, 0, 0, 0, 0), (124, -64, 0, 0, 0, 0), (114, -130, 4, 26, 0, 0)],
]
DRAPE_NEAR = [
    (22, -216, 0, 0, 24, 0),
    (88, -206, -18, -8, 18, 12),               # over the near shoulder
    (120, -150, -4, -24, 4, 26),
    (134, -86, -4, -20, 0, 0),                 # hem point
    (100, -92, 10, 2, -8, -18),
    (76, -150, 6, 22, -6, -22),
    (38, -200, 12, 10, 0, 0),
]
DRAPE_FAR = [
    (8, -218, 0, 0, -26, 0),
    (-80, -210, 22, -6, -20, 12),
    (-118, -150, 6, -24, -4, 26),
    (-136, -86, 4, -20, 0, 0),
    (-98, -92, -10, 2, 8, -18),
    (-72, -150, -6, 22, 6, -22),
    (-20, -200, -12, 10, 0, 0),
]
NEAR_EDGE = [(38, -200, 0, 0, 12, 10), (76, -150, -6, -22, 6, 22), (100, -92, -8, -18, 0, 0)]
FAR_EDGE = [(-20, -200, 0, 0, -12, 10), (-72, -150, 6, -22, -6, 22), (-98, -92, 8, -18, 0, 0)]


def brooch(c):
    return Node("Brooch", [
        Shape("Gem Shine", -2, -3, Ellipse(4, 4), [Fill("EEFFFFFF")]),
        Shape("Gem", 0, 0, Rect(11, 11, 1.5), [Fill(c["gem"])], rot=math.pi / 4),
        Shape("Gem Setting", 0, 0, Rect(18, 18, 2.5), [Fill("FFD9A93A")], rot=math.pi / 4),
        Shape("Gem Glow", 0, 0, Ellipse(18, 18), [Stroke(c["gemglow"], 6, feather=9)]),
    ], x=18, y=-194)


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


# ------------------------------------------------------------------ body
BODY = [
    (-14, -244, 0, 0, 30, -2),
    (54, -234, -20, -2, 16, 12),
    (84, -178, -6, -24, 6, 30),                # chest
    (88, -110, 4, -26, -6, 28),                # belly front
    (48, -60, 22, -8, -18, 4),
    (-4, -52, 18, 0, -26, 0),
    (-62, -66, 20, 6, -14, -14),
    (-86, -130, 2, 30, 0, -34),
    (-62, -202, -12, 26, 12, -22),
]
BELLY = [(34, -184, 0, 0, 22, 10), (72, -124, 0, -26, 0, 26), (40, -66, 18, -4, -18, 2),
         (6, -72, 10, 6, -6, -30), (16, -154, -6, 18, 6, -16)]

ARM = [(-15, -4, 0, -10, 0, 0), (15, -4, 0, 0, 0, 8), (17, 38, 0, -14, 0, 10), (0, 62, 12, 0, -12, 0),
       (-17, 38, 0, 10, 0, -14)]


def arm(name, x, y, rot, key=None, near=True):
    fur = FUR["base_top"] if near else FUR["base_bot"]
    return Node(name, [
        Shape("Paw", 0, 56, Ellipse(32, 24), [Fill(FUR["paw"])]),
        Shape("Arm", 0, 0, Path(ARM), [Fill(LinGrad(0, 0, 0, 62, [(0, fur), (1, FUR["dark"])]))]),
    ], x=x, y=y, rot=rot, key=key)


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
    return Node(f"Boots {name}", [boot("Boot Near", 36, c), boot("Boot Far", -44, c, 0.93)],
                key=f"boots_{name}")


REST_ARM_NEAR, REST_ARM_FAR = -0.22, 0.25


def character(arm_rot=REST_ARM_NEAR, head_rot=0.0):
    ch = Node("Character", [
        arm("Arm Near", 70, -196, arm_rot, key="arm_near", near=True),
        head(),
        arm("Arm Far", -62, -194, REST_ARM_FAR, near=False),
        Node("Cloak Front", [cloak_front(n, c) for n, c in CLOAKS.items()],
             key="cloakF_solo", solo_active=f"cloakF_{DEFAULTS['cloak']}"),
        Shape("Belly", 0, 0, Path(BELLY),
              paints=[Fill(RadGrad(46, -116, 46, -44, [(0, FUR["belly"]), (1, "00C0935F")]))]),
        Shape("Body", 0, 0, Path(BODY),
              paints=[Fill(LinGrad(-80, -150, 90, -120, [(0, FUR["dark"]), (1, FUR["base_top"])]))]),
        Node("Boots", [boots_variant(n, c) for n, c in BOOTS.items()],
             key="boots_solo", solo_active=f"boots_{DEFAULTS['boots']}"),
        Node("Cloak Back", [cloak_back(n, c) for n, c in CLOAKS.items()],
             key="cloakB_solo", solo_active=f"cloakB_{DEFAULTS['cloak']}"),
    ], x=FEET_X, y=FEET_Y, key="character")
    ch.children[1].rot = head_rot
    return ch


def ground():
    return Shape("Ground Glow", FEET_X, FEET_Y + 2, Ellipse(250, 34),
                 [Fill(RadGrad(0, 0, 125, 0, [(0, "7734C3E6"), (0.5, "3322556E"), (1, "0022556E")]))])


# ------------------------------------------------------------------ animation
def kf(v, f, interp="linear", ease=None):
    if ease:
        return (f'                    <KeyFrameDouble value="{fmt(float(v))}" frame="{f}" interpolationType="cubic">\n'
                f'                        <CubicEaseInterpolator x1="{ease[0]}" y1="{ease[1]}" x2="{ease[2]}" y2="{ease[3]}"/>\n'
                f'                    </KeyFrameDouble>\n')
    return f'                    <KeyFrameDouble value="{fmt(float(v))}" frame="{f}" interpolationType="{interp}"/>\n'


def keyed(obj, prop, frames):
    keys = "".join(kf(v, f, ease=e) if e else kf(v, f) for v, f, e in frames)
    return (f'            <KeyedObject objectId="{rid(obj)}">\n'
            f'                <KeyedProperty propertyKey="{prop}">\n{keys}                </KeyedProperty>\n'
            f'            </KeyedObject>\n')


IN_OUT = (0.42, 0, 0.58, 1)
OUT = (0.1, 0.6, 0.3, 1)
X, Y, ROT, SX, SY = 13, 14, 15, 16, 17
WAVE = [(REST_ARM_NEAR, 0, OUT), (-1.85, 14, IN_OUT), (-2.15, 23, IN_OUT), (-1.6, 32, IN_OUT),
        (-2.15, 41, IN_OUT), (-1.6, 50, IN_OUT), (-1.85, 58, IN_OUT), (REST_ARM_NEAR, 80, None)]


def animations():
    idle = (keyed("character", SX, [(1, 0, IN_OUT), (0.992, 100, None)])
            + keyed("character", SY, [(1, 0, IN_OUT), (1.022, 100, None)])
            + keyed("head_node", ROT, [(0, 0, IN_OUT), (0.03, 100, None)])
            + keyed("arm_near", ROT, [(REST_ARM_NEAR, 0, IN_OUT), (REST_ARM_NEAR - 0.05, 100, None)]))
    wave = (keyed("arm_near", ROT, WAVE)
            + keyed("head_node", ROT, [(0, 0, IN_OUT), (-0.07, 16, IN_OUT), (-0.07, 60, IN_OUT), (0, 80, None)])
            + keyed("character", SX, [(1, 0, None), (1, 80, None)])
            + keyed("character", SY, [(1, 0, None), (1, 80, None)]))
    blink = keyed("eyes", SY, [(1, 0, None), (1, 196, None), (0.1, 201, None), (1, 210, None)])
    blink = blink.replace('frame="0" interpolationType="linear"', 'frame="0" interpolationType="hold"', 1)
    return (f'        <LinearAnimation loopValue="pingPong" fps="60" duration="100" name="Idle" id="{rid("anim_idle")}">\n{idle}        </LinearAnimation>\n'
            f'        <LinearAnimation loopValue="oneShot" fps="60" duration="80" name="Wave" id="{rid("anim_wave")}">\n{wave}        </LinearAnimation>\n'
            f'        <LinearAnimation loopValue="loop" fps="60" duration="210" name="Blink" id="{rid("anim_blink")}">\n{blink}        </LinearAnimation>\n')


SLOT_SOLOS = {
    "cloak": (CLOAKS, ["hood", "lining", "cloakF", "cloakB"]),
    "eyes": (EYES, ["eyes"]),
    "boots": (BOOTS, ["boots"]),
}


def slot_animations():
    """One-frame holds that point each slot's Solo(s) at a variant."""
    out = ""
    for slot, (variants, prefixes) in SLOT_SOLOS.items():
        for name in variants:
            keyed_objs = ""
            for p in prefixes:
                keyed_objs += (f'            <KeyedObject objectId="{rid(p + "_solo" if p != "eyes" else "eye_solo")}">\n'
                               f'                <KeyedProperty propertyKey="296">\n'
                               f'                    <KeyFrameId value="{rid(f"{p}_{name}")}" frame="0" interpolationType="hold"/>\n'
                               f'                </KeyedProperty>\n'
                               f'            </KeyedObject>\n')
            out += (f'        <LinearAnimation loopValue="oneShot" fps="60" duration="1" name="{slot.title()} {name}" '
                    f'id="{rid(f"anim_{slot}_{name}")}">\n{keyed_objs}        </LinearAnimation>\n')
    return out


def still_animations():
    return (f'        <LinearAnimation loopValue="oneShot" fps="60" duration="1" name="Still" id="{rid("anim_still")}">\n'
            + keyed("character", SX, [(1, 0, None)]) + keyed("character", SY, [(1, 0, None)])
            + keyed("head_node", ROT, [(0, 0, None)]) + keyed("arm_near", ROT, [(REST_ARM_NEAR, 0, None)])
            + '        </LinearAnimation>\n'
            + f'        <LinearAnimation loopValue="oneShot" fps="60" duration="1" name="Eyes Open" id="{rid("anim_eyes_open")}">\n'
            + keyed("eyes", SY, [(1, 0, None)])
            + '        </LinearAnimation>\n')


def slot_layer(slot, variants, y):
    names = list(variants)
    states = ""
    for i, name in enumerate(names):
        trans = ""
        for j, other in enumerate(names):
            if j == i:
                continue
            trans += (f'                    <StateTransition stateToId="{rid(f"st_{slot}_{other}")}" duration="0">\n'
                      f'                        <TransitionNumberCondition inputId="{rid(f"in_{slot}")}" opValue="equal" value="{j}"/>\n'
                      f'                    </StateTransition>\n')
        states += (f'                <AnimationState animationId="{rid(f"anim_{slot}_{name}")}" x="{160 + 130 * i}" y="{y}" '
                   f'id="{rid(f"st_{slot}_{name}")}">\n{trans}                </AnimationState>\n')
    return (f'            <StateMachineLayer name="{slot.title()}" id="{rid(f"layer_{slot}")}">\n'
            f'                <AnyState x="{160 + 130 * len(names)}" y="{y}"/>\n'
            f'                <ExitState x="{290 + 130 * len(names)}" y="{y}"/>\n'
            f'                <EntryState x="0" y="{y}">\n'
            f'                    <StateTransition stateToId="{rid(f"st_{slot}_{names[0]}")}"/>\n'
            f'                </EntryState>\n{states}            </StateMachineLayer>\n')


def calm(value):
    op = "equal" if value else "notEqual"
    return f'<TransitionBoolCondition inputId="{rid("in_calm")}" opValue="{op}"/>'


def state_machine():
    slot_layers = "".join(slot_layer(s, v, 400 + 200 * k) for k, (s, (v, _)) in enumerate(SLOT_SOLOS.items()))
    return f'''        <StateMachine name="State Machine 1" id="{rid('sm')}">
            <StateMachineTrigger name="wave" id="{rid('trig_wave')}"/>
            <StateMachineBool name="calm" id="{rid('in_calm')}"/>
            <StateMachineNumber name="cloak" id="{rid('in_cloak')}"/>
            <StateMachineNumber name="eyes" id="{rid('in_eyes')}"/>
            <StateMachineNumber name="boots" id="{rid('in_boots')}"/>

            <StateMachineListenerSingle targetId="{rid('head')}" listenerTypeValue="click" name="Tap To Wave" id="{rid('listener_tap')}">
                <ListenerTriggerChange inputId="{rid('trig_wave')}"/>
            </StateMachineListenerSingle>

            <StateMachineLayer name="Body" id="{rid('layer_body')}">
                <AnyState x="640" y="0"/>
                <ExitState x="760" y="0"/>
                <EntryState x="0" y="0">
                    <StateTransition stateToId="{rid('st_idle')}"/>
                </EntryState>
                <AnimationState animationId="{rid('anim_idle')}" x="160" y="0" id="{rid('st_idle')}">
                    <StateTransition stateToId="{rid('st_still')}" duration="200">
                        {calm(True)}
                    </StateTransition>
                    <StateTransition stateToId="{rid('st_wave')}" duration="120">
                        <TransitionTriggerCondition inputId="{rid('trig_wave')}"/>
                    </StateTransition>
                </AnimationState>
                <AnimationState animationId="{rid('anim_wave')}" x="320" y="0" reset="true" id="{rid('st_wave')}">
                    <StateTransition stateToId="{rid('st_idle')}" duration="150"
                                     enableExitTime="true" exitTimeIsPercetange="true" exitTime="100"/>
                </AnimationState>
                <AnimationState animationId="{rid('anim_still')}" x="480" y="0" id="{rid('st_still')}">
                    <StateTransition stateToId="{rid('st_idle')}" duration="200">
                        {calm(False)}
                    </StateTransition>
                </AnimationState>
            </StateMachineLayer>

            <StateMachineLayer name="Blink" id="{rid('layer_blink')}">
                <AnyState x="480" y="200"/>
                <ExitState x="600" y="200"/>
                <EntryState x="0" y="200">
                    <StateTransition stateToId="{rid('st_blink')}"/>
                </EntryState>
                <AnimationState animationId="{rid('anim_blink')}" x="160" y="200" id="{rid('st_blink')}">
                    <StateTransition stateToId="{rid('st_eyes_open')}" duration="0">
                        {calm(True)}
                    </StateTransition>
                </AnimationState>
                <AnimationState animationId="{rid('anim_eyes_open')}" x="320" y="200" id="{rid('st_eyes_open')}">
                    <StateTransition stateToId="{rid('st_blink')}" duration="0">
                        {calm(False)}
                    </StateTransition>
                </AnimationState>
            </StateMachineLayer>

{slot_layers}        </StateMachine>
'''


def build(**pose):
    char, gnd = character(**pose), ground()
    scene = char.rml("        ") + gnd.rml("        ")
    rml = (f'<Rive version="1" kind="fragment">\n'
           f'    <Artboard defaultStateMachineId="{rid("sm")}" width="{W}" height="{H}" name="Capybara" id="0:2">\n'
           f"{scene}\n{state_machine()}\n{animations()}{still_animations()}{slot_animations()}"
           f"    </Artboard>\n</Rive>\n")
    return rml, to_svg([char, gnd], W, H)


if __name__ == "__main__":
    # usage: capybara.py [out_prefix] [cloak eyes boots] [wave]
    prefix = sys.argv[1] if len(sys.argv) > 1 else "preview"
    if len(sys.argv) >= 5:
        DEFAULTS.update(cloak=sys.argv[2], eyes=sys.argv[3], boots=sys.argv[4])
    pose = {}
    if "wave" in sys.argv:
        pose = dict(arm_rot=-2.15, head_rot=-0.07)
    rml, svg = build(**pose)
    if prefix == "preview" and not pose:
        open("scene.rml", "w").write(rml)
    open(f"{prefix}.svg", "w").write(svg)
    print("ok", len(rml.splitlines()), "lines")
