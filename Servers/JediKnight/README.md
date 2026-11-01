# Star Wars Jedi Knight: Dark Forces II Server (Docker)

This repository provides a Dockerized **Star Wars Jedi Knight: Dark Forces II** dedicated server. The original game (LucasArts, 1997) has no dedicated server. This image runs [OpenJKDF2](https://github.com/shinyquagsire23/OpenJKDF2), the open-source reimplementation of the engine, in its headless dedicated server mode, under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers.WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs `openjkdf2-64.exe -headless -dedicatedServer`, with the game data from your own copy of Jedi Knight
- Server name, port, episode, level, player count, limits, teams and password are environment variables, written into the game's `registry.json` on every start
- The server's log (`debug.log`) is streamed to `docker logs`
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  jediknight:
    image: lancommander/jediknight:latest
    container_name: jediknight

    ports:
      - "27020:27020/udp"

    volumes:
      - ./config:/config

    environment:
      JK_SERVER_NAME: "My Jedi Knight Server"
      JK_EPISODE: "JK1MP"
      JK_MAP: "m2.jkl"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

---

## Game Files

Jedi Knight is retail software with no public download. You must provide a Jedi Knight install with OpenJKDF2 added to it: `openjkdf2-64.exe` and its DLLs next to `Episode/`, `Resource/` and `player/`. **Clients have to run the same OpenJKDF2 version as the server**, because its network protocol changes between releases. The LANCommander package uses OpenJKDF2 v0.8.15.

- copy the game folder (the one containing `openjkdf2-64.exe`) to `config/Server/`, **or**
- set `JK_ARCHIVE_URL` to a zip of that folder, e.g. a LANCommander archive. It is downloaded and extracted on first start, if `Server/openjkdf2-64.exe` doesn't exist yet.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Jedi Knight + OpenJKDF2 (openjkdf2-64.exe, Episode/, Resource/ ...)
    ├── Overlay/           # Your files, layered on top of Server/ (registry.json, player/ and debug.log land here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers.WINE#environment).
The `JK_*` server settings are written into `registry.json` on every start. Settings left empty are not touched, so you can set them in that file instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `JK_PORT` | Game port (`portNum`) | `27020` |
| `JK_SERVER_NAME` | Server name (`gameName`) | `Jedi Knight Server` |
| `JK_PASSWORD` | Join password (`serverPassword`). Empty means no password | |
| `JK_EPISODE` | Episode GOB in `Episode/`, without `.GOB` (`serverEpisodeGob`) | `JK1MP` |
| `JK_MAP` | Level in that episode (`serverMapJkl`) | `m2.jkl` |
| `JK_MAX_PLAYERS` | Player slots, 1-30, not counting the server | `8` |
| `JK_MAX_RANK` | Highest Jedi rank players may pick, 0-8 (`maxRank`) | `8` |
| `JK_SCORE_LIMIT` | Score limit, `0` = none | `20` |
| `JK_TIME_LIMIT` | Minutes per level, `0` = none | `15` |
| `JK_TEAMS` | Team play (`bIsTeams`) | `false` |
| `JK_SINGLE_LEVEL` | Stay on `JK_MAP` instead of moving through the episode's levels (`bIsSingleLevel`) | `true` |
| `JK_TICK_RATE` | Network update interval in ms (`tickRate`); the game's default is `180` | |
| `JK_VERBOSE` | `-verbose` level for `debug.log`: `0`, `1` or `2` | `1` |
| `JK_EXE` | Server executable in the game folder | `openjkdf2-64.exe` |
| `JK_ARCHIVE_URL` | Zip of the game folder, used if `Server/<JK_EXE>` is missing | |
| `WINE_XVFB` | Run on a virtual display. OpenJKDF2 needs one to start, even headless | `true` |
| `START_EXE` | Launcher | `/usr/local/bin/jediknight-server` |
| `START_ARGS` | Extra OpenJKDF2 arguments, e.g. `-verboseNetworking` | |

Multiplayer episodes in the base game:

| `JK_EPISODE` | Levels (`JK_MAP`) |
|--------------|-------------------|
| `JK1MP` | `m2.jkl`, `m4.jkl`, `m5.jkl`, `m10.jkl`, `m_boss15.jkl`, `m_boss17.jkl` |
| `JK1CTF` | `c1.jkl`, `c2.jkl`, `c3.jkl` |

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/jediknight:local .
```

---

## License

Star Wars Jedi Knight: Dark Forces II, OpenJKDF2 and Wine are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
