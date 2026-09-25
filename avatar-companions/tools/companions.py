"""Builds every companion artboard into one Rive document (scene.rml) plus SVG
previews. Species art lives in species_*.py; everything shared lives in kit.py.

usage:
  python3 companions.py                  -> scene.rml + previews/<Artboard>.svg
  python3 companions.py sheet [species] cloak eyes boots augment [skin hair] [wave]
"""
import sys
import rivegen
from rivegen import Shape, Node, Ellipse, Fill, RadGrad, rid, set_scope, to_svg, fmt
import kit
from kit import (W, H, FEET_X, FEET_Y, NECK, CLOAKS, EYES, BOOTS, AUGMENTS, SKINS, HAIRS, SEL, RECOLOR,
                 hood_shell, hood_lining, cloak_front, cloak_back, boots_variant, eyes_node, arm, augments,
                 augment_fx_tracks, REST_ARM_NEAR, REST_ARM_FAR, ARM_NEAR_AT, ARM_FAR_AT)

X, Y, ROT, SX, SY, OP = 13, 14, 15, 16, 17, 18
IN_OUT = (0.42, 0, 0.58, 1)
OUT = (0.1, 0.6, 0.3, 1)


def solo(name, prefix, variants, builder, sel):
    return Node(name, [builder(n, c) for n, c in variants.items()], key=f"{prefix}_solo",
                solo_active=f"{prefix}_{sel}")


def character(sp, arm_rot=REST_ARM_NEAR, head_rot=0.0):
    h = sp.head()
    head_art = ([eyes_node(h["eyes"])] + h.get("face_top", []) + h.get("over_hood", [])
                + [solo("Hood", "hood", CLOAKS, hood_shell, SEL["cloak"])]
                + h.get("face_under", []) + h["head"]
                + [solo("Hood Lining", "lining", CLOAKS, hood_lining, SEL["cloak"])])
    scale = h.get("scale", 1.12)
    head_node = Node("Head", [Node("Head Art", head_art, x=-NECK[0], y=-NECK[1])],
                     x=NECK[0], y=NECK[1], sx=scale, sy=scale, rot=head_rot, key="head_node")
    style = sp.arm_style()
    kids = ([augments(),
             arm("Arm Near", ARM_NEAR_AT, arm_rot, style, key="arm_near", near=True),
             head_node]
            + sp.front()
            + [arm("Arm Far", ARM_FAR_AT, REST_ARM_FAR, style, near=False),
               solo("Cloak Front", "cloakF", CLOAKS, cloak_front, SEL["cloak"])]
            + sp.body()
            + [solo("Boots", "boots", BOOTS, boots_variant, SEL["boots"])]
            + sp.legs()
            + [solo("Cloak Back", "cloakB", CLOAKS, cloak_back, SEL["cloak"])]
            + sp.back())
    return Node("Character", kids, x=FEET_X, y=FEET_Y, key="character")


def ground():
    return Shape("Ground Glow", FEET_X, FEET_Y + 2, Ellipse(250, 34),
                 [Fill(RadGrad(0, 0, 125, 0, [(0, "7734C3E6"), (0.5, "3322556E"), (1, "0022556E")]))])


# ------------------------------------------------------------------ animation text
def kf(v, f, ease=None):
    if ease == "hold":
        return f'                    <KeyFrameDouble value="{fmt(float(v))}" frame="{f}" interpolationType="hold"/>\n'
    if ease:
        return (f'                    <KeyFrameDouble value="{fmt(float(v))}" frame="{f}" interpolationType="cubic">\n'
                f'                        <CubicEaseInterpolator x1="{ease[0]}" y1="{ease[1]}" x2="{ease[2]}" y2="{ease[3]}"/>\n'
                f'                    </KeyFrameDouble>\n')
    return f'                    <KeyFrameDouble value="{fmt(float(v))}" frame="{f}" interpolationType="linear"/>\n'


def keyed(tracks):
    """tracks: [(key, prop, [(value, frame, ease)])] grouped per object."""
    by_obj = {}
    for key, prop, frames in tracks:
        by_obj.setdefault(key, []).append((prop, frames))
    out = ""
    for key, props in by_obj.items():
        out += f'            <KeyedObject objectId="{rid(key)}">\n'
        for prop, frames in props:
            out += f'                <KeyedProperty propertyKey="{prop}">\n'
            out += "".join(kf(v, f, e) for v, f, e in frames)
            out += "                </KeyedProperty>\n"
        out += "            </KeyedObject>\n"
    return out


def anim(name, key, duration, loop, tracks):
    return (f'        <LinearAnimation loopValue="{loop}" fps="60" duration="{duration}" name="{name}" id="{rid(key)}">\n'
            f"{keyed(tracks)}        </LinearAnimation>\n")


