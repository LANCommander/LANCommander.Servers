# Daikatana Server (Docker)

This image provides a Dockerized **Daikatana** dedicated server. It runs the community [Daikatana v1.3](https://bitbucket.org/daikatana13/daikatana) dedicated server, `dk_ded.exe`, which is Windows-only, so the image runs it under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE). It supports file overlaying using OverlayFS.

---

## Features

- Installs the game from a zip on first start (`DAIKATANA_ARCHIVE_URL`), or uses an install you copy in
- Game mode (deathmatch, team deathmatch, CTF, Deathtag, co-op), start map, map rotation, limits and passwords are environment variables, written into `data/lancommander.cfg` on every start
- Checks the start map and rotation against the maps in `data/*.pak` and `data/maps/`, so a typo can't stall the rotation
- Your own cvars go in `data/server.cfg`
- The server's console log is followed to `docker logs`
- The server is a GUI program, so it runs on a virtual display (Xvfb)
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  daikatana:
    image: lancommander/daikatana:latest
    container_name: daikatana

    ports:
      - "27992:27992/udp"
      - "27982:27982/udp"

    volumes:
      - ./config:/config

    environment:
      DAIKATANA_SERVER_NAME: "My Daikatana Server"
      DAIKATANA_MODE: "dm"
      DAIKATANA_MAP: "e1dm1"
      DAIKATANA_MAPS: "e1dm1 e1dm2 e2dm1 e2dm2 e3dm1 e3dm2 e4dm1 e4dm2"
      DAIKATANA_TIME_LIMIT: "15"
      DAIKATANA_RCON_PASSWORD: "changeme"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The same file is in this directory as [`compose.yml`](compose.yml).

---

## Game Files

Daikatana isn't freely downloadable, so the image doesn't include it. You need a Windows **Daikatana v1.3** install, i.e. the folder that holds `dk_ded.exe` and `data/pak*.pak`. Either:

- copy it to `config/Server/`, **or**
- set `DAIKATANA_ARCHIVE_URL` to a zip of it (a `file://` URL works for a zip mounted into the container).

On first start, if `Server/dk_ded.exe` doesn't exist, the install hook downloads and unpacks the zip into `Server/`. It skips the music, the intro movie player and the debug symbols, which the server doesn't need (about 520 MB result).

Clients must run the **same v1.3 build** as the server. The server reports its build in the log (`6b7338f (2023-08-17 ...)`) and in queries (`version Win64r Aug 17 2023`). With `sv_lockout_old_builds 1` it drops older clients.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Daikatana v1.3 install (dk_ded.exe, data/pak*.pak, dlls/ ...)
    ├── Overlay/           # Your files, layered on top of Server/ (data/server.cfg, and what the
    │                      # server writes: data/lancommander.cfg, data/dk_console.log, data/save_x64/)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE#environment).
Empty settings are left out of `data/lancommander.cfg`, so the game's defaults (or `data/server.cfg`) apply.

| Variable | Description | Default |
|----------|-------------|---------|
| `DAIKATANA_ARCHIVE_URL` | URL of a zip of the game folder, used if `Server/dk_ded.exe` is missing | |
| `DAIKATANA_MODE` | `dm` (deathmatch), `tdm` (team deathmatch), `ctf`, `dt` (Deathtag) or `coop`. Empty = leave the mode to `server.cfg` | `dm` |
| `DAIKATANA_MAP` | Start map. Empty = no `+map`, and `data/server.cfg` must start a map itself | `e1dm1` |
| `DAIKATANA_MAPS` | Map rotation, separated by spaces or commas. Written to `maps_dm` (dm, tdm), `maps_ctf` or `maps_deathtag`. Co-op has no rotation | |
| `DAIKATANA_PORT` | Game port (`port`). The GameSpy query port is this minus 10 | `27992` |
| `DAIKATANA_SERVER_NAME` | `hostname` | `Daikatana Server` |
| `DAIKATANA_MAX_PLAYERS` | `maxclients` | `8` |
| `DAIKATANA_FRAG_LIMIT` | `fraglimit` | |
| `DAIKATANA_TIME_LIMIT` | `timelimit`, in minutes | |
| `DAIKATANA_SKILL` | `skill`, the co-op difficulty: `0` easy, `1` medium, `2` hard | |
| `DAIKATANA_PASSWORD` | Join password (`password`) | |
| `DAIKATANA_RCON_PASSWORD` | `rcon_password`. Empty = rcon is off | |
| `DAIKATANA_PUBLIC` | `public`: `1` sends heartbeats to the master server (`sv_master_server_ip`, `master.maraakate.org`) | `0` |
| `WINE_XVFB` | Run on a virtual display. The server exits without one | `true` |
| `START_EXE` | Launcher | `/usr/local/bin/daikatana-server` |
| `START_ARGS` | Added to the `dk_ded.exe` command line, before `+map` | |

Stock multiplayer maps:

- Deathmatch: `e1dm1`, `e1dm1a`, `e1dm2`, `e1dm2a`, `e2dm1`, `e2dm2`, `e3dm1`, `e3dm2`, `e4dm1`, `e4dm2`, `slicedm1`
- CTF: `e1ctf1`, `e2ctf1`, `e3ctf1`, `e4ctf1`
- Deathtag: `e1dt1`
- Co-op: the campaign maps, starting with `e1m1a`

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/daikatana:local Servers/Daikatana
```

---

## License

Daikatana, Daikatana v1.3 and Wine are distributed under their respective licenses.
This directory contains only Docker build logic and helper scripts licensed under MIT.
