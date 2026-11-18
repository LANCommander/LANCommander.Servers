# King Arthur's Gold Server (Docker)

This repository provides a Dockerized **King Arthur's Gold** dedicated server. King Arthur's Gold (KAG) is a 2013 side-scrolling 2D multiplayer castle-building and combat game by Transhuman Design. The image runs THD's official Linux dedicated server (build 2844, May 2024) from kag2d.com.
The image builds on [`lancommander/base`](https://github.com/LANCommander/LANCommander.Servers.Base). It supports file overlaying using OverlayFS.

---

## Features

- Official KAG Linux dedicated server, downloaded on first start and verified by SHA256; the package carries all game data, maps and game modes, so no game files are needed
- The server name, game mode, map cycle, player slots and passwords are environment variables, written into `autoconfig.cfg`
- LAN mode by default: no kag2d.com master list registration
- Optional TCP RCON (TCPR) on the game port
- Console output goes to `docker logs` as it happens
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  kag:
    image: lancommander/kingarthursgold:latest
    container_name: kag

    ports:
      - "50301:50301/udp"
      - "50301:50301/tcp"

    volumes:
      - ./config:/config

    environment:
      KAG_SERVER_NAME: "My KAG Server"
      KAG_GAME_MODE: "CTF"
      KAG_RCON_PASSWORD: "changeme"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

---

## Server Files

On first start the server package (`KAG_SERVER_URL`) is downloaded, checked against `KAG_SERVER_SHA256` and unpacked into `config/Server/`. It is reinstalled when `KAG_SERVER_URL` changes.

`https://dl.kag2d.com/kag-linux32-dedicated-release.tar.gz` always serves THD's newest release; the default hash is for build 2844 (`App/version.txt`: `version_file 1714668524-2844-...`, network `BUILD 4762` in the log). If THD ever publishes a new build the hash check fails; clear `KAG_SERVER_SHA256` to accept it. Clients must run the same build as the server.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # KAG server package (KAGdedi, libJuxta_dedi.so, Base/, Mods/ ...)
    ├── Overlay/           # Your files, layered on top of Server/ (autoconfig.cfg, Logs/, Cache/ land here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [base image's variables](https://github.com/LANCommander/LANCommander.Servers.Base#environment-variables).
The settings are written into `autoconfig.cfg` on every start. Settings left empty are not touched, so you can set them in the file instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `KAG_SERVER_URL` | Server package (.tar.gz) | `https://dl.kag2d.com/kag-linux32-dedicated-release.tar.gz` |
| `KAG_SERVER_SHA256` | SHA256 of the package; empty = no check | `1d01eb5b...d8a7560c` (build 2844) |
| `KAG_PORT` | `sv_port`: game port (UDP); TCPR uses the same TCP port | `50301` |
| `KAG_LAN` | `true` turns off kag2d.com master list registration (`sv_register 0`, `sv_sendminimap 0`); `false` turns it on | `true` |
| `KAG_SERVER_NAME` | `sv_name` | `King Arthur's Gold Server` |
| `KAG_SERVER_INFO` | `sv_info` (description in the server browser) | |
| `KAG_MAX_PLAYERS` | `sv_maxplayers` | `16` |
| `KAG_SPECTATOR_SLOTS` | `sv_spectatorslots` (extra spectator slots) | |
| `KAG_PASSWORD` | `sv_password` | |
| `KAG_RCON_PASSWORD` | `sv_rconpassword`, for in-game `/rcon` and TCPR | |
| `KAG_TCPR` | `true`/`false`: `sv_tcpr`, the TCP RCON server on `KAG_PORT` | |
| `KAG_GAME_MODE` | `sv_gamemode`: a folder name under `Base/Rules` (`CTF`, `TDM`, `WAR`, `SmallCTF`, `Sandbox`, `Challenge`, ...) | `CTF` |
| `KAG_MAP_CYCLE` | Maps separated by `;` or `,`, as paths under `Base/` (e.g. `Maps/Official/CTF/FG_Forsaken.png`). Written into `lancommander_mapcycle.cfg`, which `sv_mapcycle` points at. Empty: the game mode's own cycle. `keep`: leave `sv_mapcycle` alone | |
| `KAG_MAP_CYCLE_SHUFFLE` | `true`/`false`: `sv_mapcycle_shuffle` | |
| `KAG_CAN_PAUSE` | `true`/`false`: `sv_canpause` (sleep while empty to save CPU) | |
| `START_EXE` | Launcher | `/usr/local/bin/kag-server` |
| `START_ARGS` | Appended to the `KAGdedi` command line | |

The hook also sets `g_ansiconsole 0`, so the log has no colour codes.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/base:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/base:local -t lancommander/kingarthursgold:local .
```

---

## License

King Arthur's Gold is distributed under its own license by Transhuman Design.
This repository contains only Docker build logic and helper scripts licensed under MIT.
