"""Wave 1 companions: the two human starters, capybara, fox, axolotl, owl."""
import math
from rivegen import Shape, Node, Ellipse, Rect, Path, Fill, Stroke, LinGrad, RadGrad, Solid
import kit
from kit import tone

ROT, SX, SY = 15, 16, 17
E = (0.42, 0, 0.58, 1)


def grad_v(top, bottom, y0, y1, x=0):
    return LinGrad(x, y0, x, y1, [(0, top), (1, bottom)])


def pointed_ear(name, x, y, rot, h, w, outer, inner, tip=None):
    """Tall pointed ear drawn over the hood (fox, cat, wolf...)."""
    outer_pts = [(-w, 4, 0, 0, 0, -h * 0.35), (0, -h, -w * 0.3, h * 0.3, w * 0.3, h * 0.3), (w, 4, 0, -h * 0.35, 0, 0)]
    inner_pts = [(-w * 0.55, 0, 0, 0, 0, -h * 0.3), (0, -h * 0.72, -w * 0.2, h * 0.2, w * 0.2, h * 0.2), (w * 0.55, 0, 0, -h * 0.3, 0, 0)]
    parts = []
    if tip:
        parts.append(Shape("Ear Tip", 0, -h * 0.82, Path([(-w * 0.34, 0), (0, -h * 0.2), (w * 0.34, 0)]), [Fill(tip)]))
    parts += [Shape("Ear Inner", 0, 0, Path(inner_pts), [Fill(inner)]),
              Shape("Ear Outer", 0, 0, Path(outer_pts), [Fill(outer)])]
    return Node(name, parts, x=x, y=y, rot=rot)


def round_ear(name, x, y, rot, w, h, outer, inner):
    return Node(name, [Shape("Ear Inner", 1, 1, Ellipse(w * 0.46, h * 0.45), [Fill(inner)]),
                       Shape("Ear Outer", 0, 0, Ellipse(w, h), [Fill(outer)])], x=x, y=y, rot=rot)


# body silhouettes (feet at 0,0)
ROUND_BODY = [(-14, -244, 0, 0, 30, -2), (54, -234, -20, -2, 16, 12), (84, -178, -6, -24, 6, 30),
              (88, -110, 4, -26, -6, 28), (48, -60, 22, -8, -18, 4), (-4, -52, 18, 0, -26, 0),
              (-62, -66, 20, 6, -14, -14), (-86, -130, 2, 30, 0, -34), (-62, -202, -12, 26, 12, -22)]
ROUND_BELLY = [(34, -184, 0, 0, 22, 10), (72, -124, 0, -26, 0, 26), (40, -66, 18, -4, -18, 2),
               (6, -72, 10, 6, -6, -30), (16, -154, -6, 18, 6, -16)]
SLIM_BODY = [(-12, -244, 0, 0, 28, -2), (44, -236, -18, -2, 14, 10), (64, -196, -4, -18, 2, 20),
             (64, -132, 0, -20, 4, 20), (72, -80, -2, -14, 0, 0), (-74, -80), (-66, -132, -4, 20, 0, -20),
             (-60, -196, -2, 20, 6, -18)]


class Species:
    ARTBOARD = "?"

    def front(self):
        return []

    def legs(self):
        return []

    def back(self):
        return []

    def idle_tracks(self):
        return []

    def paw_style(self, fur, dark, paw):
        return dict(kind="paw",
                    fur_near=LinGrad(0, 0, 0, 62, [(0, fur), (1, dark)]),
                    fur_far=LinGrad(0, 0, 0, 62, [(0, dark), (1, dark)]),
                    hand=paw)


# ============================================================ HUMANS
HUMAN_HEAD_M = [(6, -344, -36, 0, 32, 0), (56, -330, -18, -8, 10, 8), (74, -300, -4, -12, 2, 8),
                (84, -282, 0, -6, -2, 5), (74, -272, 4, -2, 0, 4), (77, -258, 0, -6, 0, 7),
                (68, -236, 6, -9, -12, 5), (30, -226, 16, -2, -20, 2), (-30, -240, 22, 8, -14, -10),
                (-54, -290, 2, 22, -2, -26), (-36, -332, -10, 12, 14, -8)]
