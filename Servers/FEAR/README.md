# F.E.A.R. Server (Docker)

This repository provides a Dockerized **F.E.A.R.** multiplayer dedicated server. F.E.A.R. (Monolith, 2005) and its free multiplayer release F.E.A.R. Combat ship a Windows-only stand-alone server, `FEARServer.exe`. The image runs the 1.08 build of it under Wine, including the community SEC2 patch when the install has it.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers.WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs `FEARServer.exe -userdirectory <dir> -optionsfile <name>`, which hosts right away with no setup dialog
- Server name, port, game type, map rotation, limits and passwords are environment variables, written into the server options file on every start
- All ten game types: Deathmatch, Team Deathmatch, Elimination, Team Elimination, SlowMo Deathmatch, Team SlowMo Deathmatch, Capture the Flag, SlowMo CTF, Conquer All and Control
- The server console is copied to `docker logs`
- FEARServer is a GUI app, so it runs on a virtual display (Xvfb)
- GameSpy `\status\` queries on the game port for monitoring
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  fear:
    image: lancommander/fear:latest
    container_name: fear

    ports:
      - "27888:27888/udp"

    volumes:
      - ./config:/config

    environment:
      FEAR_SERVER_NAME: "My F.E.A.R. Server"
      FEAR_GAME_TYPE: "deathmatch"
      FEAR_TIME_LIMIT: "15"
      FEAR_SCORE_LIMIT: "50"
      FEAR_SCMD_PASSWORD: "changeme"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

---

## Game Files

F.E.A.R. is retail software with no public download. You must provide a F.E.A.R. Combat (or retail F.E.A.R. multiplayer) 1.08 install, the folder that contains `FEARServer.exe`, `EngineServer.dll`, `GameDatabase.dll`, `Default.archcfg` and the `*.Arch00` archives:

- copy that folder to `config/Server/`, **or**
- set `FEAR_ARCHIVE_URL` to a zip of that folder, e.g. a LANCommander archive. It is downloaded and extracted on first start, if `Server/FEARServer.exe` doesn't exist yet.

If the install has the SEC2 patch (a `SEC2/` folder listed in `Default.archcfg`), the server loads it. Clients and server should run the same SEC2 version.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # F.E.A.R. install (FEARServer.exe, *.Arch00, SEC2/ ...)
    │   └── Monolith Productions/FEARCombat/   # Server user directory (FEAR_USER_DIR)
    ├── Overlay/           # Your files, layered on top of Server/ (the generated options file,
    │                      # MPCustomizations.txt edits, ban lists and the server log land here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers.WINE#environment).
The `FEAR_*` server settings are written into `<FEAR_USER_DIR>/ServerOptions/<FEAR_CONFIG>.txt` on every start. Settings left empty are not touched, so you can set them in that file instead. The name, player count, limits and map list apply to the section of the selected game type.

| Variable | Description | Default |
|----------|-------------|---------|
| `FEAR_USER_DIR` | Server user directory, relative to the game folder (`-userdirectory`). Holds `ServerOptions/`, `MPCustomizations.txt`, ban lists and the log. Created if missing | `Monolith Productions/FEARCombat` |
| `FEAR_CONFIG` | Options file name without `.txt` (`-optionsfile`). Created if missing | `lancommander` |
| `FEAR_SERVER_NAME` | `SessionName` | `F.E.A.R. Combat` |
| `FEAR_SERVER_MESSAGE` | `ServerMessage`, shown to joining players. `\n` is a line break | |
| `FEAR_PORT` | Game and query port (`Port`) | `27888` |
| `FEAR_GAME_TYPE` | `deathmatch`, `teamdeathmatch`, `elimination`, `teamelimination`, `slowmodeathmatch`, `teamslowmodeathmatch`, `ctf`, `slowmoctf`, `conquerall`, `control` (`GameType`) | `deathmatch` |
| `FEAR_MAPS` | Comma-separated rotation (`Mission0`, `Mission1` ...). A bare name goes in `Worlds\ReleaseMultiplayer\`; give a path with a backslash for custom maps. Empty = every map of the game type; `config` = keep the file's list | |
| `FEAR_MAX_PLAYERS` | `MaxPlayers` | `16` |
| `FEAR_SCORE_LIMIT` | `ScoreLimit` (frags, points or captures) | |
| `FEAR_TIME_LIMIT` | Minutes (`TimeLimit`) | |
| `FEAR_ROUNDS` | `NumRounds` | |
| `FEAR_FRIENDLY_FIRE` | `FriendlyFire` (team game types) | |
| `FEAR_PASSWORD` | Join password (`Password`, sets `UsePassword`). Empty = open server | |
| `FEAR_SCMD_PASSWORD` | SCMD admin password (`ScmdPassword`, sets `AllowScmdCommands`). Empty = SCMD off | |
| `FEAR_LAN_ONLY` | `LANOnly` | `true` |
| `FEAR_CONTENT_DOWNLOAD` | `AllowContentDownload` (custom content to clients) | |
| `FEAR_ARCHIVE_URL` | Zip of the game folder, used if `Server/FEARServer.exe` is missing | |
| `WINE_XVFB` | Run on a virtual display. FEARServer needs one | `true` |
| `START_EXE` | Launcher | `/usr/local/bin/fear-server` |
| `START_ARGS` | Added to the `FEARServer.exe` command line, e.g. `-mpcustomizations MyCustomizations.txt` | |

Stock maps (every game type uses the same names): `Asylum`, `Cafeteria`, `Campus`, `Construction`, `DeadWood`, `Depot`, `Docks`, `Evac`, `Facility`, `Factory`, `Heliport`, `HighTech`, `Labs`, `Office`, `Refinery`, `SpillKill`, `Stockpile`, `Streets`, `WaterWorks`.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/fear:local .
```

---

## License

F.E.A.R., the SEC2 patch and Wine are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
