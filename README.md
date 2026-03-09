# Multiplayer FPS Game

A 3D first-person shooter built in Godot 4, designed around a dedicated server running on a Raspberry Pi. Players connect to the server over the local network (or internet), compete in arena matches, and have their stats tracked in a MariaDB database.

---

## Game Concept

Fast-paced, arena-style multiplayer FPS. Players join a lobby, the host starts the match, and everyone spawns into the arena to compete. The server tracks wins and rounds played per player — so the leaderboard persists between sessions.

### Planned Features

- [ ] Player shooting and health system
- [ ] Round-based match flow (round start → combat → round end → next round)
- [ ] Kill feed and scoreboard in-game
- [ ] Persistent player stats (wins, rounds played) stored in MariaDB
- [ ] Leaderboard screen showing top players
- [ ] Player customization (name, possibly skin color)
- [ ] Sound effects and visual feedback for hits/kills

---

## Architecture

```
[ Player PC ]  ──────────────────────────────────────────┐
[ Player PC ]  ──── ENet (port 6767) ────►  [ Raspberry Pi Server ]
[ Player PC ]                                    │
                                                 ▼
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

| Action      | Key              |
|-------------|------------------|
| Move        | WASD             |
| Look        | Mouse            |
| Sprint      | Shift            |
| Crouch      | Ctrl             |
| Jump        | Space            |
| Pause / ESC | Escape           |

### Player Movement

| State  | Speed     |
|--------|-----------|
| Walk   | 5 m/s     |
| Sprint | 10 m/s    |
| Crouch | 2.5 m/s   |

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

This project is in early prototype stage. The multiplayer framework is functional (connect, lobby sync, player spawning and replication). Next steps are implementing shooting, health, round logic, and database integration.
