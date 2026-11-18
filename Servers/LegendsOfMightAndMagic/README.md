# Legends of Might and Magic Server (Docker)

This image provides a Dockerized **Legends of Might and Magic** dedicated server. The game has no Linux server, so the image runs the retail Windows dedicated server, `LegendServ.exe` (LithTech, 2001), under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs the game's own `LegendServ.exe` dedicated server
- Native Microsoft DirectPlay installed into the Wine prefix automatically. Wine's builtin DirectPlay can't load the TCP/IP service provider the server uses.
- Every Host Settings option is an environment variable. LegendServ has no config file or command-line settings, so the image writes the registry and `ROTATION.TXT` and presses OK in the server's dialog for you
- Players can share a CD key (the digital releases all use the same one): the server's duplicate key check is patched out
- Map rotation names are checked against the retail maps and `Data/Worlds/*.dat`
- Current map and player count are logged to `docker logs` (read from the server's GameSpy status port)
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  legends:
    image: lancommander/legendsofmightandmagic:latest
    container_name: legends

    ports:
      - "29800:29800/udp"
      - "29801:29801/udp"

    volumes:
      - ./config:/config

    environment:
      LOMM_SERVER_NAME: "My Legends Server"
      LOMM_MAX_PLAYERS: "16"
      LOMM_MAP_TIME: "20"

    user: root               # the entrypoint mounts OverlayFS, then drops to UID/GID
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The same file is in this directory as [`compose.yml`](compose.yml).

The game uses DirectPlay, which is LAN-oriented. A network where the container gets its own LAN IP (macvlan/ipvlan, or `network_mode: host`) is more reliable than port mapping, and it's needed for the in-game LAN browser.

---

## Game Files

Legends of Might and Magic is retail software with no public download. You must provide a **1.1** install:

- copy the game folder (the one with `LegendServ.exe`, `server.dll` and `Data/`) to `config/Server/`, **or**
- set `LOMM_ARCHIVE_URL` to a zip of that folder. It is downloaded and extracted on first start, if `Server/LegendServ.exe` doesn't exist yet. `Movies/` and `Music/` are dropped.

The server and clients should use the same files, including any custom maps in `Data/Worlds/`.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Legends of Might and Magic install (LegendServ.exe, server.dll, Data/)
    ├── Overlay/           # Your files, layered on top of Server/ (ROTATION.TXT lands here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix with native DirectPlay and the server settings (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE#environment).
They are applied on every start. The ranges are the ones the server's dialog accepts, and the configure hook rejects anything outside them.

| Variable | Dialog field | Values | Default |
|----------|--------------|--------|---------|
| `LOMM_SERVER_NAME` | Server Name | text, up to 23 characters | `Legends of Might&Magic` |
| `LOMM_PASSWORD` | Server Password | text (empty = none) | |
| `LOMM_MAX_PLAYERS` | Max Players | 1-16 | `16` |
| `LOMM_MAPS` | Rotation List | comma-separated map names, empty = the 20 retail maps, `config` = keep `ROTATION.TXT` | |
| `LOMM_MAP_TIME` | Map Rotation Time (min) | 0-180 | `20` |
| `LOMM_ROUND_TIME` | RoundTime (min) | 0-10 | `5` |
| `LOMM_PURCHASE_TIME` | Purchase Time (sec) | 0-15 | `5` |
| `LOMM_FRIENDLY_FIRE` | Friendly Fire | `true`/`false` | `false` |
| `LOMM_ALLOW_VOTING` | Allow Voting | `true`/`false` | `true` |
| `LOMM_BALANCE_TEAMS` | Balance Teams | `true`/`false` | `true` |
| `LOMM_MONSTERS` | Monsters | `true`/`false` | `true` |
| `LOMM_SUPER_WEAPONS` | Super Weapons | `true`/`false` | `true` |
| `LOMM_DAMAGE_THROUGH_WALLS` | Damage Through Walls | `true`/`false` | `true` |
| `LOMM_LOCKED_CHASE_CAM` | Locked Chase Cam | `true`/`false` | `false` |
| `LOMM_LAN_ONLY` | Lan Only | `true`/`false` | `false` |
| `LOMM_CONNECTION_TYPE` | Connection Type | `56k`, `isdn`, `cable`, `dsl`, `t1`, `custom` | `t1` |
| `LOMM_UPLOAD_BANDWIDTH` | Upload Bandwidth | bytes/s, used with `custom` | |
| `LOMM_PORT` | Port | UDP port | `29800` |
| `LOMM_GAMESPY_PORT` | GameSpy Port | UDP port | `29801` |
| `LOMM_ALLOW_SHARED_CD_KEYS` | | `true`/`false`: patch out the "CD Key in use" check | `true` |
| `LOMM_ARCHIVE_URL` | | zip of the game folder, used if `Server/LegendServ.exe` is missing | |
| `LOMM_DIALOG_TIMEOUT` | | seconds to wait for the Host Settings dialog | `120` |

Retail maps: `_RescueAtTheRuins`, `_TempleOfBark`, `BloodFeud`, `ChateauEscape`, `CultOfTheSpider`, `Dragonblade`, `DragonSlayers`, `DungeonRescue`, `DungeonsOfDragadune`, `FahlteeTower`, `ForgottenKeep`, `Gauntlet`, `Hideout`, `IsleOfFire`, `OnTheRun`, `SecretsOfTheSphinx`, `SpidersDen`, `Stoneham`, `SwordInTheStone`, `WeddingDay`. Custom maps are the file names in `Data/Worlds/` without `.dat`.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/legendsofmightandmagic:local Servers/LegendsOfMightAndMagic
```

The DirectX February 2010 redistributable (source of the DirectPlay DLLs) is downloaded at build time and verified by sha256. See `DIRECTX_REDIST_URL` / `DIRECTX_REDIST_SHA256` in the Dockerfile.

---

## License

Legends of Might and Magic, Wine and the DirectX redistributable are distributed under their respective licenses.
This directory contains only Docker build logic and helper scripts licensed under MIT.
