# Aliens vs. Predator 2 Server (Docker)

This image provides a Dockerized **Aliens vs. Predator 2** dedicated server. AvP2 (Monolith, 2001) ships a Windows-only stand-alone server, `AVP2Serv.exe`. The image runs the Master Server Patch 2.4 build of it, which is in the community 1.0.9.6 installs, under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs `AVP2Serv.exe -config <profile>`, which hosts right away with no setup dialog
- Server name, port, game type, map rotation, limits and passwords are environment variables, written into the server profile (`ServerData\<name>.txt`) on every start
- All eight game types: Deathmatch, Team Deathmatch, Hunt, Survivor, Overrun, Evac, and the Master Server Patch's Capture the Flag and Domination
- The default rotations only use retail maps, which every 1.0.9.6 client has
- AVP2Serv is a GUI app, so it runs on a virtual display (Xvfb)
- GameSpy `\status\` queries on the game port for monitoring
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  avp2:
    image: lancommander/aliensvspredator2:latest
    container_name: avp2

    ports:
      - "27888:27888/udp"

    volumes:
      - ./config:/config

    environment:
      AVP2_SERVER_NAME: "My AvP2 Server"
      AVP2_GAME_TYPE: "deathmatch"
      AVP2_TIME_LIMIT: "15"
      AVP2_FRAG_LIMIT: "25"
      AVP2_CONTROL_PASSWORD: "changeme"

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

Aliens vs. Predator 2 is retail software with no public download. You must provide a 1.0.9.6 install that includes the Master Server Patch 2.4 dedicated server (`AVP2Serv.exe` dated 2018, `server.dll`, `LITHSERVER.REZ`, `customrez.txt`, `serverconfig.txt`, `ServerData\unnamed.txt`) and the game's `.REZ` files:

- copy the game folder (the one containing `AVP2Serv.exe`) to `config/Server/`, **or**
- set `AVP2_ARCHIVE_URL` to a zip of that folder, e.g. a LANCommander archive. It is downloaded and extracted on first start, if `Server/AVP2Serv.exe` doesn't exist yet.

The server doesn't need `Movies/`.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # AvP2 install (AVP2Serv.exe, server.dll, *.REZ, ServerData/ ...)
    ├── Overlay/           # Your files, layered on top of Server/ (the generated ServerData/<name>.txt,
    │                      # ban lists and server logs land here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE#environment).
The `AVP2_*` server settings are written into `ServerData\<AVP2_CONFIG>.txt` on every start. Settings left empty are not touched, so you can set them in that file instead. Limits and the map list apply to the section of the selected game type.

| Variable | Description | Default |
|----------|-------------|---------|
| `AVP2_CONFIG` | Server profile, `ServerData\<name>.txt` (`-config`). Created from `unnamed.txt` if missing | `lancommander` |
| `AVP2_SERVER_NAME` | `ServerName`. The server appends ` [D]` | `Aliens vs. Predator 2` |
| `AVP2_PORT` | Game and query port (`PortID`) | `27888` |
| `AVP2_GAME_TYPE` | `deathmatch`, `teamdeathmatch`, `hunt`, `survivor`, `overrun`, `evac`, `ctf`, `domination`, or `1`-`8` (`GameType`) | `deathmatch` |
| `AVP2_MAPS` | Comma-separated rotation. A bare name goes in `worlds\multi\dm\` (`evac_*` in `evac\`, `over_*` in `overrun\`); give a path with a backslash for others. Empty = the retail maps for the game type; `config` = keep the file's list | |
| `AVP2_MAX_PLAYERS` | `MaxTotalPlayers` | `16` |
| `AVP2_MAX_PLAYERS_PER_RACE` | `MaxPlayers0`-`3` (alien, marine, predator, corporate), in the game types that have them | `AVP2_MAX_PLAYERS` |
| `AVP2_TIME_LIMIT` | Minutes (`TimeLimit`) | |
| `AVP2_FRAG_LIMIT` | `FragLimit` | |
| `AVP2_SCORE_LIMIT` | `ScoreLimit` | |
| `AVP2_ROUND_LIMIT` | `RoundLimit` (Survivor, Overrun, Evac) | |
| `AVP2_CAPTURE_LIMIT` | `CaptureLimit` (CTF) | |
| `AVP2_PASSWORD` | Join password (`Password`, sets `Locked`). Empty = open server | |
| `AVP2_CONTROL_PASSWORD` | Server control password (`SCPassword`), used in game with `/control <password>`. The stock value is `AVP2` | |
| `AVP2_LAN` | `LANConnection` | `true` |
| `AVP2_BANDWIDTH` | `Bandwidth` | |
| `AVP2_FRIENDLY_FIRE` | `FriendlyFire` | |
| `AVP2_CLASS_WEAPONS` | `ClassWeapons` | |
| `AVP2_ARCHIVE_URL` | Zip of the game folder, used if `Server/AVP2Serv.exe` is missing | |
| `WINE_XVFB` | Run on a virtual display. AVP2Serv needs one | `true` |
| `START_EXE` | Launcher | `/usr/local/bin/avp2-server` |
| `START_ARGS` | Added to the `AVP2Serv.exe` command line | |

Default rotations (retail maps in `MULTI.REZ` and `AVP2P.REZ`):

- Deathmatch, Team Deathmatch, Hunt, Survivor: `dm_alesserfate`, `dm_alley`, `dm_auriga`, `dm_bunker`, `dm_colony`, `dm_compound`, `dm_depot`, `dm_fury151`, `dm_hanger`, `dm_leadworks`, `dm_outpost4`, `dm_quarantine`, `dm_reservoir`, `dm_stronghold`, `dm_verloc`
- Overrun: `over_alley`, `over_compound`, `over_leadworks`, `over_quarantine`, `over_stronghold`
- Evac: `evac_alley`, `evac_auriga`, `evac_colony`, `evac_fury151`, `evac_gauntlet`, `evac_hanger`, `evac_verloc`
- CTF: the eight maps with a `ctfworlds\` file. Domination: the ten maps with a `domworlds\` file

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/aliensvspredator2:local Servers/AliensVsPredator2
```

---

## License

Aliens vs. Predator 2, the Master Server Patch and Wine are distributed under their respective licenses.
This directory contains only Docker build logic and helper scripts licensed under MIT.
