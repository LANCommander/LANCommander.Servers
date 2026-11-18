# Devastation Server (Docker)

This image provides a Dockerized **Devastation** dedicated server. Devastation is a 2003 multiplayer shooter by Digitalo Studios, built on Unreal Engine 2. The image runs the retail Windows game's `UCC.exe server` under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs the retail game's `UCC.exe server` (headless; no X display, graphics or sound)
- A separate server ini (`System/Server.ini`) is created from the game's `Default.ini`, and the common settings are environment variables
- All four game types: Territories, CTF, StreetWar and Team StreetWar, with short names
- The map rotation can mix game types, and maps that aren't installed are left out
- The master server uplinks are removed by default
- UCC's console log goes to `docker logs`
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  devastation:
    image: lancommander/devastation:latest
    container_name: devastation

    ports:
      - "7777:7777/udp"
      - "7787:7787/udp"
      - "7900:7900/udp"
      - "8777:8777/udp"

    volumes:
      - ./config:/config

    environment:
      DEVASTATION_SERVER_NAME: "My Devastation Server"
      DEVASTATION_GAME_TYPE: "territories"
      DEVASTATION_MAP: "DTT-Union"
      DEVASTATION_MAX_PLAYERS: "16"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The same file is in this directory as [`compose.yml`](compose.yml).

The in-game LAN browser finds servers by broadcast. That needs the container on the LAN itself (macvlan/ipvlan, or `network_mode: host`). With port mapping, clients join by IP.

---

## Game Files

Devastation is retail software with no public download. You must provide a **version 390** install (the folder with `System/UCC.exe`, `System/DCore.u` and `Maps/`). Clients must run the same version; the server reports `gamever 3069`.

- copy that folder's contents (`System/`, `Maps/`, `Textures/` ...) to `config/Server/`, **or**
- set `DEVASTATION_ARCHIVE_URL` to a zip of it, e.g. a LANCommander archive. It is downloaded and extracted on first start, if `Server/System/UCC.exe` doesn't exist yet.

The server doesn't need `Movies/`, `Help/`, `Tools/`, `ExtraIcons/`, `Resources/` or `System/editorres/`.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Devastation install (System/, Maps/, Textures/ ...)
    ├── Overlay/           # Your files, layered on top of Server/ (System/Server.ini lands here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created); server.log and User.ini are in
    │                      #   drive_c/users/<user>/Documents/Devastation/
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE#environment).
The ini settings are written into `DEVASTATION_INI` on every start. Settings left empty are not touched, so you can set them in the ini instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `DEVASTATION_MAP` | Start map | `DTT-Union` |
| `DEVASTATION_GAME_TYPE` | Game type of the start map: `territories`, `ctf`, `streetwar`, `teamstreetwar` or a game class, see below | `territories` |
| `DEVASTATION_MAPS` | Map rotation, comma separated. An entry may name its game type, `DDM-Mental:teamstreetwar`; otherwise it comes from the map prefix. Empty: every installed map for `DEVASTATION_GAME_TYPE` | |
| `DEVASTATION_URL_OPTIONS` | Extra start map URL options, e.g. `Bots=4` | |
| `DEVASTATION_INI` | Server ini in `System/`, created from `Default.ini` if missing | `Server.ini` |
| `DEVASTATION_PORT` | Game port, `[URL] Port`. The query ports are this + 10 and + 123 | `7777` |
| `DEVASTATION_SERVER_NAME` | `[Engine.GameReplicationInfo] ServerName` | `Devastation Server` |
| `DEVASTATION_SHORT_NAME` | `[Engine.GameReplicationInfo] ShortName` | `Devastation Server` |
| `DEVASTATION_ADMIN_NAME` | `[Engine.GameReplicationInfo] AdminName` | |
| `DEVASTATION_ADMIN_EMAIL` | `[Engine.GameReplicationInfo] AdminEmail` | |
| `DEVASTATION_MOTD` | `[Engine.GameReplicationInfo] MOTDLine1` | |
| `DEVASTATION_MAX_PLAYERS` | `[Engine.GameInfo] MaxPlayers` | `16` |
| `DEVASTATION_GAME_PASSWORD` | `[Engine.GameInfo] GamePassword` | |
| `DEVASTATION_ADMIN_PASSWORD` | `[Engine.GameInfo] AdminPassword` | |
| `DEVASTATION_TIME_LIMIT` | `TimeLimit` in minutes, for every game type | |
| `DEVASTATION_FRAG_LIMIT` | `FragLimit` (frags; flag captures in CTF), for every game type | |
| `DEVASTATION_ROUND_LIMIT` | Territories `RoundLimit` | |
| `DEVASTATION_ROUND_TIME_LIMIT` | Territories `TimeLimitRound`, in seconds | |
| `DEVASTATION_SUDDEN_DEATH_SECONDS` | Territories `SuddenDeathSeconds` | |
| `DEVASTATION_BOTS` | `[DCore.DGameInfo] InitialBots` | |
| `DEVASTATION_SIMULATION` | `true` for Simulation mode, `false` for Arcade (`GameMode`) | |
| `DEVASTATION_FULL_PHYSICS` | `true` for full Karma physics (`bKarmaMP`) | |
| `DEVASTATION_MASTER_SERVER_UPLINK` | `true` adds the GameSpy uplink to OpenSpy (`master.openspy.com`) for an internet listing | `false` |
| `DEVASTATION_ARCHIVE_URL` | Zip of the game folder, used if `Server/System/UCC.exe` is missing | |
| `WINE_XVFB` | UCC needs no display | `false` |
| `START_EXE` | Launcher | `/usr/local/bin/devastation-server` |
| `START_ARGS` | Appended to the UCC command line | |

Game types:

| `DEVASTATION_GAME_TYPE` | Game class | Maps |
|-------------------------|------------|------|
| `territories` | `DTerritories.DTerrGameInfo` | `DTT-*` |
| `ctf` | `DTerritories.DCTFGameInfo` | `CTF-*` |
| `streetwar` (deathmatch) | `DGamePlay.DStreetWarGameInfo` | `DDM-*` |
| `teamstreetwar` (team deathmatch) | `DGamePlay.DTeamStreetWarGI` | `DDM-*` |

Retail 390 maps: `DTT-DowntownChozo`, `DTT-RiversOfWaste`, `DTT-TopOTheTower`, `DTT-Transit`, `DTT-Union`, `CTF-Chozo`, `CTF-Union`, `DDM-CarnyTown`, `DDM-EmbarcaderoDepot`, `DDM-Mental`, `DDM-Parking`, `DDM-ParkingXL`, `DDM-RiversOfWaste`, `DDM-Sniper`.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/devastation:local Servers/Devastation
```

---

## License

Devastation and Wine are distributed under their respective licenses.
This directory contains only Docker build logic and helper scripts licensed under MIT.
