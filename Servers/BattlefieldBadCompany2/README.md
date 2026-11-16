# Battlefield: Bad Company 2 Server (Docker)

This repository provides a Dockerized **Battlefield: Bad Company 2** LAN server, for the base game and the Vietnam expansion. EA shut down BFBC2's online services in 2023, so a server needs a replacement master server for logins and the server browser. The image runs both in one container:

- the **R34 dedicated server** (`Frost.Game.Main_Win32_Final.exe`) from [Bc2emu V0.9](https://sourceforge.net/projects/battlefieldbadcompany2mase/), under Wine, with the emulator's `dinput8.dll` hook that sends it to the master server
- the **MASE:BC2** master server emulator, built from source for Linux with the hardening patch from [jkuettner/bfbc2-server](https://codeberg.org/jkuettner/bfbc2-server)

The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers.WINE). It supports file overlaying using OverlayFS.

Based on [jkuettner/bfbc2-server](https://codeberg.org/jkuettner/bfbc2-server) (maplists, master server patch and settings), which builds on the [battlefieldbadcompany2mase](https://sourceforge.net/projects/battlefieldbadcompany2mase/) project by flyer8472.

---

## Features

- Server files built into the image (SourceForge download, sha256-pinned); nothing to supply
- Built-in master server: players point their game at this container, no separate service needed
- Rush, Conquest, Squad Deathmatch and Squad Rush, for Bad Company 2 and Vietnam
- Server name, slots, ports, admin password, `vars.*` settings and extra startup commands from environment variables
- Editable maplists
- Accounts, personas and stats persist in `config/Master/database/`
- The server's log in `docker logs`; RCON on all addresses
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  bfbc2:
    image: lancommander/battlefieldbadcompany2:latest
    container_name: bfbc2

    # The master server tells players and game servers to connect to the address it sees,
    # so give the container its own LAN address (macvlan) rather than port mappings
    networks:
      lan:

    volumes:
      - ./config:/config

    environment:
      BFBC2_MODE: rush
      BFBC2_SERVER_NAME: "Bad Company 2 LAN"
      BFBC2_MAX_PLAYERS: 32
      BFBC2_ADMIN_PASSWORD: "change-me"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped

networks:
  lan:
    external: true
```

### More game servers

Run more containers with `BFBC2_MASTER_SERVER_ENABLED=false` and `BFBC2_MASTER_SERVER` set to the first container's IP. Every server then shows up in the same server browser.

---

## Players

Players need the Bad Company 2 client patched to R11 (Steam/Origin builds are fine), plus `dinput8.dll` and `bfbc2.ini` from the `Crack - Copy to client root` folder of `Bc2emu_V09.rar` in the game folder. In `bfbc2.ini`, set `host=` to this container's IP address, the one in the log line `Starting the master server ... (players: set host=<ip> in bfbc2.ini)`.

In the game, create a new account with any name and password (3–32 characters, no spaces or special characters; persona names up to 16). MASE stores passwords in plain text, so players should not reuse a real one.

## Game Files

The server files are built into the image. On first start they are copied into `config/Server/` (about 420 MB). To use your own server files instead, put them in `config/Server/` before the first start; a folder that the image didn't install is left alone.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Bc2emu server files (copied from the image on first start)
    ├── Overlay/           # Your files, layered on top of Server/ (generated configs land here)
    │   ├── maplists/      # One maplist per mode; edit these
    │   └── Instance/      # ServerOptions.ini, maplist.txt, AdminScripts/Startup.txt (generated)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── Master/            # Master server: config.ini (generated), templates/, database/
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers.WINE#environment).

### Game server

| Variable | Description | Default |
|----------|-------------|---------|
| `BFBC2_MODE` | `rush`, `conquest`, `sqdm`, `sqrush`, `vietrush`, `vietconquest`, `vietsqdm` or `vietsqrush`. Picks the maplist and the BC2/Vietnam mod | `rush` |
| `BFBC2_SERVER_NAME` | Name in the server browser | `Bad Company 2 Server` |
| `BFBC2_PORT` | Game port (UDP) | `19567` |
| `BFBC2_ADMIN_PORT` | Remote admin (RCON) port (TCP) | `48888` |
| `BFBC2_ADMIN_PASSWORD` | Remote admin password. Empty: a random one is generated and printed on every start | |
| `BFBC2_MAX_PLAYERS` | Player slots (Squad Deathmatch is capped at 16) | `32` |
| `BFBC2_RANKED` | Ranked server (stats and unlocks are saved) | `true` |
| `BFBC2_HARDCORE` | `vars.hardCore` | `false` |
| `BFBC2_FRIENDLY_FIRE` | `vars.friendlyFire` | `false` |
| `BFBC2_TEAM_BALANCE` | `vars.teamBalance` | `true` |
| `BFBC2_KILL_CAM` | `vars.killCam` | `true` |
| `BFBC2_MINIMAP` | `vars.miniMap` | `true` |
| `BFBC2_CROSSHAIR` | `vars.crossHair` | `true` |
| `BFBC2_3D_SPOTTING` | `vars.3dSpotting` | `true` |
| `BFBC2_MINIMAP_SPOTTING` | `vars.miniMapSpotting` | `true` |
| `BFBC2_STARTUP_COMMANDS` | More remote admin commands for `Startup.txt`, one per line, e.g. `levelVars.set gamemode RUSH tickets 150` | |
| `BFBC2_REGION` | `-region` argument | `OC` |
| `BFBC2_EXTRA_ARGS` | More server command line arguments | |
| `START_EXE` | Launcher | `/usr/local/bin/bfbc2-server` |
| `START_ARGS` | Added to the server command line | |

### Master server

| Variable | Description | Default |
|----------|-------------|---------|
| `BFBC2_MASTER_SERVER_ENABLED` | Run the master server in this container | `true` |
| `BFBC2_MASTER_SERVER` | Master server this game server registers with. Empty: this container's own IP | |
| `BFBC2_MASTER_ALL_STATS_UNLOCKED` | New personas start with every weapon and gadget unlocked | `true` |
| `BFBC2_MASTER_ALL_VETERAN` | Every player is a veteran (M1 Garand) | `true` |
| `BFBC2_MASTER_PREMIUM_FOR_ALL` | Every player has the Limited Edition unlocks | `true` |
| `BFBC2_MASTER_SPECACT_FOR_ALL` | Every player has the SPECACT kits | `false` |
| `BFBC2_MASTER_VIETNAM_FOR_ALL` | Every player owns Vietnam | `true` |
| `BFBC2_MASTER_LOG_LEVEL` | Console log level, 0–3 | `1` |
| `BFBC2_MASTER_DIR` | Master server folder (config, templates, database) | `/config/Master` |

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 19567 | UDP | Game (`BFBC2_PORT`) |
| 48888 | TCP | Remote admin / RCON (`BFBC2_ADMIN_PORT`) |
| 18390 | TCP | Master server: player login (Plasma) |
| 18395 | TCP + UDP | Master server: server browser (Theater) |
| 19021 | TCP | Master server: game server login (Plasma) |
| 19026 | TCP | Master server: game server registration (Theater) |
| 9946 | TCP | Master server: misc requests |

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/battlefieldbadcompany2:local .
```

---

## License

Battlefield: Bad Company 2, Bc2emu/MASE:BC2 and Wine are distributed under their respective licenses.
The maplists and the master server hardening patch come from [jkuettner/bfbc2-server](https://codeberg.org/jkuettner/bfbc2-server).
This repository's own Docker build logic and helper scripts are licensed under MIT.
