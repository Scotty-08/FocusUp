"""Tiny scene DSL that emits both Rive RML and an SVG preview from one description.

Coordinates follow Rive: y grows downward, rotation in radians, first-declared
child draws on TOP (the SVG emitter reverses order to match).
"""
import math
from xml.sax.saxutils import quoteattr

_ids = {}
_next_id = [100]
_scope = [""]


def set_scope(name):
    """Ids are unique across the whole document, so every artboard keys its
    ids under its own scope ("Fox/head", "Owl/head", ...)."""
    _scope[0] = name


def rid(key):
    """Stable authored id for anything that gets referenced."""
    key = f"{_scope[0]}/{key}"
    if key not in _ids:
        _ids[key] = f"0:{_next_id[0]}"
        _next_id[0] += 1
    return _ids[key]


def fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        s = f"{v:.4f}".rstrip("0").rstrip(".")
        return "0" if s in ("-0", "") else s
    return str(v)


def attrs(d):
    return " ".join(f'{k}={quoteattr(fmt(v))}' for k, v in d.items() if v is not None)


def argb_to_svg(c):
    a = int(c[0:2], 16) / 255.0
    return "#" + c[2:], a


# ---------------------------------------------------------------- paints
class Solid:
    """key: give this colour an id so a slot animation can recolour it
    (SolidColor.colorValue, propertyKey 37)."""
    def __init__(self, color, key=None):
        self.color, self.key = color, key

    def rml(self, ind):
        idattr = f' id="{rid(self.key)}"' if self.key else ""
        return f'{ind}<SolidColor colorValue="{self.color}" name="Color"{idattr}/>\n'


class LinGrad:
    def __init__(self, sx, sy, ex, ey, stops):
        self.sx, self.sy, self.ex, self.ey, self.stops = sx, sy, ex, ey, stops

    def rml(self, ind):
        out = f'{ind}<LinearGradient {attrs(dict(startX=float(self.sx), startY=float(self.sy), endX=float(self.ex), endY=float(self.ey)))} name="Gradient">\n'
        for pos, col in self.stops:
            out += f'{ind}    <GradientStop colorValue="{col}" position="{fmt(float(pos))}"/>\n'
        return out + f"{ind}</LinearGradient>\n"


class RadGrad(LinGrad):
    def rml(self, ind):
        return super().rml(ind).replace("LinearGradient", "RadialGradient")


class Fill:
    def __init__(self, paint):
        self.paint = paint if not isinstance(paint, str) else Solid(paint)

    def rml(self, ind):
        return f'{ind}<Fill name="Fill">\n{self.paint.rml(ind + "    ")}{ind}</Fill>\n'


class Stroke:
    def __init__(self, paint, thickness, cap="round", join="round", feather=None):
        self.paint = paint if not isinstance(paint, str) else Solid(paint)
        self.thickness, self.cap, self.join, self.feather = thickness, cap, join, feather

    def rml(self, ind):
        out = f'{ind}<Stroke {attrs(dict(thickness=float(self.thickness), cap=self.cap, join=self.join))} name="Stroke">\n'
        out += self.paint.rml(ind + "    ")
        if self.feather:
            out += f'{ind}    <Feather strength="{fmt(float(self.feather))}" name="Feather"/>\n'
        return out + f"{ind}</Stroke>\n"


# ---------------------------------------------------------------- geometry
class Ellipse:
    def __init__(self, w, h):
        self.w, self.h = w, h

    def rml(self, ind):
        return f'{ind}<Ellipse width="{fmt(float(self.w))}" height="{fmt(float(self.h))}" originX="0.5" originY="0.5" name="Path"/>\n'

    def svg_d(self):
        rx, ry = self.w / 2, self.h / 2
        return f"M {-rx} 0 A {rx} {ry} 0 1 0 {rx} 0 A {rx} {ry} 0 1 0 {-rx} 0 Z"


class Rect:
    def __init__(self, w, h, r=0):
        self.w, self.h, self.r = w, h, r

    def rml(self, ind):
        extra = f' cornerRadiusTL="{fmt(float(self.r))}"' if self.r else ""
        return f'{ind}<Rectangle width="{fmt(float(self.w))}" height="{fmt(float(self.h))}" originX="0.5" originY="0.5"{extra} name="Path"/>\n'

    def svg_d(self):
        w, h, r = self.w, self.h, min(self.r, self.w / 2, self.h / 2)
        x0, y0 = -w / 2, -h / 2
        if not r:
            return f"M {x0} {y0} h {w} v {h} h {-w} Z"
        return (f"M {x0 + r} {y0} H {x0 + w - r} A {r} {r} 0 0 1 {x0 + w} {y0 + r} V {y0 + h - r} "
                f"A {r} {r} 0 0 1 {x0 + w - r} {y0 + h} H {x0 + r} A {r} {r} 0 0 1 {x0} {y0 + h - r} "
                f"V {y0 + r} A {r} {r} 0 0 1 {x0 + r} {y0} Z")


