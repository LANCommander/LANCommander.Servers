# Hexen II Server (Docker)

This repository provides a Dockerized **Hexen II** (1997) dedicated server. It runs `h2ded`, the dedicated server of [Hammer of Thyrion (uHexen2)](https://github.com/sezero/uhexen2) 1.5.9, built from source into the image, with your Hexen II game data. The Portal of Praevus mission pack and mods (`-game`) are supported.
The image builds on [`lancommander/base`](https://github.com/LANCommander/LANCommander.Servers.Base). It supports file overlaying using OverlayFS.

---

## Features

- Hammer of Thyrion 1.5.9 `h2ded` for Linux, built from source, matching Hammer of Thyrion 1.5.9 clients
- The server's name, map, game mode, limits and skill are environment variables, written into a config file the server execs at startup
- Game data copied from Windows or DOS (`DATA1/PAK0.PAK`) works as-is: the server gets lowercase links to it
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  hexen2:
    image: lancommander/hexen2:latest
    container_name: hexen2

    ports:
      - "26900:26900/udp"

    volumes:
      - ./config:/config

    environment:
      HEXEN2_SERVER_NAME: "My Hexen II Server"
      HEXEN2_MAP: "ravdm2"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The in-game LAN browser (Multiplayer → Join a Game → Search for local games) finds servers by broadcast. That needs the container on the LAN itself (macvlan/ipvlan, or `network_mode: host`); with port mapping, clients join by IP (`connect <ip>` in the console).

---

## Game Files

The image contains only the `h2ded` binary. Copy the `data1/` folder of a Hexen II install into `config/Server/`: `pak0.pak` and `pak1.pak`, patched to Raven's 1.11 update (Hammer of Thyrion's `h2patch` does that), plus the `progs.dat`/`progs2.dat` game code that ships with Hammer of Thyrion if you have it. A whole Hammer of Thyrion install directory works too; the Windows files in it are ignored. The server stops with an error if `data1/pak0.pak` is missing.

For Portal of Praevus, also copy `portals/` (with `pak3.pak`) and set `HEXEN2_PORTALS=1`. For a mod, copy its folder next to `data1/` and set `HEXEN2_GAME`.

Linux h2ded opens files by their lowercase names. If the copied files are uppercase, a startup hook links the game folder (`data1` → `DATA1`) and the files and folders directly inside it (`pak0.pak` → `PAK0.PAK`) to lowercase names in `Overlay/`. Files deeper down (for example `maps/RAVDM1.BSP`) are not linked; rename those.

Clients need Hammer of Thyrion (or another engine speaking the same protocol). The server uses protocol 19 (Raven/MP/1.12) by default; `HEXEN2_PROTOCOL=18` (Raven/H2/1.11) lets the original 1.11 game join, but doesn't work with the mission pack. HexenWorld is a different game and protocol; this image doesn't run a HexenWorld server.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Game data: data1/pak0.pak, data1/pak1.pak, portals/, mod folders
    ├── Overlay/           # Your files, layered on top of Server/ (data1/server.cfg, generated lancommander.cfg, lowercase links)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [base image's variables](https://github.com/LANCommander/LANCommander.Servers.Base#environment).
The settings are written into `<HEXEN2_GAME or data1>/lancommander.cfg` on every start. Settings left empty are left out, so you can set them in `server.cfg` instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `HEXEN2_GAME` | Mod folder (`-game`), empty for plain Hexen II (`data1`) | |
| `HEXEN2_PORTALS` | `1` runs the Portal of Praevus mission pack (`-portals`); needs `portals/pak3.pak` | |
| `HEXEN2_PORT` | `-port` (game port) | `26900` |
| `HEXEN2_MAX_PLAYERS` | `-dedicated <n>`, the player slots (fixed at startup, 2 to 16) | `16` |
| `HEXEN2_PROTOCOL` | `-protocol`: `18` (Raven 1.11), `19` (Raven/MP 1.12) or `20` (UQE 1.13); empty uses h2ded's default (19) | |
| `HEXEN2_SERVER_NAME` | `hostname` | `Hexen II Server` |
| `HEXEN2_MAP` | First map (`ravdm1` to `ravdm5`, `demo1`, `village1`, ...) | `ravdm1` |
| `HEXEN2_DEATHMATCH` | `deathmatch`: `0` off, `1` on | `1` |
| `HEXEN2_COOP` | `coop`: `1` for co-op. Turning it on also sets `deathmatch 0` | `0` |
| `HEXEN2_TEAMPLAY` | `teamplay`: `0` off, `1` teams by player color, with no team damage | `0` |
| `HEXEN2_FRAG_LIMIT` | `fraglimit` (0 = none) | `20` |
| `HEXEN2_TIME_LIMIT` | `timelimit` in minutes (0 = none) | `15` |
| `HEXEN2_SKILL` | `skill`, monster difficulty for co-op: `0` easiest to `3` hardest | `1` |
| `HEXEN2_RANDOM_CLASS` | `randomclass`: `1` gives players a random class on every respawn in deathmatch | |
| `HEXEN2_SAME_LEVEL` | `samelevel`: `1` replays the current map instead of exiting | |
| `HEXEN2_NO_EXIT` | `noexit`: `1` kills players who touch an exit in deathmatch | |
| `START_EXE` | Launcher | `/usr/local/bin/hexen2-server` |
| `START_ARGS` | Extra command line, inserted before `+map` (e.g. `+sv_gravity 600`) | |

Hexen II has no map rotation of its own. When the frag or time limit is reached on a deathmatch map, the stock game code restarts the same map. A map with an exit changes to the next map when a player takes it.

h2ded has no remote console (rcon) or server password.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/base:latest` by default. A build stage compiles `h2ded` from the Hammer of Thyrion source release:

| Build arg | Description | Default |
|-----------|-------------|---------|
| `UHEXEN2_VERSION` | Hammer of Thyrion release to build (the `uhexen2-<version>` tag) | `1.5.9` |
| `UHEXEN2_SHA256` | Expected SHA256 of the source tarball (empty skips the check); clear it when changing the version | the 1.5.9 tarball's |
| `BASE_IMAGE` | Runtime base image | `lancommander/base:latest` |

`h2ded` is built without user directories, so everything it writes lands next to the game data in `Overlay/` instead of `~/.hexen2`. [`Patches/h2ded-stdin-eof.patch`](Patches/h2ded-stdin-eof.patch) stops it from busy-reading stdin once it hits end-of-file, which is the case under Docker. The version built is in `/opt/uhexen2/VERSION` and in the server's startup log.

```bash
docker build --build-arg BASE_IMAGE=lancommander/base:local -t lancommander/hexen2:local .
```

---

## License

Hexen II is a trademark of Raven Software / id Software. Its game data is not included and is distributed under its own license. Hammer of Thyrion is GPLv2.
This repository contains only Docker build logic, a source patch and helper scripts licensed under MIT.
