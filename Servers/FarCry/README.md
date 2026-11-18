# Far Cry Server (Docker)

This image provides a Dockerized **Far Cry** dedicated server. Far Cry (Crytek, 2004) ships a Windows-only dedicated server, `Bin32/FarCry_WinSV.exe` (patch 1.4), which the image runs under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs the retail `FarCry_WinSV.exe` with a server profile, like `DedicatedServer.cmd "SProfile_run <profile>"`
- Server name, port, game type, map, map rotation, limits and passwords are environment variables, written into the profile on every start
- FarCry_WinSV is a GUI app, so it runs on a virtual display (Xvfb). Its log is streamed to `docker logs`
- All-Seeing Eye status queries for monitoring
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  farcry:
    image: lancommander/farcry:latest
    container_name: farcry

    ports:
      - "49001:49001/udp"
      - "49124:49124/udp"
      - "5678:5678/udp"

    volumes:
      - ./config:/config

    environment:
      FC_SERVER_NAME: "My Far Cry Server"
      FC_GAME_TYPE: "TDM"
      FC_MAP: "mp_radio"
      FC_MAPCYCLE: "mp_radio TDM,mp_surf TDM,mp_cliffside TDM"
      FC_RCON_PASSWORD: "changeme"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The same file is in this directory as [`compose.yml`](compose.yml).

---

## Game Files

Far Cry is retail software with no public download. You must provide an install patched to **1.4**, which includes `Bin32/FarCry_WinSV.exe`, `FCData/` and `Levels/`. Clients must be on 1.4 too.

- copy the game folder (the one containing `Bin32/`) to `config/Server/`, **or**
- set `FC_ARCHIVE_URL` to a zip of that folder, e.g. a LANCommander archive. It is downloaded and extracted on first start, if `Server/Bin32/FarCry_WinSV.exe` doesn't exist yet.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Far Cry install (Bin32/, FCData/, Levels/, Profiles/ ...)
    ├── Overlay/           # Your files, layered on top of Server/ (the generated profile and log land here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE#environment).
The `FC_*` server settings are written into `Profiles/server/<FC_PROFILE>_server.cfg` on every start. Settings left empty are not touched, so you can set them in that file instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `FC_PROFILE` | Server profile name (`SProfile_run`) | `LANCommander` |
| `FC_PORT` | Game port (`sv_port`). Status queries use this port + 123 | `49001` |
| `FC_SERVER_NAME` | `sv_name` | `Far Cry Server` |
| `FC_SERVER_TYPE` | `sv_ServerType`: `LAN`, `NET` or `UBI` (Ubi.com is offline) | `LAN` |
| `FC_GAME_TYPE` | `g_GameType`: `FFA`, `TDM` or `ASSAULT`. The map must support it | `FFA` |
| `FC_MAP` | First map (`gr_NextMap`) | `mp_monkeybay` |
| `FC_MAPCYCLE` | Comma-separated rotation of `<map> <game type>` entries, written to `<FC_PROFILE>_mapcycle.txt` (`sv_mapcyclefile`) | the five FFA maps |
| `FC_MAX_PLAYERS` | `sv_maxplayers` | `16` |
| `FC_TIME_LIMIT` | Minutes per map (`gr_TimeLimit`) | `15` |
| `FC_SCORE_LIMIT` | `gr_ScoreLimit`, `0` = none | |
| `FC_RESPAWN_TIME` | Seconds (`gr_RespawnTime`) | |
| `FC_FRIENDLY_FIRE` | `gr_FriendlyFire` | |
| `FC_PASSWORD` | Join password (`sv_password`) | |
| `FC_RCON_PASSWORD` | Remote admin password (`sv_rcon_password`); RCon is off without one | |
| `FC_PUNKBUSTER` | `sv_punkbuster` | `false` |
| `FC_LOG_VERBOSITY` | `log_verbosity`. Below `3` the log doesn't show map loads | `3` |
| `FC_ARCHIVE_URL` | Zip of the game folder, used if `Server/Bin32/FarCry_WinSV.exe` is missing | |
| `WINE_XVFB` | Run on a virtual display. FarCry_WinSV needs one | `true` |
| `START_EXE` | Launcher | `/usr/local/bin/farcry-server` |
| `START_ARGS` | Extra console commands, run before the profile, e.g. `"log_verbosity 3"` | |

Multiplayer maps:

| Game type | Maps |
|-----------|------|
| `FFA`, `TDM` | `mp_cliffside`, `mp_monkeybay`, `mp_monkeybay_n`, `mp_radio`, `mp_surf` |
| `ASSAULT` | `mp_airstrip`, `mp_dam`, `mp_dune`, `mp_freighter`, `mp_jungle`, `mp_mangoriver`, and their `mp_px_*` versions |

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/farcry:local Servers/FarCry
```

---

## License

Far Cry and Wine are distributed under their respective licenses.
This directory contains only Docker build logic and helper scripts licensed under MIT.
