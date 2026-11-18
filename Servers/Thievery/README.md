# Thievery Server (Docker)

This repository provides a Dockerized **Thievery** dedicated server. Thievery is a free total conversion mod for Unreal Tournament (1999) that pits a team of thieves against a team of guards in a pseudo-medieval setting. The mod ships Windows-only native DLLs, so the image runs Unreal Tournament's Windows `UCC.exe server` under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers.WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs `UCC.exe server` the way the mod's `ThieveryServer.bat` does (headless; no X display, graphics or sound)
- A separate server ini (`System/Server.ini`) is created from the mod's `ThAux.ini`, and the common settings are environment variables
- Thievery gameplay settings and the map rotation are written to `System/ThieveryMod.ini`, where the mod reads them
- All three game types (teams, ThiefMatch, co-op) with short names
- Optional map rotation; maps that aren't installed are left out
- Installs Unreal Tournament and Thievery from two zips, e.g. LANCommander archives
- The master server uplinks are removed by default
- UCC's console log goes to `docker logs`
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  thievery:
    image: lancommander/thievery:latest
    container_name: thievery

    ports:
      - "7777:7777/udp"
      - "7778:7778/udp"
      - "8777:8777/udp"

    volumes:
      - ./config:/config

    environment:
      THIEVERY_SERVER_NAME: "My Thievery Server"
      THIEVERY_GAME_TYPE: "teams"
      THIEVERY_MAP: "TH-Theatre"
      THIEVERY_MAX_PLAYERS: "16"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The in-game LAN browser finds servers by broadcast. That needs the container on the LAN itself (macvlan/ipvlan, or `network_mode: host`). With port mapping, clients join by IP.

---

## Game Files

The server needs **Unreal Tournament (1999) patch 436** with **Thievery 1.7** extracted on top of it, the same files the clients run. Unreal Tournament is retail software with no public download. Either:

- copy that folder's contents (`System/`, `Maps/`, `Textures/`, `Thievery/` ...) to `config/Server/`, **or**
- set `THIEVERY_UT_ARCHIVE_URL` to a zip of the Unreal Tournament folder and `THIEVERY_ARCHIVE_URL` to a zip of the Thievery files (`System/` and `Thievery/`), e.g. LANCommander archives. `file://` URLs are read in place. Each part is installed on start if it's missing (`Server/System/UCC.exe`, `Server/System/ThieveryMod.u`); the Thievery zip is merged into the UT folder.

The server doesn't need `Help/`, `Manual/` or `NetGamesUSA.com/`; they're left out when installing from zips.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Unreal Tournament + Thievery (System/, Maps/, Textures/, Thievery/ ...)
    ├── Overlay/           # Your files, layered on top of Server/ (System/Server.ini and ThieveryMod.ini land here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers.WINE#environment).
The settings are written on every start. Settings left empty are not touched, so you can set them in the ini instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `THIEVERY_MAP` | Start map | `TH-Theatre` |
| `THIEVERY_GAME_TYPE` | `teams`, `thiefmatch`, `coop` or a game class, see below | `teams` |
| `THIEVERY_MAPS` | Map rotation, comma separated, written to `[ThieveryMod.ThieveryMapList]` in `ThieveryMod.ini`. Empty: the list there is left alone | |
| `THIEVERY_URL_OPTIONS` | Extra start map URL options | |
| `THIEVERY_INI` | Server ini in `System/`, created from `ThAux.ini` if missing | `Server.ini` |
| `THIEVERY_USER_INI` | User ini in `System/` (`userini=`) | `ThieveryUser.ini` |
| `THIEVERY_PORT` | Game port, `[URL] Port`. The query port is this + 1 | `7777` |
| `THIEVERY_SERVER_NAME` | `[Engine.GameReplicationInfo] ServerName` | `Thievery Server` |
| `THIEVERY_SHORT_NAME` | `[Engine.GameReplicationInfo] ShortName` | `Thievery Server` |
| `THIEVERY_ADMIN_NAME` | `[Engine.GameReplicationInfo] AdminName` | |
| `THIEVERY_ADMIN_EMAIL` | `[Engine.GameReplicationInfo] AdminEmail` | |
| `THIEVERY_MOTD` | `[Engine.GameReplicationInfo] MOTDLine1` | |
| `THIEVERY_MAX_PLAYERS` | `[Engine.GameInfo] MaxPlayers` | `16` |
| `THIEVERY_MAX_SPECTATORS` | `[Engine.GameInfo] MaxSpectators` | |
| `THIEVERY_GAME_PASSWORD` | `[Engine.GameInfo] GamePassword` | |
| `THIEVERY_ADMIN_PASSWORD` | `[Engine.GameInfo] AdminPassword` | |
| `THIEVERY_FRIENDLY_FIRE_SCALE` | `[ThieveryMod.ThieveryDeathMatchPlus] FriendlyFireScale`, 0 to 1 (server ini) | |
| `THIEVERY_TIME_LIMIT` | `[ThieveryMod.ThieveryGameSettings] TimeLimit` in minutes | |
| `THIEVERY_BALANCE_TEAMS` | `true`/`false`: `bBalanceTeams` | |
| `THIEVERY_GUARD_START_MONEY` | `GuardStartMoney` | |
| `THIEVERY_THIEVES_START_MONEY` | `ThievesStartMoney` | |
| `THIEVERY_PREGAME_WAIT` | `nPregameWaitTime`, seconds | |
| `THIEVERY_AI_SKILL` | `AISkill`, 0 to 1 (guard AI) | |
| `THIEVERY_MASTER_SERVER_UPLINK` | `true` sends heartbeats to 333networks (`master.333networks.com`) for an internet listing | `false` |
| `THIEVERY_UT_ARCHIVE_URL` | Zip of the Unreal Tournament 436 folder, used if `Server/System/UCC.exe` is missing | |
| `THIEVERY_ARCHIVE_URL` | Zip of the Thievery files, used if `Server/System/ThieveryMod.u` is missing | |
| `WINE_XVFB` | UCC needs no display | `false` |
| `START_EXE` | Launcher | `/usr/local/bin/thievery-server` |
| `START_ARGS` | Appended to the UCC command line | |

The `THIEVERY_TIME_LIMIT` ... `THIEVERY_AI_SKILL` settings go to `[ThieveryMod.ThieveryGameSettings]` in `System/ThieveryMod.ini` and apply to every game type.

Game types:

| `THIEVERY_GAME_TYPE` | Game class |
|----------------------|------------|
| `teams` | `ThieveryMod.ThieveryDeathMatchPlus` (thieves vs guards) |
| `thiefmatch` | `ThieveryMod.ThieveryThiefMatch` |
| `coop` | `ThieveryMod.ThieveryCooperative` (thieves vs AI guards) |

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/thievery:local .
```

---

## License

Unreal Tournament, Thievery and Wine are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
