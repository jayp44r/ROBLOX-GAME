---
name: roblox-ability-moveset
description: Build a battlegrounds or anime-style ability moveset in Roblox. Abilities on keys (E/R/C/F/T/V) and phone buttons, cooldowns, a hold-Q ability wheel, server-side hitboxes, damage, knockback and stun, and layered VFX (magic circles, dark smoke, beams/chains, auras, shields, projectiles, screen tint, camera shake, damage numbers). Use when the user asks for abilities, moves, skills, powers, a moveset, a battlegrounds/fighting game, magic attacks, cooldown UI, or VFX for an ability.
---

# Ability moveset (battlegrounds style)

Learned from a "VFX moveset test" (@thetribrid6: the purple "Dark Self" kit with Outburst, Chains, Overload, Shield, Throw, Bolt and Soul Storm) and a stylized-VFX breakdown (@sambamstudios: "do your effects in layers").

## Files and where they go

| File | Instance | Location |
|---|---|---|
| `scripts/AbilityConfig.lua` | ModuleScript `AbilityConfig` | ReplicatedStorage |
| `scripts/AbilityVFX.lua` | ModuleScript `AbilityVFX` | ReplicatedStorage |
| `scripts/AbilityServer.server.lua` | Script `AbilityServer` | ServerScriptService |
| `scripts/AbilityClient.client.lua` | LocalScript `AbilityClient` | StarterPlayer › StarterPlayerScripts |

Create them with robloxstudio-mcp and set each Source to the file's contents. Add 2-3 test **Dummies** (R15 rigs with a Humanoid) near spawn so the user can see hits; Studio's Rig Builder rigs work. No uploaded assets are needed.

## What the user gets

- **E Outburst**: a magic circle appears, then a blast with a shockwave, streaks, smoke and sparks. Damage and knockback in a radius.
- **R Chains**: twisting energy beams to the enemy nearest your aim, plus damage and a 1.5 s root.
- **C Overload**: a dark aura with smoke, a glow outline, a purple screen tint and damage ticks around you.
- **F Shield**: a bubble; you take no damage for 3 s.
- **T Bolt**: a glowing projectile with a trail that explodes where you aim.
- **V Soul Storm**: a giant circle, rolling dark smoke, a dark screen tint and damage ticks over a big area.
- UI: a "DARK SELF · READY" pill, a cast line ("[E] OUTBURST · 4.2s"), a bottom bar of buttons with cooldown sweeps (tap on phone), and a **hold Q** wheel.

## Customising (edit AbilityConfig)

- Rename or re-theme the kit: change `name`, the `theme` colours (fire = orange/red, ice = cyan/white, holy = gold/white, toxic = green) and the ability `id`s, keys, cooldowns and numbers.
- New ability: add an entry using an existing `kind`. For a brand-new behaviour, add `handlers.<kind>` in AbilityServer and `play.<kind>` in AbilityVFX.
- Balance: damage per hit 8-25, cooldowns 2-20 s, radius 10-25 studs. Big area moves get long cooldowns.
- If the game also uses the gta-style-game weapon wheel (Tab/Q), change `wheelKey` (e.g. to `G`) so they don't clash.

## Why it works (keep to these rules when adding moves)

- **Server decides, clients draw.** The server checks cooldowns and finds hits (`GetPartBoundsInRadius`, raycasts), applies damage and stuns, then `Effect:FireAllClients(kind, data)`. Clients only make visuals, so it's exploit-safe and smooth. Never trust damage numbers sent from a client.
- **Layers** (from the stylized-VFX video). Every move has:
  1. **core**: one bright, readable main shape (flash, beam, sphere, shockwave);
  2. **detail**: secondary shapes that add style (magic circle, streak lines, rings, dark smoke);
  3. **particles**: sparks or debris for energy;
  4. **feel**: screen tint, camera shake near the hit, damage numbers.

  Build and check each layer separately, then play them together. Offset their timing slightly (anticipation circle first, then the hit about 0.15 s later).
- **Contrast**: pair dark smoke (`LightEmission 0`) with bright neon cores (`LightEmission 1`). Purple-on-black reads much better than purple-on-purple.
- **Performance (phones)**: use `Emit()` bursts instead of always-on emitters, clean up with `Debris`, and keep each move to about 40 particles. Effects live in the `workspace.AbilityVFX` folder.
- **Animations**: for cast animations, use the roblox-animation skill (anticipation pose → fast strike → hold → recover) and play them in `cast()` on the client.

## Reply to the user

A few lines: what was added, where it is in Explorer, and how to test it (Play, then press E R C F T V or tap the buttons; hold Q for the wheel).
