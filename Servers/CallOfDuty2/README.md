# Call of Duty 2 Server (Docker)

This image provides a Dockerized **Call of Duty 2** dedicated server. It runs the official 1.3 Linux dedicated server (`cod2_lnxded`) with your retail Call of Duty 2 game data.
The image builds on [`lancommander/base`](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/Base). It supports file overlaying using OverlayFS.

---

## Features

- Official Call of Duty 2 1.3 Linux dedicated server, downloaded on first start and verified by SHA256
- The server's name, game type, map rotation, limits and passwords are environment variables, written into a config file the server execs at startup
- LAN mode by default (`dedicated 1`)
- Optional HTTP fast download of `.iwd` files (`sv_wwwDownload`) from the base image's nginx
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  callofduty2:
    image: lancommander/callofduty2:latest
    container_name: callofduty2

    ports:
      - "28960:28960/udp"

    volumes:
      - ./config:/config

    environment:
      COD2_SERVER_NAME: "My Call of Duty 2 Server"
      COD2_GAME_TYPE: "tdm"
      COD2_RCON_PASSWORD: "changeme"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The same file is in this directory as [`compose.yml`](compose.yml).

The in-game LAN browser finds servers by broadcast. That needs the container on the LAN itself (macvlan/ipvlan, or `network_mode: host`); with port mapping, clients join by IP (`connect <ip>:28960` in the console).

---

## Game Files

The image contains no game data. Copy a retail Call of Duty 2 install, patched to 1.3, into `config/Server/`: at least `localization.txt` and the `main/` folder (`iw_00.iwd` to `iw_15.iwd` and the `localized_*_iw*.iwd` files). The Windows executables, `miles/` and the rest can stay or go. The server stops with an error if `main/iw_00.iwd` is missing.

On first start the image downloads the Linux server (`cod2_lnxded` and the PunkBuster server libraries in `pb/`) into `config/Server/`, next to the game data. Clients need Call of Duty 2 1.3.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Retail game data (main/*.iwd, localization.txt) plus cod2_lnxded
    ├── Overlay/           # Your files, layered on top of Server/ (main/server.cfg, generated lancommander.cfg, logs)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [base image's variables](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/Base#environment-variables).
The settings are written into `<COD2_FS_GAME or main>/lancommander.cfg` on every start. Settings left empty are left out, so you can set them in `server.cfg` instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `COD2_SERVER_URL` | Linux dedicated server package (`.tar.xz`/`.tar.gz`/`.tar.bz2`/`.zip` with `cod2_lnxded` at its root). Changing it reinstalls | the [`LANCommander.Servers.CallOfDuty2`](https://github.com/LANCommander/LANCommander.Servers.CallOfDuty2/releases) repo's `server-1.3` release |
| `COD2_SERVER_SHA256` | Expected SHA256 of the package (empty skips the check) | SHA256 of the `server-1.3` package |
| `COD2_PORT` | `net_port` (game port) | `28960` |
| `COD2_LAN` | `true` runs `dedicated 1` (LAN); `false` runs `dedicated 2` (internet, CD key checks against the Activision master server) | `true` |
| `COD2_FS_GAME` | Mod folder (`fs_game`), e.g. `mods/mymod` | |
| `COD2_SERVER_NAME` | `sv_hostname` | `Call of Duty 2 Server` |
| `COD2_MOTD` | `scr_motd` | |
| `COD2_MAX_PLAYERS` | `sv_maxclients` | `20` |
| `COD2_PASSWORD` | `g_password` | |
| `COD2_RCON_PASSWORD` | `rcon_password` | |
| `COD2_GAME_TYPE` | `g_gametype`: `dm`, `tdm`, `sd`, `ctf` or `hq` | `tdm` |
| `COD2_MAPS` | Map rotation, comma- or space-separated, all played as `COD2_GAME_TYPE` (`sv_mapRotation`). The server starts on the first map | all 15 stock maps |
| `COD2_TIME_LIMIT` | `scr_<gametype>_timelimit` in minutes | |
| `COD2_SCORE_LIMIT` | `scr_<gametype>_scorelimit` | |
| `COD2_FRIENDLY_FIRE` | `scr_friendlyfire`: 0 off, 1 on, 2 reflect, 3 shared | |
| `COD2_KILLCAM` | `scr_killcam` | |
| `COD2_ALLOW_VOTE` | `g_allowvote` | |
| `COD2_PUNKBUSTER` | `sv_punkbuster` | `0` |
| `COD2_ALLOW_DOWNLOAD` | `sv_allowDownload` (clients download missing mod/map files) | `1` |
| `COD2_WWW_BASE_URL` | When set, enables `sv_wwwDownload` with this `sv_wwwBaseURL` | |
| `HTTP_FILESERVER_ENABLED` | Serve `.iwd` files from `Merged/` over HTTP on port 80 | `false` |
| `HTTP_FILESERVER_WEB_ROOT` | Web root of the HTTP file server | `/config/Merged` |
| `HTTP_FILESERVER_FILE_PATTERN` | Files the HTTP file server serves | `^/.*\.iwd$` |
| `START_EXE` | Launcher | `/usr/local/bin/cod2-server` |
| `START_ARGS` | Extra console commands, inserted before `+map_rotate` (e.g. `+set sv_maxPing 200`) | |

Stock maps: `mp_breakout`, `mp_brecourt`, `mp_burgundy`, `mp_carentan`, `mp_dawnville`, `mp_decoy`, `mp_downtown`, `mp_farmhouse`, `mp_harbor`, `mp_leningrad`, `mp_matmata`, `mp_railyard`, `mp_rhine`, `mp_toujane`, `mp_trainstation`.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

```bash
docker build -t lancommander/callofduty2:local Servers/CallOfDuty2
docker build --build-arg BASE_IMAGE=lancommander/base:local -t lancommander/callofduty2:local Servers/CallOfDuty2
```

| Build arg | Description | Default |
|-----------|-------------|---------|
| `BASE_IMAGE` | Base image | `lancommander/base:latest` |

---

## License

Call of Duty 2 is a trademark of Activision. Its game data is not included and is distributed under its own license.
This directory contains only Docker build logic and helper scripts licensed under MIT.
