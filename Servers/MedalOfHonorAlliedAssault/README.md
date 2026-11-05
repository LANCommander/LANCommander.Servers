# Medal of Honor: Allied Assault Server (Docker)

This repository provides a Dockerized **Medal of Honor: Allied Assault** dedicated server, including the **Spearhead** and **Breakthrough** expansions. It runs [OpenMoHAA](https://github.com/openmoh/openmohaa), an open-source Linux build of the MOH:AA engine that the original game clients (1.11, Spearhead 2.15, Breakthrough 2.40) can join, with your retail game data.
The image builds on [`lancommander/base`](https://github.com/LANCommander/LANCommander.Servers.Base). It supports file overlaying using OverlayFS.

---

## Features

- Native Linux dedicated server (OpenMoHAA `omohaaded`, pinned and verified by SHA256 at build time)
- One image for Allied Assault, Spearhead and Breakthrough (`MOHAA_GAME`)
- The server's name, game type, map rotation, limits and passwords are environment variables, written into a config file the server execs at startup
- Stock map rotation for every game and game type when `MOHAA_MAPS` is empty
- LAN mode by default (`dedicated 1`)
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  mohaa:
    image: lancommander/medalofhonoralliedassault:latest
    container_name: mohaa

    ports:
      - "12203:12203/udp"
      - "12300:12300/udp"

    volumes:
      - ./config:/config

    environment:
      MOHAA_GAME: "aa"
      MOHAA_SERVER_NAME: "My Medal of Honor Server"
      MOHAA_GAME_TYPE: "tdm"
      MOHAA_RCON_PASSWORD: "changeme"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The in-game LAN search finds servers by broadcast. That needs the container on the LAN itself (macvlan/ipvlan, or `network_mode: host`); with port mapping, clients join by IP (`connect <ip>:12203` in the console).

---

## Game Files

The image contains no game data. Copy a retail Medal of Honor: Allied Assault install into `config/Server/`: at least `main/` (`Pak0.pk3` to `pak7.pk3`). For Spearhead add `mainta/`, for Breakthrough add `maintt/`. A patched CD install (1.11, 2.15, 2.40b) or the GOG War Chest both work. The Windows executables, DLLs, `sound/` and `video/` folders can stay or go.

Clients play with the original game (1.11 / 2.15 / 2.40) or with OpenMoHAA.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Retail game data: main/, mainta/, maintt/ with their pak*.pk3
    ├── Overlay/           # Your files, layered on top of Server/ (<game dir>/server.cfg, generated lancommander.cfg, logs)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [base image's variables](https://github.com/LANCommander/LANCommander.Servers.Base#environment).
The settings are written into `<game dir>/lancommander.cfg` on every start, where the game dir is `main`, `mainta` or `maintt`. Settings left empty are left out, so you can set them in `server.cfg` instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `MOHAA_GAME` | `aa` (Allied Assault), `sh` (Spearhead) or `bt` (Breakthrough); sets `com_target_game` | `aa` |
| `MOHAA_PORT` | `net_port` (game port) | `12203` |
| `MOHAA_GAMESPY_PORT` | `net_gamespy_port` (server browser queries) | `12300` |
| `MOHAA_LAN` | `true` runs `dedicated 1` (LAN); `false` runs `dedicated 2` (internet, heartbeats to the master server) | `true` |
| `MOHAA_SERVER_NAME` | `sv_hostname` | `Medal of Honor Server` |
| `MOHAA_MAX_PLAYERS` | `sv_maxclients` | `20` |
| `MOHAA_PASSWORD` | `g_password` | |
| `MOHAA_RCON_PASSWORD` | `rconpassword` | |
| `MOHAA_GAME_TYPE` | `g_gametype`: `ffa`, `tdm`, `round`, `obj`, `tow` (Spearhead/Breakthrough) or `lib` (Breakthrough), or the number 1-6 | `tdm` |
| `MOHAA_MAPS` | Map rotation, comma- or space-separated (`sv_maplist`). The server starts on the first map. Empty = the stock maps for the game and game type | |
| `MOHAA_TIME_LIMIT` | `timelimit` in minutes | `20` |
| `MOHAA_FRAG_LIMIT` | `fraglimit` | |
| `MOHAA_ROUND_LIMIT` | `roundlimit` (round length in minutes) | |
| `MOHAA_TEAM_DAMAGE` | `g_teamdamage` (friendly fire) | |
| `MOHAA_ALLOW_VOTE` | `g_allowvote` | |
| `START_EXE` | Launcher | `/usr/local/bin/mohaa-server` |
| `START_ARGS` | Extra console commands, run before `lancommander.cfg` (e.g. `+set sv_maxping 200`) | |

Stock rotations used when `MOHAA_MAPS` is empty:

| Game | Game type | Maps |
|------|-----------|------|
| `aa` | `ffa`, `tdm`, `round` | `dm/mohdm1` … `dm/mohdm7` |
| `aa`, `sh` | `obj` | `obj/obj_team1` … `obj/obj_team4` |
| `sh`, `bt` | `ffa`, `tdm`, `round` | `dm/mp_bahnhof_dm`, `dm/mp_bazaar_dm`, `dm/mp_brest_dm`, `dm/mp_gewitter_dm`, `dm/mp_holland_dm`, `dm/mp_malta_dm`, `dm/mp_stadt_dm`, `dm/mp_unterseite_dm`, `dm/mp_verschneit_dm` |
| `sh` | `tow` | `obj/mp_ardennes_tow`, `obj/mp_berlin_tow`, `obj/mp_druckkammern_tow`, `obj/mp_flughafen_tow` |
| `bt` | `obj` | `obj/mp_bizertefort_obj`, `obj/mp_bologna_obj`, `obj/mp_castello_obj`, `obj/mp_palermo_obj` |
| `bt` | `tow` | the Spearhead TOW maps plus `obj/mp_kasserine_tow`, `obj/mp_montebattaglia_tow`, `obj/mp_montecassino_tow` |
| `bt` | `lib` | `lib/mp_anzio_lib`, `lib/mp_bizerteharbor_lib`, `lib/mp_ship_lib`, `lib/mp_tunisia_lib` |

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

```bash
docker build -t lancommander/medalofhonoralliedassault:local .
docker build --build-arg BASE_IMAGE=lancommander/base:local -t lancommander/medalofhonoralliedassault:local .
```

| Build arg | Description | Default |
|-----------|-------------|---------|
| `BASE_IMAGE` | Base image | `lancommander/base:latest` |
| `OPENMOHAA_VERSION` | OpenMoHAA release to install | `0.82.1` |
| `OPENMOHAA_SHA256` | SHA256 of that release's `linux-amd64.zip` | SHA256 of the 0.82.1 zip |

---

## License

Medal of Honor is a trademark of Electronic Arts. Its game data is not included and is distributed under its own license.
OpenMoHAA is licensed under the GPL-2.0 and is downloaded from its GitHub releases at build time.
This repository contains only Docker build logic and helper scripts licensed under MIT.
