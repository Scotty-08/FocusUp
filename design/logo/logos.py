"""FocusUp logo concepts (wordless). Each concept is one SVG mark at 1024x1024.

Two outputs per concept:
  mark_<k>.svg  -- transparent mark (for the blocker shield / in-app use)
  icon_<k>.svg  -- full-bleed app icon (mark on the navy tile)
"""
import math

C = 512
NAVY_BG = """<radialGradient id="bg" cx="512" cy="430" r="720" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#16274A"/><stop offset="0.55" stop-color="#0B1528"/><stop offset="1" stop-color="#050A14"/></radialGradient>"""
GLOW = """<filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
  <feGaussianBlur stdDeviation="14" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>"""


def pol(r, deg, cx=C, cy=C):
    a = math.radians(deg)
    return cx + r * math.cos(a), cy + r * math.sin(a)


def arc(r, a0, a1):
    x0, y0 = pol(r, a0)
    x1, y1 = pol(r, a1)
    large = 1 if (a1 - a0) % 360 > 180 else 0
    return f"M {x0:.1f} {y0:.1f} A {r} {r} 0 {large} 1 {x1:.1f} {y1:.1f}"


def brackets(half=330, arm=118, width=30, stroke="#E8F6FB", opacity=0.92):
    out = []
    for sx, sy in [(-1, -1), (1, -1), (1, 1), (-1, 1)]:
        cx, cy = C + sx * half, C + sy * half
        d = f"M {cx} {cy - sy * arm} L {cx} {cy} L {cx - sx * arm} {cy}"
        out.append(f'<path d="{d}" fill="none" stroke="{stroke}" stroke-opacity="{opacity}" '
                   f'stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>')
    return "".join(out)


def sparkle(cx, cy, outer, inner, fill, glow=True):
    pts = []
    for i in range(8):
        r = outer if i % 2 == 0 else inner
        a = math.radians(-90 + 45 * i)
        pts.append(f"{cx + r * math.cos(a):.1f},{cy + r * math.sin(a):.1f}")
    f = ' filter="url(#glow)"' if glow else ""
    return f'<polygon points="{" ".join(pts)}" fill="{fill}"{f}/>'


# ------------------------------------------------------------ A: Aperture
def concept_a():
    defs = """<linearGradient id="ring" x1="512" y1="250" x2="512" y2="774" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#E3D8FA"/><stop offset="0.5" stop-color="#6D66DB"/><stop offset="1" stop-color="#3EE6FF"/></linearGradient>"""
    blades = []
    for k in range(6):
        a0 = -90 + 60 * k + 14
        blades.append(f'<path d="{arc(250, a0, a0 + 34)}" fill="none" stroke="#070D1A" stroke-width="124" stroke-linecap="round"/>'
                      f'<path d="{arc(250, a0, a0 + 34)}" fill="none" stroke="url(#ring)" stroke-width="100" stroke-linecap="round"/>')
    ox, oy = pol(92, -45)
    body = (brackets()
            + "".join(blades)
            + f'<circle cx="{C}" cy="{C}" r="92" fill="#081226" stroke="#E8F6FB" stroke-width="20"/>'
            + sparkle(C, C, 50, 13, "#3EE6FF")
            + f'<circle cx="{ox:.1f}" cy="{oy:.1f}" r="22" fill="#E8F6FB"/>')
    return defs, body


# ------------------------------------------------------------ B: Shutter
def blade_path(rot):
    outer, inner = [], []
    n = 40
    for i in range(n + 1):
        t = i / n
        ang = -118 + 118 * t + rot
        rc = 212 + 100 * t
        th = 92 * math.sin(math.pi * t) ** 0.75
        outer.append(pol(rc + th / 2, ang))
        inner.append(pol(rc - th / 2, ang))
    pts = outer + inner[::-1]
    return "M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts) + " Z"


def concept_b():
    defs = """<linearGradient id="blade" x1="200" y1="200" x2="824" y2="824" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#3EE6FF"/><stop offset="1" stop-color="#6E8CA8"/></linearGradient>
    <radialGradient id="lens" cx="470" cy="470" r="200" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#23385A"/><stop offset="1" stop-color="#04070D"/></radialGradient>"""
    frame = (f'<rect x="{C - 300}" y="{C - 300}" width="600" height="600" rx="22" fill="none" '
             f'stroke="#6E8CA8" stroke-opacity="0.8" stroke-width="22"/>')
    blades = "".join(f'<path d="{blade_path(90 * k)}" fill="#070D1A" stroke="#070D1A" stroke-width="22" stroke-linejoin="round"/>'
                     f'<path d="{blade_path(90 * k)}" fill="url(#blade)"/>' for k in range(4))
    crescent = (f'<path d="M {C - 82} {C - 10} A 84 84 0 0 0 {C + 30} {C + 78} A 104 104 0 0 1 {C - 82} {C - 10} Z" '
                f'fill="#3EE6FF" filter="url(#glow)"/>')
    body = (frame + blades
            + f'<circle cx="{C}" cy="{C}" r="160" fill="#070D1A"/>'
            + f'<circle cx="{C}" cy="{C}" r="142" fill="url(#lens)" stroke="#16243A" stroke-width="10"/>'
            + crescent
            + f'<circle cx="{C + 38}" cy="{C - 40}" r="30" fill="#BDF4FC"/>')
    return defs, body


# ------------------------------------------------------------ C: Ascend
def concept_c():
    defs = """<linearGradient id="ring" x1="262" y1="262" x2="762" y2="762" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#C9B8F0"/><stop offset="1" stop-color="#3EE6FF"/></linearGradient>
    <linearGradient id="chev" x1="512" y1="420" x2="512" y2="640" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#E8F6FB"/><stop offset="1" stop-color="#3EE6FF"/></linearGradient>"""
    body = (brackets(stroke="#3EE6FF", opacity=0.9)
            + f'<circle cx="{C}" cy="{C}" r="246" fill="none" stroke="url(#ring)" stroke-width="22"/>'
            + f'<path d="M 360 626 L 512 468 L 664 626" fill="none" stroke="url(#chev)" stroke-width="78" '
              f'stroke-linecap="round" stroke-linejoin="round"/>'
            + sparkle(C, 352, 62, 15, "#FFC94D"))
    return defs, body


CONCEPTS = {"A": concept_a, "B": concept_b, "C": concept_c}


def write(k):
    defs, body = CONCEPTS[k]()
    head = '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'
    mark = f"{head}<defs>{GLOW}{defs}</defs>{body}</svg>"
    icon = f'{head}<defs>{NAVY_BG}{GLOW}{defs}</defs><rect width="1024" height="1024" fill="url(#bg)"/>{body}</svg>'
    open(f"mark_{k}.svg", "w").write(mark)
    open(f"icon_{k}.svg", "w").write(icon)


if __name__ == "__main__":
    for k in CONCEPTS:
        write(k)
    print("ok")
