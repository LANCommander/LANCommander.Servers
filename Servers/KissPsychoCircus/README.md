# Kiss: Psycho Circus - The Nightmare Child Server (Docker)

This repository provides a Dockerized **Kiss: Psycho Circus - The Nightmare Child** dedicated server. The game (Third Law Interactive, 2000; LithTech 1) only ships a Windows dedicated server, so the image runs the retail `Dedicated.exe` (v1.13) under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers.WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs the retail game's `Dedicated.exe` (a console program; no display or Xvfb needed)
- The server config and map rotation are generated from environment variables
- Deathmatch and Conquer (BigHeads), with optional teamplay
- Starts the game by itself and sends the server console to `docker logs`; `kpc-console` types more commands into it
- Patches a copy of `Dedicated.exe` so an idle server uses about 20% of a core instead of 1.7 cores (see [Idle patch](#idle-patch))
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  kisspsychocircus:
    image: lancommander/kisspsychocircus:latest
    container_name: kisspsychocircus

    ports:
      - "42972:42972/udp"
      - "42973:42973/udp"

    volumes:
      - ./config:/config

    environment:
      KPC_HOSTNAME: "My Psycho Circus Server"
      KPC_GAME_TYPE: "deathmatch"
      KPC_MAPS: "PM01,PM02,PM03,PM04,PM05,PM06,PM07,PM08,PM09,PM10"
      KPC_MAX_PLAYERS: "16"
      KPC_FRAG_LIMIT: "25"
      KPC_TIME_LIMIT: "15"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

Whether the in-game LAN browser finds the server through port mapping is untested; to be safe, give the container its own LAN address (macvlan/ipvlan) or use `network_mode: host`. Clients can always join by IP.

---

## Game Files

Kiss: Psycho Circus is retail software with no public download. You must provide a full install patched to **1.13** (build 113, with `KPCPatch.rez`). Clients must run the same version:

- copy the game folder (the one containing `Dedicated.exe`, `server.dll`, `object.lto` and `PSYCHO.REZ`) to `config/Server/`, **or**
- set `KPC_ARCHIVE_URL` to a zip of that folder, e.g. a LANCommander archive. It is downloaded and extracted on first start, if `Server/Dedicated.exe` doesn't exist yet. `Movies/` and `Music/` are skipped.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Kiss: Psycho Circus install (Dedicated.exe, PSYCHO.REZ, KPCPatch.rez ...)
    ├── Overlay/           # Your files, layered on top of Server/ (the generated config, map list and patched exe land here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers.WINE#environment).
The settings are written to `<KPC_CONFIG>` in the game folder on every start. Settings left empty are left out, so the game's defaults apply.

| Variable | Description | Default |
|----------|-------------|---------|
| `KPC_CONFIG` | Server config file in the game folder, loaded with `-exec` | `lancommander.cfg` |
| `KPC_PORT` | Game port, `port` | `42972` |
| `KPC_GAMESPY_PORT` | GameSpy query port, `gamespy_port` | `42973` |
| `KPC_GAMESPY` | Report to the GameSpy master server. `false` passes `-nogamespy` | `true` |
| `KPC_HOSTNAME` | Server name, `hostname` | `Kiss Psycho Circus Server` |
| `KPC_LOCATION` | Location shown in GameSpy, `location` | |
| `KPC_MOTD` | Message of the day, `motd` | `Welcome to Psycho Circus` |
| `KPC_MAPS` | Comma-separated map rotation (see below), written to `MapLists/lancommander.txt` | `PM01,...,PM10` |
| `KPC_MAX_PLAYERS` | `maxclients`, 1 to 16 | `16` |
| `KPC_GAME_TYPE` | `deathmatch` or `conquer` (BigHeads), `gametype` 1 or 2 | `deathmatch` |
| `KPC_TEAMPLAY` | `0` no teams, `1` teams without friendly fire, `2` teams with friendly fire (`teamplay`) | `0` |
| `KPC_FRAG_LIMIT` | `fraglimit` (the team total in teamplay) | `25` |
| `KPC_TIME_LIMIT` | Minutes per map, `timelimit` | `15` |
| `KPC_SPAWN_TYPE` | `0` random, `1` farthest from body, `2` fewest players nearby, `3` farthest with fewest players, `4` in order (`spawntype`) | |
| `KPC_FRIENDLY_KILL` | Frag penalty for killing a teammate, `friendlykill` | |
| `KPC_SUICIDE` | Frag penalty for a suicide, `suicide` | |
| `KPC_KEEP_ITEMS` | Keep items across map changes, `keepitems` | |
| `KPC_FOV_CHANGE` | Allow players to change their FOV, `fovchange` | |
| `KPC_GIB_DETAIL` | `gibdetail` | |
| `KPC_EXTRA_SETTINGS` | More variables as `name value` pairs separated by `;`, e.g. `startgauntlets 1; startscourge 1` | |
| `KPC_IDLE_PATCH` | Run the patched `Dedicated-lancommander.exe` (see below) | `true` |
| `KPC_ARCHIVE_URL` | Zip of the game folder, used if `Server/Dedicated.exe` is missing | |
| `WINE_XVFB` | The server is a console program and needs no display | `false` |
| `START_EXE` | Launcher | `/usr/local/bin/kpc-server` |
| `START_ARGS` | Appended to the `Dedicated.exe` command line | |

### Maps

`KPC_MAPS` entries are deathmatch world names (`PM01`) or world paths (`worlds\deathmatch\PM01`). The 1.13 game has ten deathmatch maps, `PM01` to `PM10`, all in the default rotation. The server plays them in order and starts over after the last one.

### Idle patch

`Dedicated.exe` runs the game every 8 ms and polls its console in between without ever sleeping. Under Wine every poll is a round trip to wineserver, so an idle server uses about 1.7 CPU cores. The configure hook writes `Dedicated-lancommander.exe`, a copy that sleeps for the rest of each 8 ms frame instead, which brings an idle server down to about 20% of one core. The game logic is unchanged. Only the known 1.13 `Dedicated.exe` (sha256 `19d7766c…a829a8`) is patched; any other build runs unpatched with a warning. `KPC_IDLE_PATCH=false` runs the original.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/kisspsychocircus:local .
```

---

## License

Kiss: Psycho Circus - The Nightmare Child and Wine are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