HUMAN_HEAD_F = [(6, -342, -36, 0, 32, 0), (56, -328, -18, -8, 10, 8), (72, -300, -4, -12, 2, 8),
                (81, -284, 0, -6, -2, 5), (72, -274, 4, -2, 0, 4), (74, -260, 0, -6, -2, 8),
                (60, -240, 8, -8, -12, 4), (28, -230, 16, -2, -20, 2), (-30, -242, 22, 8, -14, -10),
                (-54, -290, 2, 22, -2, -26), (-36, -330, -10, 12, 14, -8)]
TUNIC = dict(top="FF3F8C99", bottom="FF255761", trim="FF1B4048")


class Human(Species):
    FEMALE = False

    @property
    def ARTBOARD(self):
        return "HumanFemale" if self.FEMALE else "HumanMale"

    def head(self):
        pts = HUMAN_HEAD_F if self.FEMALE else HUMAN_HEAD_M
        hair = tone("hair", kit.HAIRS)
        if self.FEMALE:
            fringe = [(8, -330, 0, 0, 24, -8), (78, -322, -16, -6, 4, 10), (76, -300, 2, -8, -12, -6),
                      (48, -310, 12, 0, -12, 6), (26, -292, 8, -8, -2, 12), (12, -262, 2, -10, 0, 0)]
            lock = [(4, -290, 0, 0, 14, 18), (30, -214, -8, -26, 8, 24), (48, -160, -2, -10, -6, 2),
                    (26, -176, 8, 8, -6, -22), (-6, -250, 2, 22, 0, 0)]
            lock_shine = [(12, -276, 0, 0, 8, 16), (30, -210, -4, -18, 0, 0)]
            hair_bits = [Shape("Hair Shine", 0, 0, Path(lock_shine, closed=False), [Stroke("44FFFFFF", 3)]),
                         Shape("Hair Lock", 0, 0, Path(lock), [Fill(tone("hair", kit.HAIRS))]),
                         Shape("Fringe", 0, 0, Path(fringe), [Fill(hair)])]
            brows = Path([(42, -310, 0, 0, 8, -3), (64, -310, 0, 0, 0, 0)], closed=False)
            mouth_col = "FFC2566A"
        else:
            fringe = [(8, -330, 0, 0, 24, -10), (80, -324, -16, -6, 0, 0), (72, -306), (62, -316),
                      (52, -300), (42, -314), (30, -296), (22, -310), (10, -290)]
            hair_bits = [Shape("Fringe", 0, 0, Path(fringe), [Fill(hair)])]
            brows = Path([(40, -310, 0, 0, 10, -2), (66, -310, 0, 0, 0, 0)], closed=False)
            mouth_col = "FF7A3E32"
        return dict(
            eyes=dict(at=(50, -292), eyes=[(14, 0, 1.0), (-12, -1, 0.82)], size=(12, 14)),
            face_top=([
                Shape("Lash Near", 0, 0, Path([(66, -301, 0, 0, 3, -2), (72, -305, 0, 0, 0, 0)], closed=False), [Stroke("FF1E1B1E", 2)]),
                Shape("Lash Far", 0, 0, Path([(40, -302, 0, 0, -2, -2), (35, -305, 0, 0, 0, 0)], closed=False), [Stroke("FF1E1B1E", 1.8)]),
            ] if self.FEMALE else []) + [
                Shape("Mouth", 0, 0, Path([(54, -250, 0, 0, 6, 4), (70, -250, -6, 4, 0, 0)], closed=False),
                      [Stroke(mouth_col, 3.0 if self.FEMALE else 2.6)]),
                Shape("Nose Shade", 0, 0, Path([(78, -286, 0, 0, 2, 6), (74, -274, 0, 0, 0, 0)], closed=False),
                      [Stroke("55402010", 2.2)]),
                Shape("Brows", 0, 0, brows, [Stroke(tone("hair", kit.HAIRS), 3.2 if not self.FEMALE else 2.4)]),
            ],
            face_under=hair_bits + [
                Shape("Cheek Blush", 62, -262, Ellipse(18, 9), [Fill("44E0707A" if self.FEMALE else "22E0707A")]),
                Shape("Hood Shade On Face", 0, 0, Path(pts),
                      [Fill(LinGrad(0, -344, 0, -284, [(0, "BB161018"), (0.5, "44161018"), (1, "00161018")]))]),
            ],
            head=[Shape("Head", 0, 0, Path(pts), [Fill(tone("skin", kit.SKINS))], key="head")],
        )

    def body(self):
        return [
            Shape("Buckle", 26, -122, Rect(14, 14, 2), [Fill("FFD9A93A")], rot=math.pi / 4),
            Shape("Belt", 0, -122, Rect(140, 14, 3), [Fill("FF5A3A22")]),
            Shape("Tunic Hem", 0, -84, Rect(146, 8, 3), [Fill(TUNIC["trim"])]),
            Shape("Neck", 18, -236, Rect(34, 26, 8), [Fill(tone("skin", kit.SKINS))]),
            Shape("Tunic", 0, 0, Path(SLIM_BODY), [Fill(LinGrad(-60, -150, 70, -150, [(0, TUNIC["bottom"]), (1, TUNIC["top"])]))]),
        ]

    def legs(self):
        return [Shape("Leg Near", 36, -72, Rect(32, 34, 8), [Fill("FF2C3140")]),
                Shape("Leg Far", -44, -72, Rect(30, 34, 8), [Fill("FF22262F")])]

    def arm_style(self):
        return dict(kind="hand",
                    fur_near=lambda: LinGrad(0, 0, 0, 62, [(0, TUNIC["top"]), (1, TUNIC["bottom"])]),
                    fur_far=lambda: LinGrad(0, 0, 0, 62, [(0, TUNIC["bottom"]), (1, TUNIC["trim"])]),
                    hand=lambda: tone("skin", kit.SKINS))


