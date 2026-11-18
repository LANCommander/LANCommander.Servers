# America's Army Server (Docker)

This repository provides a Dockerized **America's Army 2.8.5** dedicated server (U.S. Army, 2009, Unreal Engine 2). The image runs the retail Windows game's `System/Server.exe` under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers.WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs the retail game's `Server.exe` (a console program; no X display, graphics or sound)
- The common `server.ini` settings are environment variables
- Map rotation from a comma-separated list; maps that aren't installed are left out
- The GameSpy query address is set to the container's own IP, so the LAN browser sees it
- The server's console log goes to `docker logs`
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  americasarmy:
    image: lancommander/americasarmy:latest
    container_name: americasarmy

    ports:
      - "1716:1716/udp"
      - "7778:7778/udp"

    volumes:
      - ./config:/config

    environment:
      AA_SERVER_NAME: "My America's Army Server"
      AA_MAP: "Bridge"
      AA_MAPS: "Bridge,Border,Pipeline,SFhospital,Steamroller"
      AA_ADMIN_PASSWORD: "changeme"

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

America's Army 2.x is no longer distributed. You must provide an **America's Army 2.8.5** install (the folder with `System/Server.exe`, `System/AGP.u` and `Maps/`). Clients must run the same version.

- copy that folder's contents (`System/`, `Maps/`, `Textures/` ...) to `config/Server/`, **or**
- set `AA_ARCHIVE_URL` to a zip of it, e.g. a LANCommander archive. It is downloaded and extracted on first start, if `Server/System/Server.exe` doesn't exist yet. The shallowest folder holding `System/Server.exe` is used.

The server doesn't need `Movies/`, `Music/` or `Help/`, but they do no harm.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # America's Army install (System/, Maps/, Textures/ ...)
    ├── Overlay/           # Your files, layered on top of Server/ (System/server.ini and server.log land here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers.WINE#environment).
The ini settings are written into `AA_INI` on every start. Settings left empty are not touched, so you can set them in the ini instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `AA_MODE` | Server mode, the first `Server.exe` argument: `LAN`, `LANTOURNAMENT`, `LANETA`, `LANETATOURNAMENT` (`GLOBAL`/`TOURNAMENT` need the defunct auth servers) | `LAN` |
| `AA_MAP` | Start map (`.aao` is optional) | `Bridge` |
| `AA_URL_OPTIONS` | Extra map URL options, appended as `?...` | |
| `AA_INI` | Server ini in `System/`. Created from `server.ini` if it's another name and missing | `server.ini` |
| `AA_PORT` | Game port, `[URL] Port` | `1716` |
| `AA_SERVER_NAME` | `[Engine.GameReplicationInfo] ServerName` | `America's Army Server` |
| `AA_ADMIN_NAME` | `[Engine.GameReplicationInfo] AdminName` | |
| `AA_ADMIN_EMAIL` | `[Engine.GameReplicationInfo] AdminEmail` | |
| `AA_MOTD` | `[Engine.GameReplicationInfo] MOTDLine1` | |
| `AA_MAX_PLAYERS` | `[Engine.GameInfo] MaxPlayers` (stock: 26) | |
| `AA_TIME_LIMIT` | `[Engine.GameInfo] TimeLimit`, round length in minutes (stock: 10) | |
| `AA_ROUNDS_PER_MATCH` | `[AGP_Gameplay.AGP_GameDeathMatch] RoundsPerMatch` (stock: 7) | |
| `AA_GAME_PASSWORD` | `[Engine.AccessControl] GamePassword` | |
| `AA_ADMIN_PASSWORD` | `[Engine.AccessControl] AdminPassword`. **The stock value is `goarmy`**; set this | |
| `AA_MAPS` | Map rotation, comma separated (`.aao` is optional). Rewrites `[AGP_Gameplay.AGP_MapList]` and turns on `bCycleMaps` when it has more than one map | |
| `AA_GAMESPY_IP` | `[IpDrv.GameSpyQR] IP`. Empty uses the container's first IPv4 address | |
| `AA_ARCHIVE_URL` | Zip of the game folder, used if `Server/System/Server.exe` is missing | |
| `WINE_XVFB` | Server.exe needs no display | `false` |
| `START_EXE` | Launcher | `/usr/local/bin/aa-server` |
| `START_ARGS` | Appended to the `Server.exe` command line | |

Maps in 2.8.5: `Border`, `Bridge`, `Bridge_SE`, `BRM_Range`, `camp_mackall`, `Canyon`, `District`, `Dusk`, `Eagle_Tower`, `EandE`, `ES2Border`, `ES2Bridge`, `ES2McKenna`, `Insurgent_Camp`, `Interdiction`, `Leavenworth`, `MOUT_McKenna`, `Pipeline`, `Pipeline_SF`, `Rummage`, `SFCourtyard`, `SFcsar`, `SFDockside`, `SFextraction`, `SFhospital`, `SFHospitalSE`, `SFSnakePlain`, `SMU_GH_SFFloodgate`, `Steamroller`, `Tunnel`, `Urban_Assault`, `Weapons_Cache`. The rest (`*_Range`, `*_Training*`, `Jump_Tower`, `Medic_*` ...) are single-player training maps.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/americasarmy:local .
```

---

## License

America's Army and Wine are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
