# Rune Server (Docker)

This repository provides a Dockerized **Rune** dedicated server. Rune is a 2000 Viking melee action game by Human Head Studios, built on Unreal Engine 1; the Rune Classic release (1.10) includes the Halls of Valhalla multiplayer expansion. The image runs the retail Windows game's `UCC.exe server` under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers.WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs the retail game's `UCC.exe server` (headless; no X display, graphics or sound)
- A separate server ini (`System/Server.ini`) is created from the game's `Default.ini`, and the common settings are environment variables
- All four game types: Deathmatch, Team, Arena and HeadBall, with short names
- Optional map rotation; maps that aren't installed are left out
- Optional web admin
- The dead GameSpy master server uplink is removed by default
- UCC's console log goes to `docker logs`
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  rune:
    image: lancommander/rune:latest
    container_name: rune

    ports:
      - "7777:7777/udp"
      - "7778:7778/udp"
      - "8777:8777/udp"

    volumes:
      - ./config:/config

    environment:
      RUNE_SERVER_NAME: "My Rune Server"
      RUNE_GAME_TYPE: "deathmatch"
      RUNE_MAP: "DM-Hel"
      RUNE_MAX_PLAYERS: "16"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The in-game LAN browser finds servers by broadcast. That needs the container on the LAN itself (macvlan/ipvlan, or `network_mode: host`). With port mapping, clients join by IP.

---

## Game Files

Rune is retail software with no public download. You must provide a **Rune Classic 1.10** install (GOG or Steam; the folder with `System/UCC.exe`, `System/RuneI.u` and `Maps/`). Clients must run the same version; the server reports `gamever 110`.

- copy that folder's contents (`System/`, `Maps/`, `Textures/` ...) to `config/Server/`, **or**
- set `RUNE_ARCHIVE_URL` to a zip of it, e.g. a LANCommander archive. It is downloaded and extracted on first start, if `Server/System/UCC.exe` doesn't exist yet.

The server doesn't need `Help/`, `Video/`, `redist/`, the manuals or the GOG installer files.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Rune install (System/, Maps/, Textures/ ...)
    ├── Overlay/           # Your files, layered on top of Server/ (System/Server.ini lands here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers.WINE#environment).
The ini settings are written into `RUNE_INI` on every start. Settings left empty are not touched, so you can set them in the ini instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `RUNE_MAP` | Start map | `DM-Hel` |
| `RUNE_GAME_TYPE` | `deathmatch`, `team`, `arena`, `headball` or a game class, see below | `deathmatch` |
| `RUNE_MAPS` | Map rotation, comma separated, written to the game type's map list. Empty: the list in the ini is left alone; an empty list cycles through every installed map with the game type's prefix | |
| `RUNE_URL_OPTIONS` | Extra start map URL options | |
| `RUNE_INI` | Server ini in `System/`, created from `Default.ini` if missing | `Server.ini` |
| `RUNE_PORT` | Game port, `[URL] Port`. The query port is this + 1 | `7777` |
| `RUNE_SERVER_NAME` | `[Engine.GameReplicationInfo] ServerName` | `Rune Server` |
| `RUNE_SHORT_NAME` | `[Engine.GameReplicationInfo] ShortName` | `Rune Server` |
| `RUNE_ADMIN_NAME` | `[Engine.GameReplicationInfo] AdminName` | |
| `RUNE_ADMIN_EMAIL` | `[Engine.GameReplicationInfo] AdminEmail` | |
| `RUNE_MOTD` | `[Engine.GameReplicationInfo] MOTDLine1` | |
| `RUNE_MAX_PLAYERS` | `[Engine.GameInfo] MaxPlayers` | `16` |
| `RUNE_MAX_SPECTATORS` | `[Engine.GameInfo] MaxSpectators` | |
| `RUNE_GAME_PASSWORD` | `[Engine.GameInfo] GamePassword` | |
| `RUNE_ADMIN_PASSWORD` | `[Engine.GameInfo] AdminPassword`, and the web admin password | |
| `RUNE_FRAG_LIMIT` | `[RuneI.RuneMultiPlayer] FragLimit` (all game types) | |
| `RUNE_TIME_LIMIT` | `[RuneI.RuneMultiPlayer] TimeLimit` in minutes (all game types) | |
| `RUNE_GOAL_TEAM_SCORE` | Team/HeadBall `GoalTeamScore` | |
| `RUNE_FRIENDLY_FIRE_SCALE` | Team/HeadBall `FriendlyFireScale`, 0 to 1 | |
| `RUNE_HARDCORE` | `true`/`false`: `bHardCoreMode` | |
| `RUNE_MEGA_SPEED` | `true`/`false`: `bMegaSpeed` (1.5x movement) | |
| `RUNE_LIMB_SEVER` | `true`/`false`: `bAllowLimbSever`, for every game type | |
| `RUNE_WEB_ADMIN` | `true` turns on the web admin (`/ServerAdmin`) | `false` |
| `RUNE_WEB_ADMIN_PORT` | Web admin TCP port | `8080` |
| `RUNE_WEB_ADMIN_USER` | Web admin user name | `admin` |
| `RUNE_MASTER_SERVER_UPLINK` | `true` sends heartbeats to 333networks (`master.333networks.com`) for an internet listing | `false` |
| `RUNE_ARCHIVE_URL` | Zip of the game folder, used if `Server/System/UCC.exe` is missing | |
| `WINE_XVFB` | UCC needs no display | `false` |
| `START_EXE` | Launcher | `/usr/local/bin/rune-server` |
| `START_ARGS` | Appended to the UCC command line | |

Game types:

| `RUNE_GAME_TYPE` | Game class | Map list | Maps |
|------------------|------------|----------|------|
| `deathmatch` | `RuneI.RuneMultiPlayer` | `RuneI.DMmaplist` | `DM-*` |
| `team` | `RuneI.TeamGame` | `RuneI.DMmaplist` | `DM-*` (team starts in `DM-TEAM_*`) |
| `arena` | `Arena.ArenaGameInfo` | `Arena.ARMapList` | `AR-*` |
| `headball` | `HeadBall.HeadBallGame` | `HeadBall.HBmaplist` | `HB-*` |

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/rune:local .
```

---

## License

Rune and Wine are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
