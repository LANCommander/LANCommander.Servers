# Red Faction Server (Docker)

This repository provides a Dockerized **Red Faction** dedicated server. Red Faction (Volition, 2001) has no Linux server, so the image runs the game's own `-dedicated` mode under Wine, through [Dash Faction](https://github.com/rafalh/dashfaction).
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers.WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs the retail game's dedicated server mode with Dash Faction injected (headless; no window, display or Xvfb needed)
- The server's name, player limit and passwords are environment variables, written into the selected `dedicated_server.txt` game configuration
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
      RF_CONFIG: "dm"
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

Red Faction is retail software with no public download. You must provide an install patched to **1.20 NA** with **Dash Faction** (tested with 1.8.0) in the game folder:

- copy the game folder (the one containing `DashFactionLauncher.exe`, `RF.exe`, `dedicated_server.txt` and the `.vpp` files) to `config/Server/`, **or**
- set `RF_ARCHIVE_URL` to a zip of that folder, e.g. a LANCommander archive. It is downloaded and extracted on first start, if `Server/DashFactionLauncher.exe` doesn't exist yet.

Dash Faction must be the 1.20 NA `RF.exe`. If the folder has an `RF_120na.exe` (left by Dash Faction's patcher when the original `RF.exe` is a different release), that is used; otherwise `RF.exe`. Set `RF_EXE` to override. Clients should run the same Dash Faction version as the server.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Red Faction install (DashFactionLauncher.exe, RF.exe, *.vpp ...)
    ├── Overlay/           # Your files, layered on top of Server/ (dedicated_server.txt, banlist.txt and logs/ land here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers.WINE#environment).
The `dedicated_server.txt` settings are written into the `RF_CONFIG` block on every start. Settings left empty are not touched, so you can set them in the file instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `RF_CONFIG` | Game configuration (`$Name:` block in `dedicated_server.txt`) to run. The stock file has `dm`, `teamdm` and `ctf` | `dm` |
| `RF_PORT` | Game port (the `ForcePort` registry value) | `7755` |
| `RF_LAN_ONLY` | `true` passes `-lanonly`, so the server is not announced to the game tracker | `true` |
| `RF_SERVER_NAME` | `$Server Name:` | `Red Faction Server` |
| `RF_MAX_PLAYERS` | `$Max Players:` (2 to 32) | `16` |
| `RF_PASSWORD` | `$Password:` | |
| `RF_RCON_PASSWORD` | `$Rcon Password:` | |
| `RF_EXE` | Game executable handed to Dash Faction (`-exe-path`) | `RF_120na.exe` if present, else `RF.exe` |
| `RF_ARCHIVE_URL` | Zip of the game folder, used if `Server/DashFactionLauncher.exe` is missing | |
| `WINE_XVFB` | Unused by `rf-server`; the server doesn't need a display | `false` |
| `START_EXE` | Launcher | `/usr/local/bin/rf-server` |
| `START_ARGS` | Appended to the Dash Faction command line | |

Game type, time/kill/capture limits, damage rules and the map rotation are per configuration in `dedicated_server.txt` (`$Game Type:`, `$Max Time:`, `$Max Kills:`, `$Map:` ...).

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/redfaction:local .
```

---

## License

Red Faction, Dash Faction and Wine are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
