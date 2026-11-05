# Soldat Server (Docker)

This repository provides a Dockerized **Soldat** dedicated server. Soldat is a 2002 side-scrolling 2D multiplayer shooter by Michal Marcinkowski. The image runs the official SoldatServer 2.8.2 for game version 1.7.1.1, the non-Steam Linux build from soldat.pl.
The image builds on [`lancommander/base`](https://github.com/LANCommander/LANCommander.Servers.Base). It supports file overlaying using OverlayFS.

---

## Features

- Official SoldatServer 2.8.2 (game 1.7.1.1), downloaded on first start and verified by SHA256; the server ships its own maps, so no game files are needed
- The non-Steam build: no Steam login or Steam authentication, for the soldat.pl 1.7.1 client
- The server name, game type, map rotation, limits and passwords are environment variables, written into `soldat.ini` and `mapslist.txt`
- LAN mode by default: no soldat.pl lobby or All-Seeing Eye registration
- Console output goes to `docker logs` as it happens
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  soldat:
    image: lancommander/soldat:latest
    container_name: soldat

    ports:
      - "23073:23073/udp"
      - "23073:23073/tcp"
      - "23083:23083/tcp"

    volumes:
      - ./config:/config

    environment:
      SOLDAT_SERVER_NAME: "My Soldat Server"
      SOLDAT_GAME_TYPE: "ctf"
      SOLDAT_ADMIN_PASSWORD: "changeme"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

---

## Server Files

On first start the server zip (`SOLDAT_SERVER_URL`) is downloaded, checked against `SOLDAT_SERVER_SHA256` and unpacked into `config/Server/`. It is reinstalled when `SOLDAT_SERVER_URL` changes. Clients must run Soldat **1.7.1** (the server reports `Soldat Dedicated Server 1.7.1 - 2.8.2`).

The Steam release of Soldat uses a different server build (SteamCMD app 638500) that checks Steam tickets. This image is for the non-Steam client.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # SoldatServer package (soldatserver, maps/, bots/, soldat.ini ...)
    ├── Overlay/           # Your files, layered on top of Server/ (soldat.ini, mapslist.txt, logs/ land here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [base image's variables](https://github.com/LANCommander/LANCommander.Servers.Base#environment-variables).
The settings are written into `soldat.ini` on every start. Settings left empty are not touched, so you can set them in the ini instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `SOLDAT_SERVER_URL` | Server package (zip) | `https://static.soldat.pl/downloads/soldatserver2.8.2_1.7.1.1.zip` |
| `SOLDAT_SERVER_SHA256` | SHA256 of the package; empty = no check | `6ec94586...a867099` |
| `SOLDAT_PORT` | Game port (`-p`). The admin console is on the same TCP port, file downloads on this + 10 (TCP) | `23073` |
| `SOLDAT_LAN` | `true` turns off soldat.pl lobby and All-Seeing Eye registration (`Lobby_Register`, `ASE_Register`); `false` turns them on | `true` |
| `SOLDAT_SERVER_NAME` | `[NETWORK] Server_Name` | `Soldat Server` |
| `SOLDAT_GREETING` | `[NETWORK] Greeting_Message` | |
| `SOLDAT_SERVER_INFO` | `[NETWORK] Server_Info` | |
| `SOLDAT_MAX_PLAYERS` | `[NETWORK] Max_Players` | `16` |
| `SOLDAT_MAX_SPECTATORS` | `[NETWORK] Max_Spectators` | |
| `SOLDAT_GAME_PASSWORD` | `[NETWORK] Game_Password` | |
| `SOLDAT_ADMIN_PASSWORD` | `[NETWORK] Admin_Password`. Without it the admin console is off | |
| `SOLDAT_GAME_TYPE` | `dm`, `pm`, `tm`, `ctf`, `rm`, `inf`, `htf` or the `GameStyle` number, see below | `ctf` |
| `SOLDAT_MAPS` | Map rotation, comma separated (`mapslist.txt`). Empty: every installed map for the game type. `keep`: leave `mapslist.txt` alone | |
| `SOLDAT_SCORE_LIMIT` | The game type's limit (`Capture_Limit`, `Deathmatch_Limit`, ...) | |
| `SOLDAT_TIME_LIMIT` | `[GAME] Time_Limit` in minutes | |
| `SOLDAT_RESPAWN_TIME` | `[GAME] Respawn_Time` in ticks (60 per second) | |
| `SOLDAT_FRIENDLY_FIRE` | `true`/`false`: `Friendly_Fire` | |
| `SOLDAT_BALANCE_TEAMS` | `true`/`false`: `Balance_Teams` | |
| `SOLDAT_REALISTIC` | `true`/`false`: `Realistic_Mode` | |
| `SOLDAT_SURVIVAL` | `true`/`false`: `Survival_Mode` | |
| `SOLDAT_BOTS` | Bot count: `Random_Bots`, or split over Alpha and Bravo (`Random_Bots_1`/`_2`) in team game types | |
| `SOLDAT_BOT_DIFFICULTY` | `[BOTS] Difficulty` | |
| `START_EXE` | Launcher | `/usr/local/bin/soldat-server` |
| `START_ARGS` | Appended to the `soldatserver` command line | |

Game types:

| `SOLDAT_GAME_TYPE` | `GameStyle` | Limit key | Default maps |
|--------------------|-------------|-----------|--------------|
| `dm` (Deathmatch) | 0 | `Deathmatch_Limit` | maps without a prefix |
| `pm` (Pointmatch) | 1 | `Pointmatch_Limit` | maps without a prefix |
| `tm` (Teammatch) | 2 | `Teammatch_Limit` | maps without a prefix |
| `ctf` (Capture the Flag) | 3 | `Capture_Limit` | `ctf_*` |
| `rm` (Rambomatch) | 4 | `Rambomatch_Limit` | maps without a prefix |
| `inf` (Infiltration) | 5 | `Infiltration_Limit` | `inf_*` |
| `htf` (Hold the Flag) | 6 | `Hold_Limit` | `htf_*` |

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/base:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/base:local -t lancommander/soldat:local .
```

---

## License

Soldat is distributed under its own license.
This repository contains only Docker build logic and helper scripts licensed under MIT.
