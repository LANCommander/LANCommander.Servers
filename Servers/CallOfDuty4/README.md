# Call of Duty 4: Modern Warfare Server (Docker)

This repository provides a Dockerized **Call of Duty 4: Modern Warfare** dedicated server. It runs the official 1.7 Linux dedicated server (`cod4_lnxded`) with your retail Call of Duty 4 game data.
The image builds on [`lancommander/base`](https://github.com/LANCommander/LANCommander.Servers.Base). It supports file overlaying using OverlayFS.

---

## Features

- Official Call of Duty 4 1.7 Linux dedicated server, downloaded on first start and verified by SHA256
- The server's name, game type, map rotation, limits and passwords are environment variables, written into a config file the server execs at startup
- LAN mode by default (`dedicated 1`)
- Optional HTTP fast download of mod files (`sv_wwwDownload`) from the base image's nginx
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  callofduty4:
    image: lancommander/callofduty4:latest
    container_name: callofduty4

    ports:
      - "28960:28960/udp"

    volumes:
      - ./config:/config

    environment:
      COD4_SERVER_NAME: "My Call of Duty 4 Server"
      COD4_GAME_TYPE: "war"
      COD4_RCON_PASSWORD: "changeme"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The in-game LAN browser finds servers by broadcast. That needs the container on the LAN itself (macvlan/ipvlan, or `network_mode: host`); with port mapping, clients join by IP (`connect <ip>:28960` in the console).

---

## Game Files

The image contains no game data. Copy a retail Call of Duty 4 install, patched to 1.7, into `config/Server/`: at least `localization.txt`, the `.iwd` files in `main/` (`iw_00.iwd` to `iw_13.iwd` and `localized_english_iw00.iwd` to `localized_english_iw06.iwd`) and the whole `zone/` folder. `main/video/`, the Windows executables, `DirectX/`, `Docs/` and the rest aren't needed (about 5 GB remains). The server stops with an error if `main/iw_00.iwd` or `zone/english/common_mp.ff` is missing.

On first start the image downloads the Linux server (`cod4_lnxded`) into `config/Server/`, next to the game data. Clients need Call of Duty 4 1.7.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Retail game data (main/*.iwd, zone/, localization.txt) plus cod4_lnxded
    ├── Overlay/           # Your files, layered on top of Server/ (main/server.cfg, generated lancommander.cfg, logs)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [base image's variables](https://github.com/LANCommander/LANCommander.Servers.Base#environment).
The settings are written into `<COD4_FS_GAME or main>/lancommander.cfg` on every start. Settings left empty are left out, so you can set them in `server.cfg` instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `COD4_SERVER_URL` | Linux dedicated server package (`.tar.xz`/`.tar.gz`/`.tar.bz2`/`.zip` with `cod4_lnxded` at its root). Changing it reinstalls | this repo's `server-1.7` release |
| `COD4_SERVER_SHA256` | Expected SHA256 of the package (empty skips the check) | SHA256 of the `server-1.7` package |
| `COD4_PORT` | `net_port` (game port) | `28960` |
| `COD4_LAN` | `true` runs `dedicated 1` (LAN); `false` runs `dedicated 2` (internet, CD key checks against the Activision master server) | `true` |
| `COD4_FS_GAME` | Mod folder (`fs_game`), e.g. `mods/mymod` | |
| `COD4_SERVER_NAME` | `sv_hostname` | `Call of Duty 4 Server` |
| `COD4_MOTD` | `scr_motd` | |
| `COD4_MAX_PLAYERS` | `sv_maxclients` | `24` |
| `COD4_PASSWORD` | `g_password` | |
| `COD4_RCON_PASSWORD` | `rcon_password` | |
| `COD4_GAME_TYPE` | `g_gametype`: `dm`, `war`, `sd`, `sab`, `dom` or `koth` | `war` |
| `COD4_MAPS` | Map rotation, comma- or space-separated, all played as `COD4_GAME_TYPE` (`sv_mapRotation`). The server starts on the first map | all 21 stock maps |
| `COD4_TIME_LIMIT` | `scr_<gametype>_timelimit` in minutes | |
| `COD4_SCORE_LIMIT` | `scr_<gametype>_scorelimit` | |
| `COD4_HARDCORE` | `scr_hardcore` | |
| `COD4_FRIENDLY_FIRE` | `scr_team_fftype`: 0 off, 1 on, 2 reflect, 3 shared | |
| `COD4_KILLCAM` | `scr_game_allowkillcam` | |
| `COD4_ALLOW_VOTE` | `g_allowvote` | |
| `COD4_PUNKBUSTER` | `sv_punkbuster` | `0` |
| `COD4_ALLOW_DOWNLOAD` | `sv_allowDownload` (clients download missing mod files) | `1` |
| `COD4_WWW_BASE_URL` | When set, enables `sv_wwwDownload` with this `sv_wwwBaseURL` | |
| `HTTP_FILESERVER_ENABLED` | Serve `.iwd` and `.ff` files from `Merged/` over HTTP on port 80 | `false` |
| `HTTP_FILESERVER_WEB_ROOT` | Web root of the HTTP file server | `/config/Merged` |
| `HTTP_FILESERVER_FILE_PATTERN` | Files the HTTP file server serves | `^/.*\.(iwd\|ff)$` |
| `START_EXE` | Launcher | `/usr/local/bin/cod4-server` |
| `START_ARGS` | Extra console commands, inserted before `+map_rotate` (e.g. `+set sv_maxPing 200`) | |

Stock maps: `mp_backlot`, `mp_bloc`, `mp_bog`, `mp_broadcast`, `mp_carentan`, `mp_cargoship`, `mp_citystreets`, `mp_convoy`, `mp_countdown`, `mp_crash`, `mp_crash_snow`, `mp_creek`, `mp_crossfire`, `mp_farm`, `mp_killhouse`, `mp_overgrown`, `mp_pipeline`, `mp_shipment`, `mp_showdown`, `mp_strike`, `mp_vacant`.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

```bash
docker build -t lancommander/callofduty4:local .
docker build --build-arg BASE_IMAGE=lancommander/base:local -t lancommander/callofduty4:local .
```

| Build arg | Description | Default |
|-----------|-------------|---------|
| `BASE_IMAGE` | Base image | `lancommander/base:latest` |

---

## License

Call of Duty 4: Modern Warfare is a trademark of Activision. Its game data is not included and is distributed under its own license.
This repository contains only Docker build logic and helper scripts licensed under MIT.