class Path:
    """points: (x, y) for a corner, or (x, y, inx, iny, outx, outy) with handle
    offsets relative to the point."""

    def __init__(self, pts, closed=True):
        self.pts, self.closed = pts, closed

    def rml(self, ind):
        out = f'{ind}<PointsPath isClosed="{fmt(self.closed)}" name="Path">\n'
        for p in self.pts:
            if len(p) == 2:
                out += f'{ind}    <StraightVertex x="{fmt(float(p[0]))}" y="{fmt(float(p[1]))}"/>\n'
            else:
                x, y, ix, iy, ox, oy = p
                d = dict(x=float(x), y=float(y),
                         inRotation=math.atan2(iy, ix), inDistance=math.hypot(ix, iy),
                         outRotation=math.atan2(oy, ox), outDistance=math.hypot(ox, oy))
                out += f"{ind}    <CubicDetachedVertex {attrs(d)}/>\n"
        return out + f"{ind}</PointsPath>\n"

    def svg_d(self):
        def full(p):
            return p if len(p) == 6 else (p[0], p[1], 0, 0, 0, 0)
        pts = [full(p) for p in self.pts]
        d = f"M {pts[0][0]} {pts[0][1]} "
        segs = list(zip(pts, pts[1:]))
        if self.closed:
            segs.append((pts[-1], pts[0]))
        for a, b in segs:
            d += (f"C {a[0] + a[4]} {a[1] + a[5]} {b[0] + b[2]} {b[1] + b[3]} {b[0]} {b[1]} ")
        return d + ("Z" if self.closed else "")


# ---------------------------------------------------------------- tree
class Shape:
    def __init__(self, name, x=0, y=0, geo=None, paints=(), rot=0.0, key=None, sx=1, sy=1, opacity=1):
        self.name, self.x, self.y, self.geo, self.paints = name, x, y, geo, list(paints)
        self.rot, self.key, self.sx, self.sy, self.opacity = rot, key, sx, sy, opacity

    def rml(self, ind):
        a = dict(x=float(self.x) if self.x else None, y=float(self.y) if self.y else None,
                 rotation=float(self.rot) if self.rot else None,
                 scaleX=float(self.sx) if self.sx != 1 else None,
                 scaleY=float(self.sy) if self.sy != 1 else None,
                 opacity=float(self.opacity) if self.opacity != 1 else None,
                 name=self.name, id=rid(self.key) if self.key else None)
        out = f"{ind}<Shape {attrs(a)}>\n" + self.geo.rml(ind + "    ")
        for p in self.paints:
            out += p.rml(ind + "    ")
        return out + f"{ind}</Shape>\n"

    def svg(self, ctx):
        d = self.geo.svg_d()
        body = ""
        for p in self.paints:
            paint_ref, alpha = ctx.paint(p.paint)
            if isinstance(p, Fill):
                body += f'<path d="{d}" fill="{paint_ref}" fill-opacity="{alpha}"/>'
            else:
                filt = ""
                if p.feather:
                    filt = f' filter="url(#{ctx.blur(p.feather)})"'
                body += (f'<path d="{d}" fill="none" stroke="{paint_ref}" stroke-opacity="{alpha}" '
                         f'stroke-width="{p.thickness}" stroke-linecap="{p.cap}" stroke-linejoin="{p.join}"{filt}/>')
        op = f' opacity="{self.opacity}"' if self.opacity != 1 else ""
        return f'<g transform="{tf(self)}"{op}>{body}</g>'


class Node:
    def __init__(self, name, children, x=0, y=0, rot=0.0, key=None, solo_active=None, sx=1, sy=1):
        self.name, self.children, self.x, self.y, self.rot = name, children, x, y, rot
        self.key, self.solo_active, self.sx, self.sy = key, solo_active, sx, sy

    def rml(self, ind):
        tag = "Solo" if self.solo_active else "Node"
        a = dict(x=float(self.x) if self.x else None, y=float(self.y) if self.y else None,
                 rotation=float(self.rot) if self.rot else None,
                 scaleX=float(self.sx) if self.sx != 1 else None,
                 scaleY=float(self.sy) if self.sy != 1 else None,
                 activeComponentId=rid(self.solo_active) if self.solo_active else None,
                 name=self.name, id=rid(self.key) if self.key else None)
        out = f"{ind}<{tag} {attrs(a)}>\n"
        for c in self.children:
            out += c.rml(ind + "    ")
        return out + f"{ind}</{tag}>\n"

    def svg(self, ctx):
        kids = self.children
        if self.solo_active:
            kids = [c for c in kids if c.key == self.solo_active]
        inner = "".join(c.svg(ctx) for c in reversed(kids))
        return f'<g transform="{tf(self)}">{inner}</g>'


def tf(o):
    return (f"translate({o.x} {o.y}) rotate({math.degrees(o.rot)}) scale({o.sx} {o.sy})")


class SvgCtx:
    def __init__(self):
        self.defs, self.n = [], 0

    def paint(self, p):
        if isinstance(p, Solid):
            return argb_to_svg(p.color)
        self.n += 1
        gid = f"g{self.n}"
        stops = "".join(
            f'<stop offset="{pos}" stop-color="{argb_to_svg(c)[0]}" stop-opacity="{argb_to_svg(c)[1]}"/>'
            for pos, c in p.stops)
        if isinstance(p, RadGrad):
            r = math.hypot(p.ex - p.sx, p.ey - p.sy)
            self.defs.append(f'<radialGradient id="{gid}" gradientUnits="userSpaceOnUse" cx="{p.sx}" cy="{p.sy}" r="{r}">{stops}</radialGradient>')
        else:
            self.defs.append(f'<linearGradient id="{gid}" gradientUnits="userSpaceOnUse" x1="{p.sx}" y1="{p.sy}" x2="{p.ex}" y2="{p.ey}">{stops}</linearGradient>')
        return f"url(#{gid})", 1

    def blur(self, strength):
        self.n += 1
        fid = f"f{self.n}"
        self.defs.append(f'<filter id="{fid}" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="{strength / 2}"/></filter>')
        return fid


def to_svg(root_children, w, h, bg="#0E1A33"):
    ctx = SvgCtx()
    body = "".join(c.svg(ctx) for c in reversed(root_children))
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            f'<defs>{"".join(ctx.defs)}</defs><rect width="{w}" height="{h}" fill="{bg}"/>{body}</svg>')
