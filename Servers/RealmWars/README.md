# Realm Wars Server (Docker)

This repository provides a Dockerized **Realm Wars** dedicated server. Realm Wars (GarageGames community project, 2003) is a fantasy first-person team combat game built on the Torque Game Engine. Its server is the Windows game executable run with `-dedicated`; the image runs it under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers.WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs `RealmWars.exe -dedicated -mission …`
- Server name, info, passwords, player limit, time limit, port and mission set from environment variables
- Shows the server console (`console.log`) in `docker logs`
- Never tries to register with the defunct GarageGames master server
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  realmwars:
    image: lancommander/realmwars:latest
    container_name: realmwars

    ports:
      - "28000:28000/udp"

    volumes:
      - ./config:/config

    environment:
      REALMWARS_SERVER_NAME: "My Realm Wars Server"
      REALMWARS_MISSION: "rw/data/missions/newlands.mis"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

---

## Game Files

The image doesn't include the game. Provide a Realm Wars install (the folder with `RealmWars.exe`, `main.cs`, `common/` and `rw/`):

- copy it to `config/Server/`, **or**
- set `REALMWARS_ARCHIVE_URL` to a zip of the game folder (with the game at the zip root or in one top-level folder), e.g. a LANCommander archive. It is downloaded on first start, if `Server/RealmWars.exe` doesn't exist yet.

Clients must run the same build of the game as the server (e.g. the GRWC-Mod 2007 build).

## Missions

`REALMWARS_MISSION` is a path relative to the game folder. The GRWC-Mod build ships these (all Deathmatch):

| Mission | File |
|---------|------|
| Over the dark hills III | `rw/data/missions/newlands.mis` |
| Besh Jikne destroyed | `rw/data/missions/BeshJikne.mis` |
| Mountains of Tanimura | `rw/data/missions/mountains.mis` |
| Rang A Shada | `rw/data/missions/RangAShada.mis` |
| Rang A Shada 2 | `rw/data/missions/RangAShada2.mis` |
| Skar's rough Stronghold II | `rw/data/missions/skarstronghold.mis` |

If the file doesn't exist the launcher lists the missions it finds and exits.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Realm Wars install (RealmWars.exe, common/, rw/)
    ├── Overlay/           # Your files, layered on top of Server/
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    │   └── lancommander/  # Generated settings mod (main.cs) and your custom.cs
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers.WINE#environment).

| Variable | Description | Default |
|----------|-------------|---------|
| `REALMWARS_ARCHIVE_URL` | Zip of the game folder, used if `Server/RealmWars.exe` is missing | |
| `REALMWARS_SERVER_NAME` | Server name (`$Pref::Server::Name`) | `Realm Wars Server` |
| `REALMWARS_SERVER_INFO` | Server description (`$Pref::Server::Info`) | `A LANCommander Realm Wars server` |
| `REALMWARS_MAX_PLAYERS` | Player limit | `16` |
| `REALMWARS_PASSWORD` | Join password (empty = none) | |
| `REALMWARS_ADMIN_PASSWORD` | Admin password (empty = none) | |
| `REALMWARS_TIME_LIMIT` | Round time limit in minutes | `20` |
| `REALMWARS_PORT` | UDP game port | `28000` |
| `REALMWARS_MISSION` | Mission file, relative to the game folder | `rw/data/missions/newlands.mis` |
| `REALMWARS_EXTRA_ARGS` | Extra `RealmWars.exe` arguments | |
| `START_EXE` | Launcher | `/usr/local/bin/realmwars-server` |
| `START_ARGS` | Added to the `RealmWars.exe` command line | |

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 28000 | UDP | Game and LAN discovery (`REALMWARS_PORT`) |

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/realmwars:local .
```

---

## License

Realm Wars and Wine are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