class HumanMale(Human):
    FEMALE = False


class HumanFemale(Human):
    FEMALE = True


# ============================================================ CAPYBARA
CAPY = dict(base_top="FFA87248", base_bot="FF74482A", dark="FF5C3923", belly="FFC0935F",
            paw="FF4A2E1C", ear="FF6B4329", ear_in="FF3E2616", nose="FF2A1A10", mouth="FF3A2416")
CAPY_HEAD = [(-4, -348, -38, 0, 40, 0), (64, -328, -24, -9, 14, 6), (100, -300, -8, -10, 5, 8),
             (108, -262, 2, -14, -2, 13), (88, -234, 10, -8, -16, 7), (28, -222, 24, -2, -26, 1),
             (-36, -236, 24, 5, -18, -7), (-60, -284, 3, 21, -2, -26), (-40, -332, -12, 12, 14, -9)]


class Capybara(Species):
    ARTBOARD = "Capybara"

    def head(self):
        c = CAPY
        return dict(
            eyes=dict(at=(62, -298), eyes=[(0, 0, 1.0)]),
            face_top=[
                Shape("Nostril", 97, -285, Ellipse(10, 6), [Fill(c["nose"])], rot=0.55),
                Shape("Mouth", 0, 0, Path([(66, -248, 0, 0, 6, 4), (82, -243, -7, 1, 6, -1), (94, -251, -4, 4, 0, 0)],
                                          closed=False), [Stroke(c["mouth"], 2.6)]),
            ],
            over_hood=[round_ear("Ear", -14, -356, -0.35, 26, 22, c["ear"], c["ear_in"])],
            face_under=[
                Shape("Snout Highlight", 66, -314, Ellipse(62, 18), rot=0.38,
                      paints=[Fill(RadGrad(0, 0, 31, 0, [(0, "99E0AE82"), (1, "00E0AE82")]))]),
                Shape("Jaw Shade", 30, -230, Ellipse(110, 22),
                      paints=[Fill(RadGrad(0, 0, 55, 0, [(0, "55402614"), (1, "00402614")]))]),
            ],
            head=[Shape("Head", 0, 0, Path(CAPY_HEAD), key="head",
                        paints=[Fill(grad_v(c["base_top"], c["base_bot"], -348, -222))])],
        )

    def body(self):
        c = CAPY
        return [Shape("Belly", 0, 0, Path(ROUND_BELLY), [Fill(RadGrad(46, -116, 46, -44, [(0, c["belly"]), (1, "00C0935F")]))]),
                Shape("Body", 0, 0, Path(ROUND_BODY), [Fill(LinGrad(-80, -150, 90, -120, [(0, c["dark"]), (1, c["base_top"])]))])]

    def arm_style(self):
        c = CAPY
        return self.paw_style(c["base_top"], c["dark"], c["paw"])


# ============================================================ FOX
FOX = dict(top="FFF0893A", bottom="FFCC5E24", dark="FF3A2418", white="FFF8F0E4", ear_in="FF7A3520",
           tunic_top="FF9A2F3C", tunic_bot="FF5E1A24")
