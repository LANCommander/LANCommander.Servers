# Freelancer Server (Docker)

This image provides a Dockerized **Freelancer** dedicated server. Freelancer has no Linux server, so the image runs the retail `FLServer.exe` under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs the retail Freelancer 1.1 server (`EXE/FLServer.exe`) headless under Wine and Xvfb
- Native Microsoft DirectPlay and MFC42 installed into the Wine prefix automatically, from redists cached in the image
- No first-run dialogs. The EULA is accepted and `FLServer.cfg` is written from environment variables on every start.
- Player accounts and characters persist in the Wine prefix
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  freelancer:
    image: lancommander/freelancer:latest
    container_name: freelancer

    ports:
      - "2302:2302/udp"
      - "6073:6073/udp"

    volumes:
      - ./config:/config

    environment:
      FL_SERVER_NAME: "My Freelancer Server"
      FL_DESCRIPTION: "Welcome to Sirius"
      FL_MAX_PLAYERS: "16"
      FL_PVP: "false"

    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The same file is in this directory as [`compose.yml`](compose.yml).

DirectPlay is LAN-oriented and also opens dynamic UDP ports. A network where the container gets its own LAN IP (macvlan/ipvlan, or `network_mode: host`) is more reliable than port mapping.

---

## Game Files

Freelancer is retail software with no public download. You must provide a **1.1** install:

- copy the game folder (the one containing `EXE/` and `DATA/`) to `config/Server/`, **or**
- set `FL_ARCHIVE_URL` to a zip of that folder. It is downloaded and extracted on first start, if `Server/EXE/FLServer.exe` doesn't exist yet.

Clients must run the same version and data as the server. Mods that change `DATA/` have to be installed on both.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Freelancer install (EXE/, DATA/, DLLS/)
    ├── Overlay/           # Your files, layered on top of Server/
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created). Player accounts and characters are in
    │                      # drive_c/users/lancommander/Documents/My Games/Freelancer/Accts/MultiPlayer/
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE#environment).
The `FL_*` settings are the fields of FLServer's "Server Configuration" dialog.

| Variable | Description | Default |
|----------|-------------|---------|
| `FL_SERVER_NAME` | Server name shown in the server list (max 32 characters) | `Freelancer Server` |
| `FL_DESCRIPTION` | Server description (max 128 characters) | *(empty)* |
| `FL_PASSWORD` | Join password (max 16 characters), empty for none | *(empty)* |
| `FL_MAX_PLAYERS` | Maximum players, 1-128 | `16` |
| `FL_ALLOW_NEW_PLAYERS` | Allow players to create new characters/accounts | `true` |
| `FL_PVP` | Allow players to harm other players | `false` |
| `FL_INTERNET` | "Make your server Internet accessible" (registers with the long-gone Microsoft lobby) | `false` |
| `FL_PORT` | Game port (`/p`) | `2302` |
| `FL_EXTRA_ARGS` | Extra FLServer.exe arguments, appended after `/c /p<port>` | *(empty)* |
| `FL_ARCHIVE_URL` | Zip of the game folder, used if `Server/EXE/FLServer.exe` is missing | *(empty)* |

Boolean settings accept `true`/`false` (or `1`/`0`, `yes`/`no`).

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/freelancer:local Servers/Freelancer
```

The DirectX February 2010 redistributable (source of the DirectPlay DLLs) and the Visual C++ 6 redistributable (source of `mfc42.dll`) are downloaded at build time and verified by sha256. See the `*_URL` / `*_SHA256` build arguments in the Dockerfile.

---

## License

Freelancer, Wine and the Microsoft redistributables are distributed under their respective licenses.
This directory contains only Docker build logic and helper scripts licensed under MIT.
