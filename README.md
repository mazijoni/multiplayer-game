# The Backrooms — First-Person Horror

A first-person survival horror game built in **Godot 4.6** inspired by the
**Backrooms** creepypasta. You wake up alone inside an infinite labyrinth of
yellow-wallpapered rooms and buzzing fluorescent lights. Something is already
in there with you.

---

## Game Concept

The Backrooms are an endless, procedurally generated maze of connected rooms
and corridors. Every run is different. The environment is designed to feel
*liminal* — uncanny, empty, and deeply wrong. There is no objective except
survival. There is no map. There is no escape.

---

## Features

| Feature | Status |
|---|---|
| Procedurally generated Backrooms maze (drunk-walk algorithm) | ✅ |
| First-person movement with weighted acceleration / deceleration | ✅ |
| Stamina-based sprinting — exhaust yourself and slow to a walk | ✅ |
| Smooth crouch with capsule height lerp | ✅ |
| Head bob (frequency scales with speed) | ✅ |
| Camera sway tied to mouse inertia | ✅ |
| Sanity system — proximity to monster darkens the screen | ✅ |
| Monster AI — patrol → alerted → search → chase → kill | ✅ |
| Sound-driven monster alerting (footstep radius) | ✅ |
| Flickering fluorescent lights | ✅ |
| Atmospheric fog and near-black ambient light | ✅ |
| HUD — stamina bar, sanity vignette, death screen | ✅ |
| Scene reload on death | ✅ |

---

## Controls

| Input | Action |
|---|---|
| W / A / S / D | Move |
| Mouse | Look |
| Shift | Sprint (drains stamina) |
| Ctrl | Hold to crouch |
| Esc | Release mouse cursor |

> **Tip:** Crouch and walk slowly to avoid alerting the monster.
> Sprinting is loud and visible — it will hear you from 20 m away.

---

## How to Run

1. Clone or open the project folder in **Godot 4.6**.
2. Set `scenes/main.tscn` as the main scene
   *(Project → Project Settings → Application → Run → Main Scene)*.
3. Press **F5** to play.

> The NavMesh is baked at runtime automatically. There is a brief
> freeze on first load while the navigation mesh generates.

---

## Monster AI

The monster uses a five-state finite state machine:

```
PATROL ──► ALERTED ──► SEARCHING ──► PATROL
			  │                          ▲
			  └──────────────────────────┘
			  │
			  ▼
		   CHASING ──► KILLING (game over)
			  │
			  └──► SEARCHING  (player broke LOS)
```

| State | Behaviour |
|---|---|
| **PATROL** | Walks a loop of waypoints; pauses briefly at each one |
| **ALERTED** | Heard a footstep; moves toward last known position |
| **SEARCHING** | Sweeps random offsets around last known position for 12 s |
| **CHASING** | Saw the player; sprints directly at them (8.5 m/s) |
| **KILLING** | Reached the player — triggers death and scene reload |

### Detection rules
- **Sight** — 90 ° FOV cone, 20 m range, blocked by walls (raycast)
- **Hearing (walk)** — detects footsteps within **8 m**
- **Hearing (sprint)** — detects footsteps within **20 m**
- Crouching produces **no footstep events** at all

---

## Procedural Generation

The level is built at runtime using a **drunk-walk algorithm**:

1. Start from the centre of a 24 × 24 grid.
2. Take 200 random steps (N/S/E/W), marking each cell as a room.
3. For every room cell, place floor + ceiling + walls on any side
   that has **no adjacent room** (open doorways appear automatically).
4. Add a flickering `OmniLight3D` to roughly every third room.
5. Bake the `NavigationRegion3D` asynchronously; spawn entities when done.

Each run produces a unique, naturally winding layout with dead ends,
long corridors, and open areas — all using the same material set.

---

## Project Structure

```
project.godot
scenes/
  main.tscn                ← entry point (room generator + nav region)
  player/
	player.tscn            ← CharacterBody3D + camera rig + flashlight
  enemy/
	monster.tscn           ← CharacterBody3D + NavigationAgent3D
  ui/
	hud.tscn               ← CanvasLayer (HUD built in code)
scripts/
  game_manager.gd          ← autoload: cross-system signals
  player_controller.gd     ← FPS movement, stamina, head-bob, sway, crouch
  sanity_system.gd         ← sanity meter → vignette/HUD
  monster_ai.gd            ← 5-state AI (patrol/alert/search/chase/kill)
  room_generator.gd        ← drunk-walk maze builder + entity spawner
  flickering_light.gd      ← per-light flicker behaviour
  hud_manager.gd           ← stamina bar, sanity vignette, death label
assets/
  audio/                   ← (placeholder — add footstep/ambient SFX here)
  textures/                ← (placeholder — add PBR texture sets here)
README.md
```

---

## Known Limitations

- No audio yet — add `AudioStreamPlayer3D` nodes for footsteps and ambience.
- Navigation mesh bake causes a brief freeze on scene load.
- Shadows are disabled on room lights to keep frame rate manageable;
  enable `shadow_enabled = true` in `room_generator.gd` for better visuals.
- Monster mesh is a placeholder box — replace `monster.tscn` mesh with a
  real animated character.

---

## Future Plans

- [ ] Ambient audio (looping hum, distant footsteps, whispers at low sanity)
- [ ] Multiple monster types
- [ ] Items to collect (notes, keys, batteries)
- [ ] Flashlight battery drain
- [ ] More room variety (wider rooms, narrow crawlways, stairwells)
- [ ] Procedural level expansion as the player walks (infinite generation)