def first_frame(tracks):
    return [(k, p, [(fr[0][0], 0, None)]) for k, p, fr in tracks]


WAVE = [(REST_ARM_NEAR, 0, OUT), (-1.85, 14, IN_OUT), (-2.15, 23, IN_OUT), (-1.6, 32, IN_OUT),
        (-2.15, 41, IN_OUT), (-1.6, 50, IN_OUT), (-1.85, 58, IN_OUT), (REST_ARM_NEAR, 80, None)]


def animations(sp):
    extra = sp.idle_tracks()
    idle = [("character", SX, [(1, 0, IN_OUT), (0.992, 100, None)]),
            ("character", SY, [(1, 0, IN_OUT), (1.022, 100, None)]),
            ("head_node", ROT, [(0, 0, IN_OUT), (0.03, 100, None)]),
            ("arm_near", ROT, [(REST_ARM_NEAR, 0, IN_OUT), (REST_ARM_NEAR - 0.05, 100, None)])] + extra
    wave = [("arm_near", ROT, WAVE),
            ("head_node", ROT, [(0, 0, IN_OUT), (-0.07, 16, IN_OUT), (-0.07, 60, IN_OUT), (0, 80, None)]),
            ("character", SX, [(1, 0, None), (1, 80, None)]),
            ("character", SY, [(1, 0, None), (1, 80, None)])]
    blink = [("eyes", SY, [(1, 0, "hold"), (1, 196, None), (0.1, 201, None), (1, 210, None)])]
    fx = augment_fx_tracks()
    return (anim("Idle", "anim_idle", 100, "pingPong", idle)
            + anim("Wave", "anim_wave", 80, "oneShot", wave)
            + anim("Blink", "anim_blink", 210, "loop", blink)
            + anim("Augment FX", "anim_fx", 240, "loop", fx)
            + anim("Still", "anim_still", 1, "oneShot", first_frame(idle))
            + anim("Eyes Open", "anim_eyes_open", 1, "oneShot", [("eyes", SY, [(1, 0, None)])])
            + anim("Augment FX Still", "anim_fx_still", 1, "oneShot", first_frame(fx)))


def slot_defs(sp):
    """slot -> (variant names, animation body builder)"""
    solos = {"cloak": ["hood", "lining", "cloakF", "cloakB"], "eyes": ["eye"], "boots": ["boots"], "augment": ["aug"]}
    variants = {"cloak": list(CLOAKS), "eyes": list(EYES), "boots": list(BOOTS), "augment": AUGMENTS}
    defs = {}
    for slot, prefixes in solos.items():
        defs[slot] = (variants[slot], lambda name, prefixes=prefixes, slot=slot: "".join(
            f'            <KeyedObject objectId="{rid(p + "_solo")}">\n'
            f'                <KeyedProperty propertyKey="296">\n'
            f'                    <KeyFrameId value="{rid(("eyes" if p == "eye" else p) + "_" + name)}" frame="0" interpolationType="hold"/>\n'
            f'                </KeyedProperty>\n'
            f'            </KeyedObject>\n' for p in prefixes))
    for role, palette in (("skin", SKINS), ("hair", HAIRS)):
        if RECOLOR.get(role):
            defs[role] = (list(palette), lambda name, role=role, palette=palette: "".join(
                f'            <KeyedObject objectId="{rid(k)}">\n'
                f'                <KeyedProperty propertyKey="37">\n'
                f'                    <KeyFrameColor value="{palette[name]}" frame="0" interpolationType="hold"/>\n'
                f'                </KeyedProperty>\n'
                f'            </KeyedObject>\n' for k in RECOLOR[role]))
    return defs


def slot_animations(defs):
    out = ""
    for slot, (names, body) in defs.items():
        for name in names:
            out += (f'        <LinearAnimation loopValue="oneShot" fps="60" duration="1" name="{slot.title()} {name}" '
                    f'id="{rid(f"anim_{slot}_{name}")}">\n{body(name)}        </LinearAnimation>\n')
    return out


def slot_layer(slot, names, y, start):
    states = ""
    for i, name in enumerate(names):
        trans = "".join(
            f'                    <StateTransition stateToId="{rid(f"st_{slot}_{other}")}" duration="0">\n'
            f'                        <TransitionNumberCondition inputId="{rid(f"in_{slot}")}" opValue="equal" value="{j}"/>\n'
            f'                    </StateTransition>\n'
            for j, other in enumerate(names) if j != i)
        states += (f'                <AnimationState animationId="{rid(f"anim_{slot}_{name}")}" x="{160 + 130 * i}" y="{y}" '
                   f'id="{rid(f"st_{slot}_{name}")}">\n{trans}                </AnimationState>\n')
    return (f'            <StateMachineLayer name="{slot.title()}" id="{rid(f"layer_{slot}")}">\n'
            f'                <AnyState x="{160 + 130 * len(names)}" y="{y}"/>\n'
            f'                <ExitState x="{290 + 130 * len(names)}" y="{y}"/>\n'
            f'                <EntryState x="0" y="{y}">\n'
            f'                    <StateTransition stateToId="{rid(f"st_{slot}_{start}")}"/>\n'
            f'                </EntryState>\n{states}            </StateMachineLayer>\n')


