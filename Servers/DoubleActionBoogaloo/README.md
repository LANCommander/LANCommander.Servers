# Double Action: Boogaloo Server (Docker)

This repository provides a Dockerized **Double Action: Boogaloo** dedicated server. The game content in the Double Action Dedicated Server (Steam app `317800`) ships only Windows server binaries (`dab/bin/server.dll`), so the image runs the Windows `srcds.exe` under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers.WINE). It supports file overlaying using OverlayFS.

---

## Features

- Installs and updates the Double Action Dedicated Server (Steam app 317800, Windows depot) with SteamCMD, anonymously
- Common server settings are environment variables, applied after the stock `server.cfg` so they always take effect
- The server console (`da_info/console.log`) is streamed to `docker logs`
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  doubleactionboogaloo:
    image: lancommander/doubleactionboogaloo:latest
    container_name: doubleactionboogaloo

    ports:
      - "27015:27015/udp"
      - "27015:27015/tcp"

    volumes:
      - ./config:/config

    environment:
      DAB_HOSTNAME: "My Double Action Server"
      DAB_MAP: "da_cocaine"
      DAB_MAX_PLAYERS: "16"
      DAB_RCON_PASSWORD: "changeme"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

---

## Game Files

SteamCMD downloads app 317800 with the Windows platform forced (about 2.3 GB) into `config/Server/` on every start. Set `STEAM_APP_UPDATE=false` to skip the update once it is installed.

The app's engine depot is from 2014, but its game content depot (`dab/`) is shared with the game and is current (`dab/steam.inf` holds the version, e.g. `PatchVersion=1.6.0.0`). Clients must run the same version as the server.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # srcds.exe, bin/, hl2/, dab/ (SteamCMD)
    ├── Overlay/           # Your files, layered on top of Server/ (e.g. dab/cfg/server_custom.cfg)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    │   └── da_info/       # DAB's write path: console.log, downloadlists, caches
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers.WINE#environment).

| Variable | Description | Default |
|----------|-------------|---------|
| `DAB_PORT` | Game port (`-port`) | `27015` |
| `DAB_MAP` | Starting map (`+map`) | `da_cocaine` |
| `DAB_MAX_PLAYERS` | `+maxplayers` | `16` |
| `DAB_HOSTNAME` | `hostname`. Empty keeps the one from `server.cfg`. | `Double Action: Boogaloo Server` |
| `DAB_PASSWORD` | `sv_password`. Empty means no password. | |
| `DAB_RCON_PASSWORD` | `rcon_password`. Empty disables RCON. | |
| `DAB_LAN` | `sv_lan`: `1` for LAN only, `0` for internet | `1` |
| `DAB_SERVER_CFG` | Config run on every map load before the `DAB_*` values (in `dab/cfg/`). Empty runs none. | `server.cfg` |
| `DAB_EXTRA_ARGS` | Extra srcds arguments, split on whitespace | `-insecure` |
| `STEAM_APP_ID` | Double Action Dedicated Server app | `317800` |
| `STEAM_APP_UPDATE` | Install/update the app on start | `true` |
| `STEAM_VALIDATE` | Validate the install on every start | `false` |
| `STEAM_USERNAME` / `STEAM_PASSWORD` | SteamCMD login | `anonymous` / |
| `STEAM_BRANCH` / `STEAM_BRANCH_PASSWORD` | SteamCMD beta branch | |
| `STEAM_INSTALL_ATTEMPTS` | SteamCMD retries | `3` |
| `START_EXE` | Launcher | `/usr/local/bin/dab-server` |
| `START_ARGS` | Extra arguments, passed before `DAB_EXTRA_ARGS`. Prefer `DAB_EXTRA_ARGS`: the base entrypoint splits a single-word `START_ARGS` into characters. | |

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/doubleactionboogaloo:local .
```

---

## License

Double Action: Boogaloo, the Source Dedicated Server and Wine are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
