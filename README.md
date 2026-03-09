# Hide the Body

A cooperative multiplayer physics-based comedy game built in Godot 4. 2–6 players must secretly move and hide a ragdoll body before NPCs discover it — all while fighting clumsy controls and chaotic physics.

The game server runs on a Raspberry Pi, and player stats (wins, rounds played) are stored in a MariaDB database so the leaderboard persists between sessions.

---

## Game Concept

You and your friends have accidentally caused a fatal incident. Panic sets in. You have only a few minutes to move the body somewhere believable before a neighbor, security guard, or passing pedestrian notices. The body is heavy, floppy, and completely uncooperative. So are your friends.

The focus is on absurd cooperative chaos — limbs caught in doorways, bodies sliding down stairs, players arguing about the plan while the timer ticks down.

### Planned Features

- [ ] Ragdoll body physics (floppy, heavy, reacts to gravity and collisions)
- [ ] Cooperative grab/drag/carry mechanics (multiple players required for heavy lifting)
- [ ] NPC patrol routines with suspicion system
- [ ] Suspicion triggers (running with body, loud noises, open doors, visible body parts)
- [ ] Multiple maps: apartment, office, hotel, school, house party
- [ ] Hiding spots: closets, dumpsters, lockers, containers, storage rooms
- [ ] Round timer with escalating tension (more NPCs, investigators near the end)
- [ ] Random events each round (different body spawn, NPC schedules, random incidents)
- [ ] Persistent player stats (wins, rounds played) stored in MariaDB
- [ ] Leaderboard screen
- [ ] Stylized/cartoon visual style

---

## Architecture

```
[ Player PC ]  ──────────────────────────────────────────┐
[ Player PC ]  ──── ENet (port 6767) ────►  [ Raspberry Pi Server ]
[ Player PC ]                                    │
[ Player PC ]                                    ▼
                                         [ MariaDB Database ]
                                         - players table
                                         - rounds table
                                         - stats table
```

### Server (Raspberry Pi)

The game server runs on a Raspberry Pi as a headless Godot export. It is the authoritative host for all game sessions — all clients connect to it rather than peer-to-peer.

- **Protocol**: ENet over UDP
- **Port**: `6767`
- **Mode**: Headless (no display required)
- **Startup**: Runs as a systemd service on the Pi so it restarts automatically on reboot

### Database (MariaDB)

MariaDB runs on the same Raspberry Pi as the game server. The server writes to the database after each round ends.

**Planned schema:**

```sql
CREATE TABLE players (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    display_name  VARCHAR(64) NOT NULL UNIQUE,
    created_at    DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE rounds (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    played_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
    winner_id   INT REFERENCES players(id)
);

CREATE TABLE stats (
    player_id     INT PRIMARY KEY REFERENCES players(id),
    rounds_played INT DEFAULT 0,
    wins          INT DEFAULT 0
);
```

---

## Gameplay

### Round Flow

1. Players connect to the lobby on the Pi server
2. A map and body spawn location are randomly selected
3. The round timer starts — players must hide the body before time runs out
4. NPCs patrol the map following daily routines
5. If an NPC discovers the body → **round lost**
6. If the body is hidden and players act normal until the timer ends → **round won**
7. Stats (win/loss, round count) are written to the MariaDB database

### Controls (current prototype)

| Action  | Key    |
|---------|--------|
| Move    | WASD   |
| Look    | Mouse  |
| Sprint  | Shift  |
| Crouch  | Ctrl   |
| Jump    | Space  |
| Pause   | Escape |

> Grab, carry, and drop mechanics are planned for the body interaction system.

### NPC Suspicion System

NPCs follow patrol routes but react to suspicious behaviour:

| Trigger                        | Suspicion Level |
|-------------------------------|-----------------|
| Visible body / body part       | High            |
| Player running while carrying  | Medium          |
| Loud noise nearby              | Medium          |
| Door left open                 | Low             |
| Player staring at hiding spot  | Low             |

When suspicion fills, the NPC will investigate. If they find the body, the round ends.

---

## Project Structure

```
multiplayer game/
├── assets/          # Audio and other assets
├── autoload/        # Global singletons
├── debug/           # Debug tools and overlays
├── export/          # Exported builds (including headless Pi build)
├── scenes/
│   ├── world.tscn   # Main game world and lobby
│   └── player.tscn  # Player prefab
├── scripts/
│   ├── world.gd     # Networking, lobby, and spawn logic
│   └── player.gd    # First-person controller and replication
├── textures/        # Texture assets
└── project.godot
```

---

## Running the Server on Raspberry Pi

1. **Export** a Linux headless build from Godot (`Project → Export → Linux Headless`).
2. **Copy** the build to the Pi.
3. **Install MariaDB** on the Pi and run the schema above.
4. **Create a systemd service** (e.g. `/etc/systemd/system/game-server.service`):

```ini
[Unit]
Description=Godot Multiplayer Game Server
After=network.target mariadb.service

[Service]
ExecStart=/home/pi/game-server/game.x86_64 --headless
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
```

5. **Enable and start** the service:

```bash
sudo systemctl enable game-server
sudo systemctl start game-server
```

---

## Connecting as a Client

1. Launch the game on your PC.
2. Enter the Pi's IP address in the **Join** field.
3. Click **Join** — you will enter the lobby.
4. Wait for the host to start the match.

---

## Development Status

Early prototype stage. The multiplayer framework is functional — players can connect to the Pi server, join a lobby, and move around a shared 3D world with position replication.

**Next steps:**
- Ragdoll body physics and grab/carry mechanics
- NPC patrol and suspicion system
- First playable map with hiding spots
- Round timer and win/lose logic
- MariaDB integration for stat tracking
