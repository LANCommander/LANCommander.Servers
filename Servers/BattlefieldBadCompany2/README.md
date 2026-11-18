# Battlefield: Bad Company 2 Server (Docker)

This image provides a Dockerized **Battlefield: Bad Company 2** LAN server, for the base game and the Vietnam expansion. It runs the **R34 dedicated server** (`Frost.Game.Main_Win32_Final.exe`) from [Bc2emu V0.9](https://sourceforge.net/projects/battlefieldbadcompany2mase/) under Wine, with the emulator's `dinput8.dll` hook.

EA shut down BFBC2's online services in 2023, so the server logs in to and registers with a master server emulator instead, set with `BFBC2_MASTER_SERVER`. The LANCommander server provides one as a plugin; it isn't part of this image.

The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE). It supports file overlaying using OverlayFS.

Based on [jkuettner/bfbc2-server](https://codeberg.org/jkuettner/bfbc2-server) (maplists and settings), which builds on the [battlefieldbadcompany2mase](https://sourceforge.net/projects/battlefieldbadcompany2mase/) project by flyer8472.

---

## Features

- Server files built into the image (SourceForge download, sha256-pinned); nothing to supply
- Registers with an external master server (LANCommander's BFBC2 master server plugin)
- Rush, Conquest, Squad Deathmatch and Squad Rush, for Bad Company 2 and Vietnam
- Server name, slots, ports, admin password, `vars.*` settings and extra startup commands from environment variables
- Editable maplists
- The server's log in `docker logs`; RCON on all addresses
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  bfbc2:
    image: lancommander/battlefieldbadcompany2:latest
    container_name: bfbc2

    # The master server lists the game server at the address it sees it connect from,
    # so give the container its own LAN address (macvlan) rather than port mappings
    networks:
      lan:

    volumes:
      - ./config:/config

    environment:
      BFBC2_MASTER_SERVER: "192.168.1.10"   # the LANCommander server
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

The same file is in this directory as [`compose.yml`](compose.yml).

### More game servers

Run more containers with the same `BFBC2_MASTER_SERVER`. Every server then shows up in the same server browser.

---

## Players

Players need the Bad Company 2 client patched to R11 (Steam/Origin builds are fine), plus `dinput8.dll` and `bfbc2.ini` from the `Crack - Copy to client root` folder of `Bc2emu_V09.rar` in the game folder. In `bfbc2.ini`, set `host=` to the master server's address, the same as `BFBC2_MASTER_SERVER`.

In the game, create a new account with any name and password (3–32 characters, no spaces or special characters; persona names up to 16). The master server emulator may store passwords in plain text, so players should not reuse a real one.

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
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE#environment).

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
| `BFBC2_MASTER_SERVER` | **Required.** Address of the master server emulator the server logs in to and registers with, e.g. the LANCommander server | |

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 19567 | UDP | Game (`BFBC2_PORT`) |
| 48888 | TCP | Remote admin / RCON (`BFBC2_ADMIN_PORT`) |

The server connects out to the master server on 19021/tcp and 19026/tcp.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/battlefieldbadcompany2:local Servers/BattlefieldBadCompany2
```

---

## License

Battlefield: Bad Company 2, Bc2emu and Wine are distributed under their respective licenses.
The maplists come from [jkuettner/bfbc2-server](https://codeberg.org/jkuettner/bfbc2-server).
This directory's own Docker build logic and helper scripts are licensed under MIT.