def calm(value):
    return f'<TransitionBoolCondition inputId="{rid("in_calm")}" opValue="{"equal" if value else "notEqual"}"/>'


def toggle_layer(name, key, y, live_state, live_anim, still_state, still_anim):
    return f'''            <StateMachineLayer name="{name}" id="{rid(key)}">
                <AnyState x="480" y="{y}"/>
                <ExitState x="600" y="{y}"/>
                <EntryState x="0" y="{y}">
                    <StateTransition stateToId="{rid(live_state)}"/>
                </EntryState>
                <AnimationState animationId="{rid(live_anim)}" x="160" y="{y}" id="{rid(live_state)}">
                    <StateTransition stateToId="{rid(still_state)}" duration="0">
                        {calm(True)}
                    </StateTransition>
                </AnimationState>
                <AnimationState animationId="{rid(still_anim)}" x="320" y="{y}" id="{rid(still_state)}">
                    <StateTransition stateToId="{rid(live_state)}" duration="0">
                        {calm(False)}
                    </StateTransition>
                </AnimationState>
            </StateMachineLayer>
'''


def state_machine(defs):
    inputs = "".join(f'            <StateMachineNumber name="{s}" id="{rid(f"in_{s}")}"/>\n' for s in defs)
    layers = "".join(slot_layer(s, names, 600 + 200 * k, names[0]) for k, (s, (names, _)) in enumerate(defs.items()))
    return f'''        <StateMachine name="State Machine 1" id="{rid('sm')}">
            <StateMachineTrigger name="wave" id="{rid('trig_wave')}"/>
            <StateMachineBool name="calm" id="{rid('in_calm')}"/>
{inputs}
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

{toggle_layer("Blink", "layer_blink", 200, "st_blink", "anim_blink", "st_eyes_open", "anim_eyes_open")}
{toggle_layer("Augment FX", "layer_fx", 400, "st_fx", "anim_fx", "st_fx_still", "anim_fx_still")}
{layers}        </StateMachine>
'''


def build_artboard(sp, index, pose=None):
    set_scope(sp.ARTBOARD)
    RECOLOR.clear()
    char, gnd = character(sp, **(pose or {})), ground()
    scene = char.rml("        ") + gnd.rml("        ")
    defs = slot_defs(sp)
    rml = (f'    <Artboard x="{index * 520}" y="0" defaultStateMachineId="{rid("sm")}" width="{W}" height="{H}" '
           f'name="{sp.ARTBOARD}" id="{rid("artboard")}">\n'
           f"{scene}\n{state_machine(defs)}\n{animations(sp)}{slot_animations(defs)}    </Artboard>\n")
    return rml, to_svg([char, gnd], W, H)


def roster():
    import species_wave1, species_more
    return species_wave1.ROSTER + species_more.ROSTER


def build_all():
    kit.reset_selection()
    parts = []
    for i, sp in enumerate(roster()):
        rml, _ = build_artboard(sp, i)
        parts.append(rml)
    return '<Rive version="1" kind="fragment">\n' + "".join(parts) + "</Rive>\n"


if __name__ == "__main__":
    import os
    os.makedirs("previews", exist_ok=True)
    if len(sys.argv) > 1 and sys.argv[1] == "sheet":
        # sheet <out.svg> <Species|all> cloak eyes boots augment [skin hair] [wave]
        out, which = sys.argv[2], sys.argv[3]
        vals = sys.argv[4:]
        keys = ["cloak", "eyes", "boots", "augment", "skin", "hair"]
        for k, v in zip(keys, [v for v in vals if v != "wave"]):
            SEL[k] = v.replace("_", " ")
        pose = dict(arm_rot=-2.15, head_rot=-0.07) if "wave" in vals else None
        sp = [s for s in roster() if s.ARTBOARD == which][0]
        _, svg = build_artboard(sp, 0, pose)
        open(out, "w").write(svg)
    else:
        open("scene.rml", "w").write(build_all())
        kit.reset_selection()
        for i, sp in enumerate(roster()):
            _, svg = build_artboard(sp, i)
            open(f"previews/{sp.ARTBOARD}.svg", "w").write(svg)
        print("ok", [s.ARTBOARD for s in roster()])
