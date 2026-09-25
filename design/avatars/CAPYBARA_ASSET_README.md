# Capybara vector starting asset

Created a genuine editable SVG, not a flattened image: capybara-layered-v1.svg. Named groups include Root, CloakBack, Body, ArmLeft, ArmRight, LegLeft/ShoeLeft, LegRight/ShoeRight, Head, Ears, Face, Muzzle, Nose, Smile, EyeLeft, EyeRight, HoodBack, HoodFront, CloakShoulders and AugmentLeaf. EyeColorLeft/Right are individually addressable shapes. All drawing uses paths/ellipses; no embedded raster art. This simplified first art pass needs user visual review.

capybara-motion-preview.html demonstrates browser-only breathing, blink, cloak sway and wave. It is NOT a .riv file, skeletal rig, or app integration. Import the static SVG into Rive, verify editable group structure, author transform pivots/bones and state-machine timelines, then export a working .riv. Some hierarchy/IDs may require renaming after import. Current 2D pivot hints in 600x600 coordinates: root 300,470; right shoulder 367,313; left shoulder 221,313; head ~300,275; cloak 300,280. Verify appearance and rotation overlap in editor.

## Important correction to previous Claude advice
The user does not have to manually draw/trace everything. Official Rive desktop MCP supports structured creation/editing of shapes, paths, keyframes, animation/state machines and data binding. Actual bone/weighting tool availability must be inspected, not assumed.
Official setup: https://rive.app/docs/editor/ai/mcp
Install/open current Rive desktop app (docs include an Early Access note), open a file/artboard, then connect Claude Code:

    claude mcp add --transport http rive http://127.0.0.1:9791/mcp

Verify available tools in Claude; do not silently install an unrelated third-party server. Rive is not connected in this Codex session and no Rive application was found in /Applications at inspection. No .riv has been created. Rive's free editor does not imply free production export; check current pricing before purchasing: https://rive.app/pricing . User should sign in directly, not share passwords in chat.

Current app still uses PixelAvatarView in AvatarView.swift with AvatarConfig slots robe/eyes/cloak/headwear. Preserve XP, currency, purchased item IDs and existing work during migration. Do not remove the current renderer before a working replacement passes visual and build checks. See AVATAR_RIVE_HANDOFF.md for full roster/progression intent.