FOX_HEAD = [(0, -348, -36, 0, 34, 0), (52, -334, -18, -6, 16, 8), (90, -304, -12, -10, 12, 9),
            (122, -283, -6, -6, 3, 6), (113, -271, 6, -2, -12, 2), (84, -259, 12, -4, -10, 6),
            (60, -238, 10, -8, -14, 6), (26, -228, 14, -2, -18, 0), (-38, -240, 22, 8, -14, -12),
            (-60, -292, 2, 24, -2, -26), (-38, -334, -10, 12, 14, -8)]
FOX_MUZZLE = [(56, -282, 0, 0, 20, -6), (104, -287, -12, -2, 8, 1), (122, -283, 0, 0, 0, 0),
              (113, -271, 6, -2, -12, 2), (84, -259, 12, -4, -10, 6), (60, -238, 10, -8, -14, 4),
              (26, -228, 14, 0, -4, -10), (30, -254, -4, 12, 10, -14)]
FOX_TAIL = [(0, 0, 0, 0, -26, 14), (-70, -6, 26, 18, -26, -20), (-112, -96, 6, 34, 2, -32),
            (-98, -176, -12, 18, 14, -8), (-66, -164, -10, -12, -8, 22), (-64, -92, -12, -30, 12, 26),
            (4, -30, -22, 0, 0, 0)]
FOX_TAIL_TIP = [(-112, -120, 0, 0, 2, -28), (-98, -176, -12, 18, 14, -8), (-66, -164, -10, -12, -6, 14),
                (-70, -128, 0, -12, -12, 4)]


class Fox(Species):
    ARTBOARD = "Fox"

    def head(self):
        c = FOX
        return dict(
            eyes=dict(at=(64, -305), eyes=[(0, 0, 1.0), (-28, -3, 0.78)], size=(13, 15)),
            face_top=[
                Shape("Nose", 119, -281, Ellipse(13, 9), [Fill(c["dark"])], rot=0.3),
                Shape("Mouth", 0, 0, Path([(84, -258, 0, 0, 6, 3), (100, -264, 0, 0, 0, 0)], closed=False),
                      [Stroke(c["dark"], 2.4)]),
            ],
            over_hood=[pointed_ear("Ear Near", 40, -350, 0.38, 60, 17, c["top"], c["ear_in"], c["dark"]),
                       pointed_ear("Ear Far", -16, -356, -0.18, 56, 16, c["bottom"], c["ear_in"], c["dark"])],
            face_under=[Shape("Muzzle", 0, 0, Path(FOX_MUZZLE), [Fill(c["white"])])],
            head=[Shape("Head", 0, 0, Path(FOX_HEAD), key="head", paints=[Fill(grad_v(c["top"], c["bottom"], -348, -228))])],
        )

    def body(self):
        c = FOX
        return [
            Shape("Chest Fluff", 0, 0, Path([(-4, -240, 0, 0, 24, 0), (48, -234, 0, 0, -6, 20), (22, -190, 10, -6, -10, -6)]),
                  [Fill(c["white"])]),
            Shape("Buckle", 24, -124, Rect(13, 13, 2), [Fill("FFD9A93A")], rot=math.pi / 4),
            Shape("Belt", 0, -124, Rect(140, 13, 3), [Fill("FF4A2A18")]),
            Shape("Tunic", 0, 0, Path(SLIM_BODY), [Fill(LinGrad(-60, -150, 70, -150, [(0, c["tunic_bot"]), (1, c["tunic_top"])]))]),
        ]

    def legs(self):
        return [Shape("Leg Near", 36, -72, Rect(30, 34, 10), [Fill(FOX["bottom"])]),
                Shape("Leg Far", -44, -72, Rect(28, 34, 10), [Fill("FFA84A1C")])]

    def back(self):
        c = FOX
        return [Node("Tail", [
            Shape("Tail Tip", 0, 0, Path(FOX_TAIL_TIP), [Fill(c["white"])]),
            Shape("Tail", 0, 0, Path(FOX_TAIL), [Fill(LinGrad(0, 0, -110, -170, [(0, c["bottom"]), (1, c["top"])]))]),
        ], x=-70, y=-108, key="tail")]

    def arm_style(self):
        return self.paw_style(FOX["top"], FOX["bottom"], FOX["dark"])

    def idle_tracks(self):
        return [("tail", ROT, [(0, 0, E), (0.09, 100, None)])]


# ============================================================ AXOLOTL
AXO = dict(top="FFD0BCF6", bottom="FFA891E0", light="FFEEE6FD", dark="FF7E66C0", gill="FFF27DBA",
           gill_dark="FFC9579A", mouth="FF5A3F8A")
