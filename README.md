# Retro Video Store Simulator

A 3D first-person retro VHS video-store simulator built in **Godot 4.6**.
Browse shelves, stock tapes, serve customers, and keep the store running.

---

## Game Concept

You manage a small, dimly lit video-rental store straight out of the 1990s.
Customers walk in, browse the shelves, and bring tapes to the checkout counter.
You restock shelves, rearrange the store layout, and process rentals — all in real time.

---

## Current Implemented Alpha Features

| Feature | Status |
|---|---|
| Physical 3D store building (editor-visible) | ✅ |
| Six genre shelves with VHS tape props | ✅ |
| Player FPS movement + mouse-look | ✅ |
| Tape pickup / carry inventory (max 10) | ✅ |
| Place tapes onto shelves | ✅ |
| Shelf genre labeling (Empty / genre name / Mixed) | ✅ |
| Tapes move with shelf when shelf is moved | ✅ |
| Shelf placement / movement system | ✅ |
| Editor-visible interaction Area3D zones | ✅ |
| Customer AI state machine | ✅ |
| Checkout counter interaction | ✅ |
| Rewind machine | ✅ |
| HUD: carry count + interaction prompts | ✅ |

---

## Building Layout and Editor-Visible Environment

The store is a real scene (`scenes/MainStore.tscn`) containing StaticBody3D nodes
assembled manually in the Godot editor:

- **Floor / Ceiling** — BoxMesh, 12 × 16 m
- **Walls** — BoxMesh panels; a front wall gap forms the entrance
- **Counter** — two BoxMesh bodies near the back (z ≈ -4.2)
- **Rewind Machine** — small BoxMesh on the counter, left side
- **Shelves** — six instances of `scenes/shelf.tscn` placed in the Shelves group
- **Lights** — six OmniLight3D fixtures for the warm store atmosphere

Every object is a real node you can click, move, or resize in the Godot editor.

---

## Shelf Placement / Building System

Select any empty-handed interaction on a shelf to enter **Move Mode**.
A preview tint shows the shelf at its current drag position.

| Input | Action |
|---|---|
| Move mouse | Shelf follows camera-projected ground point |
| **E** | Confirm new position |
| **X** | Cancel — shelf snaps back |

**Tapes travel with the shelf automatically** because placed tapes are children of
the shelf's `TapeContainer` node. No extra code is needed — Godot's scene tree
handles the transform propagation.

---

## Editor-Visible Interaction Areas

Every interactable object in the scene has a dedicated **Area3D** node with a
named `CollisionShape3D` child. These nodes are visible in the editor scene tree
and can be resized/repositioned by hand:

| Node name | Parent | Purpose |
|---|---|---|
| `InteractionArea` / `InteractionShape` | Shelf root | Shelf interact zone |
| `CounterInteractionArea` / `CounterInteractionShape` | Building/Counter | Counter zone |
| `RewindInteractionArea` / `RewindInteractionShape` | Building/RewindMachine | Rewind zone |

**Collision layers:**
- Layer 1 (value 1) — physical world (walls, floor, shelf/counter bodies, player)
- Layer 2 (value 2) — tape StaticBody3D nodes (pickup ray)
- Layer 3 (value 4) — interaction Area3D nodes (interact ray)

The player's RayCast3D uses `collision_mask = 6` and `collide_with_areas = true`
so it detects tapes (layer 2) and interaction zones (layer 3) independently.

---

## How Tapes Are Parented to Shelves

When a tape is placed on a shelf, `shelf.add_tape(tape)` calls
`tape.reparent(tape_container, true)` to make the tape a child of the shelf's
`TapeContainer` node. The tape then has its local position set to a slot offset.

When a tape is removed (player pick-up or customer grab),
`shelf.remove_tape(tape)` calls `tape.reparent(get_tree().current_scene, true)`,
returning the tape to the scene root while preserving its world position.

This means:
- **Move the shelf → tapes move with it** (Godot parent-child transform)
- **Customer grabs a tape → tape detaches cleanly, world position preserved**
- **Player places a tape → tape snaps to the next free slot**

---

## Customer Shelf-Picking Behavior

Customers spawn at the back entrance, pick a random genre, and then:

1. **ENTERING** — walk to a random browse point
2. **SEARCHING** — scan shelves for an exact-genre label match; fall back to "Mixed" shelves that contain the genre; give up if none found
3. **WALKING_TO_SHELF** — navigate to the chosen shelf
4. **PICKING_TAPE** — take one tape from the shelf (shelf data + parent updated)
5. **WALKING_TO_COUNTER** — carry the tape to the counter
6. **WAITING_AT_COUNTER** — wait for the player to press **E**
7. **LEAVING** — exit the store

If no matching tape exists the customer reacts and leaves gracefully.

---

## Player Carry Inventory

The player can hold **up to 10 tapes** at once.

- **Pick up** — look at a tape and press **E**
- **Place on shelf** — look at a shelf (with tapes in hand) and press **E**
- **Drop on counter** — look at the counter and press **E**
- **Rewind all** — look at the rewind machine and press **E**
- Inventory full → a HUD message blocks further pick-ups

---

## Shelf Genre Label Rules

| Contents | Label |
|---|---|
| No tapes | `Empty` |
| All tapes same genre | That genre name (e.g. `Horror`) |
| Mixed genres | `Mixed` |

The label is a billboard `Label3D` that always faces the camera.
It updates immediately whenever tapes are added or removed.

---

## Controls

| Key | Action |
|---|---|
| W / A / S / D | Move |
| Mouse | Look |
| Shift | Sprint |
| **E** | Interact / confirm placement |
| **X** | Cancel shelf move |
| Esc | Release mouse cursor |

---

## How to Run in Godot 4.6

1. Clone or open the project folder in **Godot 4.6**.
2. Open `scenes/MainStore.tscn` as the main scene
   (Project → Project Settings → Application → Run → Main Scene).
3. Press **F5** to play.

> Godot 4.6 is required. Earlier 4.x versions may have minor API differences.

---

## Project Folder Structure

```
project.godot
assets/
scenes/
  MainStore.tscn   ← full store (open this as main scene)
  shelf.tscn       ← shelf unit with TapeContainer + InteractionArea
  tape.tscn        ← VHS tape prop
  customer.tscn    ← AI customer
  player.tscn      ← first-person player
  ui.tscn          ← HUD overlay
scripts/
  main.gd                ← scene root, spawns tapes + customers
  shelf.gd               ← tape storage, genre label, reparenting
  tape.gd                ← tape data + interaction callbacks
  customer.gd            ← customer state machine
  player_controller.gd   ← FPS movement + interaction detection
  carry_inventory.gd     ← 10-tape carry system
  placement_system.gd    ← shelf move / placement mode
  game_manager.gd        ← global rental state
  ui_manager.gd          ← HUD updates
  group_setter.gd        ← utility: add node to group on ready
README.md
```

---

## Known Limitations

- NavigationRegion3D bake must be triggered manually in the editor
  (NavigationRegion3D → Bake NavigationMesh) for customer pathfinding to work.
- Customer navigation may glitch if shelves overlap nav-mesh baked geometry.
- No audio.
- No save system.
- No day/night cycle.
- Only one store layout (no procedural variation).

---

## Future Plans (NOT implemented)

The following features are planned for future milestones and are
**not present in the current build**:

- **Multiplayer** — no networking of any kind exists yet
- **Login / account system** — no authentication or user accounts
- **Database saves** — no persistent data storage or cloud saves
- **Online syncing** — no server-side state
- **Larger store systems** — multiple rooms, employee NPCs, late-fee mechanics
