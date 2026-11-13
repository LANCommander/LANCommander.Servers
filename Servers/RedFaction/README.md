# Red Faction Server (Docker)

This repository provides a Dockerized **Red Faction** dedicated server. Red Faction (Volition, 2001) has no Linux server, so the image runs the game's dedicated mode under Wine, through [Alpine Faction](https://github.com/GooberRF/alpinefaction).
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers.WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs the retail game's dedicated server mode with Alpine Faction injected (headless; no window, display or Xvfb needed)
- Alpine Faction comes with the image, so only a stock Red Faction 1.20 NA install is needed
- Mixed game type rotations: each level in the rotation can have its own game type (DM, TDM, CTF, King of the Hill, Gun Game ...) and rules
- The server's name, player limit and passwords are environment variables, written into the server's TOML config
- LAN-only by default (`-lanonly`), so the server does not register with the internet game tracker
- The dedicated server console goes to `docker logs`
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  redfaction:
    image: lancommander/redfaction:latest
    container_name: redfaction

    ports:
      - "7755:7755/udp"

    volumes:
      - ./config:/config

    environment:
      RF_SERVER_NAME: "My Red Faction Server"
      RF_MAX_PLAYERS: "16"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The in-game LAN browser finds servers by broadcast. That needs the container on the LAN itself (macvlan/ipvlan, or `network_mode: host`); with port mapping, clients join by IP.

---

## Game Files

Red Faction is retail software with no public download. You must provide an install patched to **1.20 NA**:

- copy the game folder (the one containing `RF.exe` and the `.vpp` files) to `config/Server/`, **or**
- set `RF_ARCHIVE_URL` to a zip of that folder, e.g. a LANCommander archive. It is downloaded and extracted on first start, if `Server/RF.exe` doesn't exist yet.

Alpine Faction needs the 1.20 NA `RF.exe`. If the folder has an `RF_120na.exe` (left by the Dash Faction or Alpine Faction patcher when the original `RF.exe` is a different release), that is used; otherwise `RF.exe`. Set `RF_EXE` to override.

On every start the image copies its Alpine Faction files (`AlpineFactionLauncher.exe`, `AlpineFaction.dll`, `alpinefaction.vpp` ...) into the game folder, through the overlay. A Dash Faction install in the folder is left alone and isn't used.

Clients should run the same Alpine Faction version as the server. Dash Faction and stock clients can still play DM, TDM and CTF levels, but the server keeps them spectating on levels with game types or mutators added by Alpine Faction.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Red Faction install (RF.exe, *.vpp ...)
    ├── Overlay/           # Your files, layered on top of Server/ (server.toml, Alpine Faction, logs/ and downloaded levels land here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers.WINE#environment).
The settings are written into the top-level keys of `<RF_CONFIG>.toml` on every start. Settings left empty are not touched, so you can set them in the file instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `RF_CONFIG` | Name of the Alpine Faction dedicated server config, `<RF_CONFIG>.toml` in the game folder. Created from the image's default (a mixed DM/TDM/CTF/Gun Game rotation) if missing | `server` |
| `RF_PORT` | Game port (`-port`) | `7755` |
| `RF_LAN_ONLY` | `true` passes `-lanonly`, so the server is not announced to the game tracker | `true` |
| `RF_SERVER_NAME` | `server_name` | `Red Faction Server` |
| `RF_MAX_PLAYERS` | `max_players` (1 to 32) | `16` |
| `RF_PASSWORD` | `password` | |
| `RF_RCON_PASSWORD` | `rcon_password` | |
| `RF_EXE` | Game executable handed to Alpine Faction (`-exe-path`) | `RF_120na.exe` if present, else `RF.exe` |
| `RF_ARCHIVE_URL` | Zip of the game folder, used if `Server/RF.exe` is missing | |
| `AF_INSTALL` | `true` copies the image's Alpine Faction into the game folder on start. Set `false` to use your own copy in `Server/` | `true` |
| `WINE_XVFB` | Unused by `rf-server`; the server doesn't need a display | `false` |
| `START_EXE` | Launcher | `/usr/local/bin/rf-server` |
| `START_ARGS` | Appended to the Alpine Faction command line, e.g. `-nodl` or `-log` | |

Game types, limits, rules, votes and the level rotation are set in the TOML config. See [Documentation/Docker.md](Documentation/Docker.md#server-config) and Alpine Faction's [dedicated server config reference](https://github.com/GooberRF/alpinefaction/blob/main/docs/reference/DEDICATED_SERVER_CONFIG.md).

---

## Building

The image is built `FROM lancommander/wine:latest` by default and downloads the Alpine Faction release set by the `AF_VERSION` build argument (default `1.4.0_Lupin`). To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/redfaction:local .
```

---

## License

Red Faction, Alpine Faction and Wine are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