AXO_HEAD = [(2, -344, -40, 0, 40, 0), (72, -330, -22, -8, 16, 12), (104, -298, -2, -16, 2, 16),
            (106, -262, 4, -14, -6, 14), (80, -236, 18, -6, -20, 6), (20, -226, 26, 0, -26, 0),
            (-40, -238, 20, 8, -12, -12), (-60, -286, 0, 22, 0, -26), (-38, -330, -12, 12, 14, -8)]
AXO_TAIL = [(0, 0, 0, 0, -30, -8), (-84, -6, 24, -6, -22, 4), (-140, 14), (-84, 24, -22, -4, 24, 2),
            (0, 26, -20, 0, 0, 0)]
AXO_FIN = [(-10, -8, 0, 0, -30, -14), (-90, -18, 26, -8, -24, 8), (-150, 14), (-90, 36, -24, -6, 26, 8),
           (-10, 32, -24, 0, 0, 0)]


def gill_frond(name, rot, length, c):
    """A fern-like gill: tapered pink stem with short feather ticks."""
    parts = []
    for i, t in enumerate((0.35, 0.58, 0.8)):
        y = -length * t
        tick = 7 * (1.1 - t * 0.4)
        parts.append(Shape(f"Tick L{i}", 0, 0, Path([(0, y), (-tick, y - tick * 0.7)], closed=False), [Stroke(c["gill"], 3)]))
        parts.append(Shape(f"Tick R{i}", 0, 0, Path([(0, y), (tick, y - tick * 0.7)], closed=False), [Stroke(c["gill"], 3)]))
    parts.append(Shape("Stem", 0, 0, Path([(-4, 0), (0, -length), (4, 0)]),
                       [Fill(LinGrad(0, 0, 0, -length, [(0, c["gill_dark"]), (1, c["gill"])])), Stroke(c["gill"], 3)]))
    return Node(name, parts, rot=rot)


class Axolotl(Species):
    ARTBOARD = "Axolotl"

    def head(self):
        c = AXO
        near = Node("Gills Near", [gill_frond(f"Frond {i}", r, L, c) for i, (r, L) in enumerate(((0.45, 58), (1.0, 54), (1.55, 46)))],
                    x=98, y=-306, key="gills_near")
        far = Node("Gills Far", [gill_frond(f"Frond {i}", r, L, c) for i, (r, L) in enumerate(((-0.45, 56), (-1.0, 52), (-1.55, 44)))],
                   x=-78, y=-300, key="gills_far")
        return dict(
            eyes=dict(at=(62, -296), eyes=[(10, 0, 1.0), (-18, -2, 0.8)], size=(12, 13)),
            face_top=[
                Shape("Smile", 0, 0, Path([(54, -258, 0, 0, 10, 8), (78, -251, -10, 2, 10, -2), (100, -262, 0, 0, 0, 0)], closed=False),
                      [Stroke(c["mouth"], 2.8)]),
                Shape("Blush", 86, -270, Ellipse(18, 9), [Fill("88FF9EC8")]),
            ],
            over_hood=[near, far],
            face_under=[Shape("Face Light", 70, -270, Ellipse(70, 50), [Fill(RadGrad(0, 0, 35, 0, [(0, "77FFFFFF"), (1, "00FFFFFF")]))])],
            head=[Shape("Head", 0, 0, Path(AXO_HEAD), key="head", paints=[Fill(grad_v(c["top"], c["bottom"], -344, -226))])],
        )

    def body(self):
        c = AXO
        return [Shape("Belly", 0, 0, Path(ROUND_BELLY), [Fill(RadGrad(46, -116, 46, -44, [(0, c["light"]), (1, "00EEE6FD")]))]),
                Shape("Body", 0, 0, Path(ROUND_BODY), [Fill(LinGrad(-80, -150, 90, -120, [(0, c["bottom"]), (1, c["top"])]))])]

    def legs(self):
        return [Shape("Leg Near", 36, -60, Rect(30, 26, 10), [Fill(AXO["bottom"])]),
                Shape("Leg Far", -44, -60, Rect(28, 26, 10), [Fill(AXO["dark"])])]

    def back(self):
        c = AXO
        return [Node("Tail", [
            Shape("Tail", 0, 0, Path(AXO_TAIL), [Fill(LinGrad(0, 0, -140, 0, [(0, c["bottom"]), (1, c["top"])]))]),
            Shape("Tail Fin", 0, 0, Path(AXO_FIN), [Fill("99F5B8DC")]),
        ], x=-52, y=-92, rot=0.55, sx=0.8, sy=0.8, key="tail")]

    def arm_style(self):
        return self.paw_style(AXO["top"], AXO["bottom"], AXO["light"])

    def idle_tracks(self):
        return [("tail", ROT, [(0.55, 0, E), (0.45, 100, None)]),
                ("gills_near", ROT, [(0, 0, E), (0.08, 100, None)]),
                ("gills_far", ROT, [(0, 0, E), (-0.08, 100, None)])]


