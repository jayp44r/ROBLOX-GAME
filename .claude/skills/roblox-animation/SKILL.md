---
name: roblox-animation
description: Animate Roblox characters (R6/R15) so they feel alive and pro, in Blender or straight in Roblox Studio. Covers idles, walks, runs, attacks, emotes, talking or cutscene acting, NPC animations and ability animations, then exporting and uploading to Roblox. Use whenever the user asks for an animation, a pose, a cutscene, an emote, or to make a character move.
---

# Roblox character animation

Learned from a creator's workflow video (@weenocks) that used Roblox Studio, Blender, Moon Animator 2 and Cautioned's Roblox Blender plugin, plus the 12 principles of animation.

## Pick the route

- **Straight in Studio (default, quickest)**: build the animation with `scripts/AnimBuilder.lua` through robloxstudio-mcp. It goes into the rig's `AnimSaves`, so the user can open it in the **Animation Editor**, tweak it and click **Publish**.
- **Blender (best quality, long or complex acting)**: get the rig into Blender, key it with blender-mcp `insert_keyframes`, then `export_fbx`. In Studio, use **Animation Editor → Import → From FBX Animation**, then publish. The Blender plugin (Cautioned's "Roblox Animations" add-on) can import or export rigs directly if the user has it. `get_scene_info` says whether it's installed.

Always use 30 fps (`set_animation_settings fps=30`). Only the user can publish to their account. When it's ready, tell them: Animation Editor → ⋯ → Publish to Roblox, then copy the ID.

## How to make it look pro (from the video)

1. **Block key poses first, then in-betweens.** Set the 2-4 storytelling poses (anticipation → action → follow-through → settle) before adding anything between them.
2. **Animate from the hips out.** Do the **legs and root first** (weight, steps, bounce), then the **torso**, then **arms**, then the **head** last. Don't animate the torso before the legs work.
3. **Timing and spacing (graph editor).** Use ease-in/ease-out (`Cubic`/`InOut`) for natural moves; fast-in then slow-out for hits; `Back` for snappy overshoot; `Bounce` or `Elastic` only for cartoon gags. Fewer frames = heavier impact.
4. **Overlap and offset.** Body parts shouldn't all hit their poses on the same frame. Delay arms 1-3 frames behind the torso and the head 1-2 frames behind the chest.
5. **Arcs.** Hands and the head travel in curves, not straight lines. Add a middle key that bows the path.
6. **Exaggerate.** Roblox characters are blocky and small on screen, so push poses about 20-30% further than "real life".
7. **Talking or cutscenes.** Move the arms up and down on the beat of the words, and nod or bob the head slightly on each word or stressed syllable. Add a slow breathing idle underneath (torso up and down about 0.05 studs over 2-3 s) so the character is never frozen.
8. **Loops.** The last keyframe must equal the first. Set `loop = true` for idles, walks and runs.
9. **Priority.** Idle = `Idle`, walk/run = `Movement`, attacks/emotes/abilities = `Action`.

## Handy numbers (R15, degrees relative to rest)

- Raise arm to the side: `RightUpperArm rot {0,0,90}`; left arm uses the opposite sign.
- Arm forward (punch / point): `RightUpperArm rot {90,0,0}`.
- Bend elbow: `RightLowerArm rot {60,0,0}`. Bend knee: `RightLowerLeg rot {-60,0,0}`.
- Lean the body: `LowerTorso` / `UpperTorso rot {-10..15,0,0}`. Crouch: `LowerTorso pos {0,-0.6,0}`.
- Walk cycle (1 s loop, 30 fps): contact, down, passing, up for each leg. Legs swing ±30°, arms swing opposite ±25°, and the hips bob 0.1 studs down on contact.

Axes can differ between rigs, so check a pose on one joint first (preview, or `get_viewport_screenshot` in Blender) before keying everything.

## Playing it in game

```lua
local animator = humanoid:FindFirstChildOfClass("Animator")
local track = animator:LoadAnimation(animationInstanceWithPublishedId)
track:Play(0.1) -- 0.1 s fade in
```

`AnimBuilder.previewId(seq)` gives a temporary ID that works only in Studio playtests, for checking before publishing.
