# City Climb

A multiplayer physics-based climbing and traversal game built in **Godot 4**.  
2–8 players must climb, stumble, and navigate a vertical city using intentionally awkward physics-based controls inspired by chaotic physics games.

The goal is simple: **reach the top of the city**.

The problem is that your character is extremely hard to control.

The game server runs on a **Raspberry Pi**, and player stats (wins, height reached, rounds played) are stored in a **MariaDB database** so progress and leaderboard rankings persist between sessions.

---

## Game Concept

Players spawn at the bottom of a dense city filled with rooftops, scaffolding, cranes, construction sites, and unstable physics objects.

Your objective is to **climb higher than everyone else**.

However, movement is intentionally awkward:

- Characters are physics-driven
- Balance and momentum matter
- Grabbing objects is unreliable
- Players can easily fall

The result is chaotic, funny gameplay where players:

- slip off ledges
- knock each other down
- grab the wrong object
- fall multiple floors
- barely recover impossible jumps

---

## Planned Features

- Physics-based player controller with awkward movement
- Multiplayer-only gameplay (2–8 players)
- Large vertical city map
- Rooftop traversal and ledge grabbing
- Moving obstacles (cranes, elevators, swinging signs)
- Checkpoints or respawn system
- Competitive race mode
- Cooperative climbing mode
- Chaos mode with random hazards
- Persistent player stats stored in MariaDB
- Leaderboard system
- Stylized cartoon-like visuals

---

## Architecture

```
[ Player PC ] ──────────────────────────────────────────┐
[ Player PC ] ──── ENet (port 6767) ────► [ Raspberry Pi Server ]
[ Player PC ] │
[ Player PC ] ▼
			  [ MariaDB Database ]
				- players table
				- matches table
				- stats table
```

---

## Server (Local or Raspberry Pi)

The game server runs as a **headless Godot export** and can be hosted in two ways:

- **Local machine** — run the server directly on a PC on the same network, useful for quick sessions and testing
- **Raspberry Pi** — run the server as a persistent, always-on dedicated server for longer-running sessions

It acts as the **authoritative server**, meaning all clients connect to it.

- Protocol: ENet over UDP
- Port: `6767`
- Mode: Headless (no display required)

When hosted on a Raspberry Pi, the server runs as a **systemd service**, automatically restarting if the Pi reboots.

---

## Database (MariaDB)

MariaDB runs on the same Raspberry Pi as the server.

The game writes match results and player statistics after each round.

### Example Schema

```sql
CREATE TABLE players (
	id INT AUTO_INCREMENT PRIMARY KEY,
	display_name VARCHAR(64) NOT NULL UNIQUE,
	created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE matches (
	id INT AUTO_INCREMENT PRIMARY KEY,
	played_at DATETIME DEFAULT CURRENT_TIMESTAMP,
	winner_id INT NULL,
	max_height FLOAT DEFAULT 0
);

CREATE TABLE stats (
	player_id INT PRIMARY KEY,
	rounds_played INT DEFAULT 0,
	wins INT DEFAULT 0,
	best_height FLOAT DEFAULT 0,
	total_falls INT DEFAULT 0
);
```

---

## Gameplay

### Match Flow

1. Players connect to the lobby.
2. A city map is selected.
3. Players spawn at the bottom of the map.
4. The match begins.
5. Players climb and navigate obstacles.
6. The highest player or first to the goal wins.
7. Stats are saved to the MariaDB database.

### Controls (Prototype)

| Action | Key |
|--------|-----|
| Move | WASD |
| Look | Mouse |
| Jump | Space |
| Grab Left Hand | Q |
| Grab Right Hand | E |
| Sprint | Shift |
| Stabilize | Ctrl |
| Interact | F |
| Quit | Escape |

> Controls may change depending on how the physics system evolves.

---

## Game Modes

### Race Mode
Players race to reach the top first.

### Survival Mode
Hazards increase over time and players are eliminated if they fall.

### Co-op Climb Mode
Players work together to overcome difficult obstacles.

### Chaos Mode
Random events and physics hazards create maximum chaos.

---

## Environment Ideas

The city acts as a giant vertical playground. Possible structures include:

- Rooftops
- Fire escapes
- Billboards
- Construction cranes
- Scaffolding
- Air vents
- Hanging cables
- Pipes
- Water towers
- Apartment windows
- Neon signs

Each area should feel risky, climbable, and chaotic.

---

## Physics Design Goals

The movement should feel:

- Awkward
- Funny
- Unstable
- Skill-based over time
- Frustrating but rewarding

Players should feel like they are constantly barely in control.

---

## Project Structure

```
multiplayer-game/
├── export/
├── scenes/
│   ├── world.tscn
│   ├── player.tscn
│   ├── obstacles/
│   └── props/
├── scripts/
│   ├── world.gd
│   ├── player.gd
│   ├── obstacle.gd
│   └── database.gd
├── export_presets.cfg
├── icon.svg
└── project.godot
```

---

## Running the Server on Raspberry Pi

1. Export a Linux headless build from Godot.
2. Copy it to the Pi and create a systemd service.

```ini
[Unit]
Description=City Climb Server
After=network.target mariadb.service

[Service]
ExecStart=/home/pi/game-server/game.x86_64 --headless
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
```

3. Enable the service:

```bash
sudo systemctl enable game-server
sudo systemctl start game-server
```

---

## Connecting as a Client

1. Launch the game.
2. Enter the Raspberry Pi IP address.
3. Click **Join**.
4. Wait in the lobby until the match starts.

---

## Development Status

Early prototype stage.

### Current Progress

- Multiplayer framework working
- Player movement prototype
- Raspberry Pi server hosting

### Next Steps

- Build the physics-based player controller
- Add grabbing and climbing mechanics
- Create the first vertical city map
- Add obstacles and hazards
- Implement match win conditions
- Add database stat tracking
- Build leaderboard system