# ============================================================ OWL
OWL = dict(top="FF94693F", bottom="FF6A4A2E", dark="FF4E3520", cream="FFF4E8D0", chest="FFE8D6B4",
           beak="FFEBA43C", disk_edge="FFC9A574")
OWL_HEAD = [(4, -352, -40, 0, 40, 0), (70, -338, -22, -8, 16, 12), (100, -300, -2, -16, 2, 18),
            (98, -262, 4, -14, -8, 14), (76, -236, 18, -6, -20, 6), (18, -226, 26, 0, -26, 0),
            (-40, -238, 20, 8, -12, -12), (-62, -288, 0, 22, 0, -28), (-40, -334, -12, 12, 14, -8)]
OWL_DISK = [(22, -318, 0, 0, 16, -10), (60, -326, -16, -2, 16, 4), (92, -306, -6, -12, 4, 14),
            (96, -270, 2, -12, -4, 14), (76, -240, 14, -4, -16, 4), (40, -240, 14, 4, -10, -8),
            (20, -270, 4, 14, -4, -18)]


class Owl(Species):
    ARTBOARD = "Owl"

    def head(self):
        c = OWL
        tuft = lambda name, x, y, r: Node(name, [Shape("Tuft", 0, 0, Path([(-10, 4, 0, 0, -2, -8), (-6, -20), (0, -8), (4, -22), (10, 4, 0, -10, 0, 0)]),
                                                        [Fill(c["bottom"])])], x=x, y=y, rot=r)
        return dict(
            eyes=dict(at=(58, -290), eyes=[(18, 0, 1.2), (-10, -1, 1.0)], size=(14, 15)),
            face_top=[Shape("Beak", 0, 0, Path([(64, -276, 0, 0, 6, -2), (78, -276, 0, 0, -2, 10), (71, -256, 2, -6, -4, -8)]),
                            [Fill(c["beak"])])],
            over_hood=[tuft("Tuft Near", 34, -354, 0.4), tuft("Tuft Far", -18, -358, -0.35)],
            face_under=[Shape("Face Disk", 0, 0, Path(OWL_DISK), [Fill(c["cream"]), Stroke(c["disk_edge"], 3)])],
            head=[Shape("Head", 0, 0, Path(OWL_HEAD), key="head", paints=[Fill(grad_v(c["top"], c["bottom"], -352, -226))])],
        )

    def body(self):
        c = OWL
        marks = [Shape(f"Feather Mark {i}", 0, 0, Path([(x - 5, y), (x, y + 5), (x + 5, y)], closed=False),
                       [Stroke("AA9C7A52", 2)]) for i, (x, y) in enumerate(((36, -168), (56, -150), (26, -130), (48, -112), (32, -92), (58, -88)))]
        return marks + [
            Shape("Chest", 0, 0, Path(ROUND_BELLY), [Fill(c["chest"])]),
            Shape("Body", 0, 0, Path(ROUND_BODY), [Fill(LinGrad(-80, -150, 90, -120, [(0, c["dark"]), (1, c["top"])]))]),
        ]

    def legs(self):
        return [Shape("Leg Near", 36, -60, Rect(22, 26, 8), [Fill(OWL["beak"])]),
                Shape("Leg Far", -44, -60, Rect(20, 26, 8), [Fill("FFC4862E")])]

    def arm_style(self):
        c = OWL
        return dict(kind="wing", fur_near=LinGrad(0, 0, 0, 88, [(0, c["top"]), (1, c["bottom"])]),
                    fur_far=LinGrad(0, 0, 0, 88, [(0, c["bottom"]), (1, c["dark"])]), stripe="88F4E8D0")


ROSTER = [HumanMale(), HumanFemale(), Capybara(), Fox(), Axolotl(), Owl()]
