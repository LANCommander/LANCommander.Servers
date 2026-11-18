# Global Operations Server (Docker)

This image provides a Dockerized **Global Operations** dedicated server. It runs the game's Windows dedicated server, `goserver.exe` (LithTech, 2002), from the unofficial 4.0a update (server version 1.40), under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs the game's own `goserver.exe` dedicated server
- Every Server Settings option is an environment variable. `goserver.exe` has no command-line settings, so the image writes `Globalops/server.cfg` and presses OK in the server's dialog for you
- Map rotation names are checked against `Globalops/worlds/*.dat`
- The server's event log (joins, team changes, kills, map changes) is copied to `docker logs`
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  globalops:
    image: lancommander/globaloperations:latest
    container_name: globalops

    ports:
      - "27888:27888/udp"
      - "28672:28672/udp"

    volumes:
      - ./config:/config

    environment:
      GO_SERVER_NAME: "My Global Operations Server"
      GO_MAX_PLAYERS: "24"
      GO_MAPS: "antarctica,mexico,srilanka"

    user: root               # the entrypoint mounts OverlayFS, then drops to UID/GID
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The same file is in this directory as [`compose.yml`](compose.yml).

A network where the container gets its own LAN IP (macvlan/ipvlan, or `network_mode: host`) is needed for the in-game LAN browser.

---

## Game Files

Global Operations is retail software with no public download. You must provide an install with the unofficial **4.0a** update. Clients must run the same version.

- copy the game folder (the one with `goserver.exe`, `server.dll` and `Globalops/`) to `config/Server/`, **or**
- set `GO_ARCHIVE_URL` to a zip of that folder. It is downloaded and extracted on first start, if `Server/goserver.exe` doesn't exist yet. `GO.bik` and `Support/` are dropped.

The server and clients should use the same files, including any custom maps in `Globalops/worlds/`.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Global Operations install (goserver.exe, server.dll, Globalops/)
    ├── Overlay/           # Your files, layered on top of Server/ (server.cfg and logs/ land here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE#environment).
They are written to `Globalops/server.cfg` on every start. **A variable set to an empty string keeps the value already in `server.cfg`.** To clear a text field (e.g. remove a password), set it to a single space.

| Variable | Dialog field | `server.cfg` key | Values | Default |
|----------|--------------|------------------|--------|---------|
| `GO_SERVER_NAME` | Server > Server Name | `servername` | text | `Global Operations Server` |
| `GO_PASSWORD` | Server > Server Password | `serverpassword` | text | |
| `GO_ADMIN_NAME` | Server > Admin Name | `adminname` | text | |
| `GO_ADMIN_EMAIL` | Server > Admin Email | `adminemail` | text | |
| `GO_WEBSITE` | Server > Server Website | `serverwebsite` | text | |
| `GO_REMOTE_ADMIN_PASSWORD` | Server > Remote Admin Password | `remoteadminpassword` | text | |
| `GO_TIME_LIMIT` | Rules > Time | `timelimit` | minutes | `30` |
| `GO_ROUNDS` | Rules > Switch Map | `numrounds` | rounds per map | `5` |
| `GO_MAX_PLAYERS` | Rules > Maximum | `maxplayers` | 1-24 | `24` |
| `GO_TEAM_FLIP` | Rules > Team Flip | `teamflip` | `true`/`false` | `false` |
| `GO_TEAM_FLIP_ROUNDS` | Rules > Every Number of | `flipround` | rounds | `1` |
| `GO_LAN` | Rules > Lan | `lan` | `true`/`false` | `true` |
| `GO_MAPS` | Rules > Map Rotation | `map0`..`mapN`, `nummaps` | comma-separated map names, `config` = keep `server.cfg` | the 13 retail maps |
| `GO_FRIENDLY_FIRE` | Team Rules > Friendly Fire (team) | `ffteam` | 0-100 % | `50` |
| `GO_FRIENDLY_FIRE_ALLIES` | Team Rules > Friendly Fire (allies) | `ffallies` | 0-100 % | `50` |
| `GO_MIRROR_DAMAGE` | Team Rules > Mirror | `mirrordamage` | `true`/`false` | `true` |
| `GO_MIRROR_DAMAGE_PERCENT` | Team Rules > Percentage of damage | `mirrordamagepercent` | 0-100 % | `50` |
| `GO_MIRROR_CASH` | Team Rules > Cash Penalty for shooting | `mirrorcash` | cash | `50` |
| `GO_TEAM_KILL_PUNISH` | Team Rules > Team Kill Punish | `tkpunish` | `true`/`false` | `true` |
| `GO_TEAM_KILLS_TO_KICK` | Team Rules > Number Team Kills before | `numtkstokick` | count | `5` |
| `GO_CIVILIAN_KILLS_TO_KICK` | Team Rules > Number Civilian Kills before | `numcivstokick` | count | `5` |
| `GO_AUTO_TEAM_BALANCE` | Advanced > Auto Team | `autoteambalance` | `true`/`false` | `true` |
| `GO_ALLOW_BADGES` | Advanced > Allow Badge | `allowuploads` | `true`/`false` | `true` |
| `GO_LOG_EVENTS` | Advanced > Log Server | `logevents` | `true`/`false`: also needed for `docker logs` output | `true` |
| `GO_VOICE` | Advanced > Voice over | `voip` | `true`/`false` | `false` |
| `GO_BANDWIDTH` | Advanced > Bandwidth | `serverbandwidth` | `56k`, `isdn`, `dsl`, `t1`, `t3`, `custom` | `t3` |
| `GO_CUSTOM_BANDWIDTH` | Advanced > Bandwidth (custom) | `custombandwidth` | bytes/s, used with `custom` | |
| `GO_AFK_KICK` | Advanced > Kick Away From Keyboard User | `kickafktime` | minutes | `8` |
| `GO_FORCE_TEAM_BALANCE` | Advanced > Force Team | `forceteambalance` | `true`/`false` | `true` |
| `GO_TIME_SYNC` | Advanced > Time Sync | `TimeSyncCheck` | `true`/`false` | `true` |
| `GO_VOTING` | Advanced > Voting | `voting` | `true`/`false` | `true` |
| `GO_VOTE_KICK_RATIO` | Advanced > Vote Player Kick Ratio | `playerkickvote` | 0-100 % | `60` |
| `GO_VOTE_MAP_RATIO` | Advanced > Vote Change Map | `mapvote` | 0-100 % | `60` |
| `GO_ARCHIVE_URL` | | | zip of the game folder, used if `Server/goserver.exe` is missing | |
| `GO_DIALOG_TIMEOUT` | | | seconds to wait for the Server Settings dialog | `120` |

Retail maps: `antarctica`, `argentina`, `chechnya`, `colombia`, `lima`, `mexico`, `nafrica`, `quebec`, `schinasea`, `srilanka`, `tunnel`, `uganda`, `usa`. Custom maps are the file names in `Globalops/worlds/` without `.dat`.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/globaloperations:local Servers/GlobalOperations
```

---

## License

Global Operations and Wine are distributed under their respective licenses.
This directory contains only Docker build logic and helper scripts licensed under MIT.
