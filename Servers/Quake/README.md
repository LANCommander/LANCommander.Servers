# Quake Server (Docker)

This repository provides a Dockerized **Quake** (1996) dedicated server. It runs the latest [Ironwail](https://github.com/andrei-drexler/ironwail) release (v0.8.2 as of this writing) in dedicated mode, built from source into the image, with your Quake game data. Mods (`-game`) are supported.
The image builds on [`lancommander/base`](https://github.com/LANCommander/LANCommander.Servers.Base). It supports file overlaying using OverlayFS.

---

## Features

- Ironwail for Linux, built from the latest Ironwail source release (or a version you pin) and run with `-dedicated`
- The server's name, map, game mode, limits and skill are environment variables, written into a config file the server execs at startup
- Game data copied from Windows or DOS (`Id1/PAK0.PAK`) works as-is: the server gets lowercase links to it
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  quake:
    image: lancommander/quake:latest
    container_name: quake

    ports:
      - "26000:26000/udp"

    volumes:
      - ./config:/config

    environment:
      QUAKE_SERVER_NAME: "My Quake Server"
      QUAKE_MAP: "dm4"

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

The image contains only the Ironwail binary. Copy the `id1/` folder of a Quake install (`pak0.pak` and `pak1.pak`; `pak0.pak` alone is the shareware episode) into `config/Server/`. For a mod, copy its folder next to `id1/` and set `QUAKE_GAME`. The server stops with an error if `id1/pak0.pak` is missing.

Linux Quake opens files by their lowercase names. If the copied files are uppercase, a startup hook links the game folder (`id1` → `Id1`) and the files and folders directly inside it (`pak0.pak` → `PAK0.PAK`) to lowercase names in `Overlay/`. Files deeper down (for example `maps/DM7.BSP`) are not linked; rename those.

Clients need a NetQuake engine that speaks the server's protocol. Ironwail 0.8 uses RMQ (999) by default, which Ironwail, QuakeSpasm and FTEQW clients support. For older engines, set `QUAKE_PROTOCOL=666` (FitzQuake) or `15` (original Quake, no extended limits). The Quake II/QuakeWorld protocols are not supported.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Game data: id1/pak0.pak, id1/pak1.pak, mod folders
    ├── Overlay/           # Your files, layered on top of Server/ (id1/server.cfg, generated lancommander.cfg, lowercase links)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [base image's variables](https://github.com/LANCommander/LANCommander.Servers.Base#environment).
The settings are written into `<QUAKE_GAME or id1>/lancommander.cfg` on every start. Settings left empty are left out, so you can set them in `server.cfg` next to it instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `QUAKE_GAME` | Mod folder (`-game`), empty for plain Quake (`id1`) | |
| `QUAKE_PORT` | `-port` (game port) | `26000` |
| `QUAKE_MAX_PLAYERS` | `-dedicated <n>`, the player slots (fixed at startup) | `16` |
| `QUAKE_PROTOCOL` | `-protocol`: `15` (original), `666` (FitzQuake) or `999` (RMQ); empty uses Ironwail's default (999) | |
| `QUAKE_SERVER_NAME` | `hostname` | `Quake Server` |
| `QUAKE_MAP` | First map (`dm1` to `dm6`, `e1m1`, `start`, ...) | `dm1` |
| `QUAKE_DEATHMATCH` | `deathmatch`: `0` off, `1` weapons respawn, `2` weapons stay | `1` |
| `QUAKE_COOP` | `coop`: `1` for co-op. Turning it on also sets `deathmatch 0` | `0` |
| `QUAKE_TEAMPLAY` | `teamplay`: `0` off, `1` no team damage, `2` team damage | `0` |
| `QUAKE_FRAG_LIMIT` | `fraglimit` (0 = none) | `20` |
| `QUAKE_TIME_LIMIT` | `timelimit` in minutes (0 = none) | `15` |
| `QUAKE_SKILL` | `skill`, monster difficulty for co-op: `0` easy to `3` nightmare | `1` |
| `QUAKE_SAME_LEVEL` | `samelevel`: `1` replays the current map instead of exiting | |
| `QUAKE_NO_EXIT` | `noexit`: `1` kills players who touch an exit in deathmatch | |
| `START_EXE` | Launcher | `/usr/local/bin/quake-server` |
| `START_ARGS` | Extra command line, inserted before `+map` (e.g. `+sv_gravity 600`) | |

Quake has no map rotation of its own. When the frag or time limit is reached on a deathmatch map, the stock game code restarts the same map. A map with an exit (e1m1, ...) changes to the next map when a player takes the exit. Mods can change this.

Ironwail has no remote console (rcon) or server password.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/base:latest` by default. A build stage compiles Ironwail from its source release:

| Build arg | Description | Default |
|-----------|-------------|---------|
| `IRONWAIL_VERSION` | Ironwail release tag to build (e.g. `v0.8.2`), or `latest` for the newest release | `latest` |
| `IRONWAIL_SHA256` | Expected SHA256 of the source tarball (empty skips the check) | |
| `BASE_IMAGE` | Runtime base image | `lancommander/base:latest` |

Rebuilding picks up a new Ironwail release on its own: the build fetches GitHub's latest-release info, and a change there invalidates the cached compile step. The version built is in `/opt/ironwail/VERSION` and in the server's startup log.

```bash
docker build --build-arg BASE_IMAGE=lancommander/base:local -t lancommander/quake:local .
docker build --build-arg IRONWAIL_VERSION=v0.8.2 -t lancommander/quake:0.8.2 .
```

---

## License

Quake is a trademark of id Software. Its game data is not included and is distributed under its own license. Ironwail is GPLv2.
This repository contains only Docker build logic and helper scripts licensed under MIT.
