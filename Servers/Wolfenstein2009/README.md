# Wolfenstein (2009) Server (Docker)

This image provides a Dockerized **Wolfenstein** (2009, Raven Software/Endrant Studios) multiplayer dedicated server. The game has no stand-alone server download and no Linux server: the dedicated server is `Wolf2MPLite.exe` in the installed game's `MP` folder (multiplayer 1.2, `WolfMP 1.2.341005`). The image runs it under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE). It supports file overlaying using OverlayFS.

---

## Features

- Extracts the server (the `MP` folder) from a zip of the game on first start
- Server name, password, limits and a map rotation with per-map rules are environment variables, written into `base/lancommander.cfg` on every start
- All three rule sets (Objective, Stopwatch, Team Deathmatch) on the eight stock maps
- The server's `console.log` is followed to `docker logs`
- The server is a GUI program, so it runs on a virtual display (Xvfb)
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  wolfenstein:
    image: lancommander/wolfenstein2009:latest
    container_name: wolfenstein

    ports:
      - "27758:27758/udp"

    volumes:
      - ./config:/config

    environment:
      WOLF_SERVER_NAME: "My Wolfenstein Server"
      WOLF_RULES: "objective"
      WOLF_MAPS: "mp_bank,mp_canals,mp_manor:tdm"

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

The game can't be redistributed, so the image doesn't download it. The server needs only the installed game's `MP` folder (`Wolf2MPLite.exe` and `base/*.pk4`, about 470 MB), version 1.2. Either:

- copy the contents of the `MP` folder to `config/Server/`, **or**
- put a zip of the installed game (or of its `MP` folder) in `config/`, **or**
- set `WOLF_ARCHIVE` to the path of such a zip inside the container (any file name, e.g. a LANCommander game archive), **or**
- set `WOLF_ARCHIVE_URL` to a download URL of one.

On first start, if `Server/Wolf2MPLite.exe` doesn't exist, the install hook extracts everything next to `Wolf2MPLite.exe` in the zip (the single-player `SP` folder and the menu videos are skipped) into `Server/`. Clients must run the same version (1.2).

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # The game's MP folder (Wolf2MPLite.exe, base/pak*.pk4 ...)
    ├── Overlay/           # Your files, layered on top of Server/ (the generated base/lancommander.cfg)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created). The server's console.log and saved
    │                      # cvars are in drive_c/users/lancommander/Documents/id Software/WolfMP/base/
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE#environment).
On every start the configure hook writes `base/lancommander.cfg` from the `WOLF_*` variables, and the server execs it after its own configs. Set `WOLF_MANAGE_CONFIG=false` to write the file yourself instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `WOLF_SERVER_NAME` | `si_name`, shown in the server browser | `LANCommander Wolfenstein` |
| `WOLF_PASSWORD` | Join password (`g_password`, sets `si_needPass`) | |
| `WOLF_RCON_PASSWORD` | Remote console password (`net_serverRemoteConsolePassword`). Empty = off | |
| `WOLF_PORT` | Game port (`net_port`) | `27758` |
| `WOLF_LAN_ONLY` | `net_LANServer`: only accept clients with LAN addresses | `true` |
| `WOLF_MAX_PLAYERS` | `si_maxPlayers` | `12` |
| `WOLF_MAX_PLAYERS_PER_TEAM` | `si_maxPlayersPerTeam`. Empty = half of `WOLF_MAX_PLAYERS`, rounded up | |
| `WOLF_MIN_PLAYERS` | `si_minPlayers`, the players needed before a match starts | `0` |
| `WOLF_TIME_LIMIT` | `si_timeLimit`, map time limit in **minutes** | `20` |
| `WOLF_TEAM_DAMAGE` | `si_teamDamage` | `false` |
| `WOLF_RULES` | Rules for maps that don't name their own: `objective`, `stopwatch` or `tdm` | `objective` |
| `WOLF_MAPS` | Comma-separated map rotation, played in this order. `map:rules` gives a map its own rules (`mp_manor:tdm`). The `mp_` prefix is optional. Empty = all eight stock maps | |
| `WOLF_MOTD` | Message of the day, up to four lines separated by `\|` (`si_motd_1`..`4`) | |
| `WOLF_EXTRA_CONFIG` | More console commands, separated by `;`, written before the rotation | |
| `WOLF_MANAGE_CONFIG` | `false` = don't touch `base/lancommander.cfg` | `true` |
| `WOLF_ARCHIVE` | Path of a zip of the game (or its `MP` folder) in the container. Empty = look for a zip containing `Wolf2MPLite.exe` in `/config` | |
| `WOLF_ARCHIVE_URL` | Download URL of such a zip, used if `Server/Wolf2MPLite.exe` is missing | |
| `WINE_XVFB` | Run on a virtual display. The server exits without one | `true` |
| `START_EXE` | Launcher | `/usr/local/bin/wolf-server` |
| `START_ARGS` | Added to the `Wolf2MPLite.exe` command line, e.g. `+set si_pure 0` | |

Stock maps: `mp_bank` (Bank), `mp_canals` (Canals), `mp_chemical` (Chemical), `mp_facility` (Facility), `mp_hospital` (Hospital), `mp_manor` (Manor), `mp_rooftops` (Rooftops), `mp_tesla` (Power Station).

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/wolfenstein2009:local Servers/Wolfenstein2009
```

---

## License

Wolfenstein and Wine are distributed under their respective licenses.
This directory contains only Docker build logic and helper scripts licensed under MIT.
