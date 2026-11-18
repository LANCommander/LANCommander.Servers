# Commandos: Behind Enemy Lines Server (Docker)

This repository provides a Dockerized **Commandos: Behind Enemy Lines** multiplayer server. Commandos (Pyro Studios, 1998) plays cooperative multiplayer through a small Windows-only TCP server that ships with the game, `mpserver.exe`. The image runs it under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers.WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs `mpserver.exe`, the game's own multiplayer server
- Needs only `mpserver.exe` from the game folder; from a zip of the game it extracts just that file
- Shows the server's console in `docker logs`
- No virtual display needed
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  commandos:
    image: lancommander/commandosbehindenemylines:latest
    container_name: commandos

    ports:
      - "4321:4321/tcp"
      - "4322:4322/tcp"

    volumes:
      - ./config:/config

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

---

## Game Files

Commandos: Behind Enemy Lines is retail software with no public download. The server is a single file from the game folder, `mpserver.exe` (107 KB):

- copy `mpserver.exe` to `config/Server/`, **or**
- set `COMMANDOS_ARCHIVE_URL` to a zip of the game folder (with the game at the zip root or in one top-level folder), e.g. a LANCommander archive. It is downloaded on first start, if `Server/mpserver.exe` doesn't exist yet, and only `mpserver.exe` is extracted.

## Joining

The server has no settings. Players enter the server's IP address in the **SERVER IP ADDRESS** field of the client's join multiplayer screen (the client stores it as `.SERVERADDRESS` in `OUTPUT\COMANDO.CFG`), then create or join a game and pick the mission there. Up to 6 players.

The server prints the container's own IP address at startup. Behind Docker port mapping, give players the host's address instead.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # mpserver.exe
    ├── Overlay/           # Your files, layered on top of Server/
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers.WINE#environment).

| Variable | Description | Default |
|----------|-------------|---------|
| `COMMANDOS_ARCHIVE_URL` | Zip of the game folder, used if `Server/mpserver.exe` is missing. Only `mpserver.exe` is extracted | |
| `WINE_XVFB` | Run on a virtual display. mpserver is a console program and doesn't need one | `false` |
| `START_EXE` | Launcher | `/usr/local/bin/commandos-server` |
| `START_ARGS` | Added to the `mpserver.exe` command line (it takes no options) | |

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 4321 | TCP | mpserver.exe |
| 4322 | TCP | mpserver.exe |

Both ports are fixed in `mpserver.exe`.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/commandosbehindenemylines:local .
```

---

## License

Commandos: Behind Enemy Lines and Wine are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
