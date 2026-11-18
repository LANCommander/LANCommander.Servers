# No One Lives Forever Server (Docker)

This image provides a Dockerized **The Operative: No One Lives Forever** dedicated server. NOLF (Monolith, 2000) ships a Windows-only dedicated server, `NolfServ.exe` (1.004), which the image runs under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs the retail `NolfServ.exe` with `-nowiz`, so its setup wizard is skipped
- Deathmatch and H.A.R.M. vs. UNITY
- Server name, port, player limit, password, level rotation, end conditions and gameplay options are environment variables, written into `NetHost.txt` on every start
- Loads the [NOLF Modernizer](https://heythere.coffee/nolf/) (`Custom/MODERNIZER.REZ`) when the install has it, so the server runs the same game code (1.006) as clients that use it
- Checks the level rotation against the levels in the loaded `.rez` files; an unknown level is dropped instead of hanging the server
- NolfServ is a GUI app, so it runs on a virtual display (Xvfb)
- GameSpy `\status\` queries on the game port for monitoring
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  nolf:
    image: lancommander/noonelivesforever:latest
    container_name: nolf

    ports:
      - "27888:27888/udp"

    volumes:
      - ./config:/config

    environment:
      NOLF_SERVER_NAME: "My NOLF Server"
      NOLF_GAME_TYPE: "deathmatch"
      NOLF_LEVELS: "001ThePad_DM,002Rebar_DM,005Unity_DM"
      NOLF_FRAG_LIMIT: "25"
      NOLF_TIME_LIMIT: "15"

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

No One Lives Forever is retail software with no public download. You must provide an install patched to **1.003** or later (the Game of the Year edition is 1.004), which includes `NolfServ.exe`, `server.dll` and the `.rez` files:

- copy the game folder (the one containing `NolfServ.exe`) to `config/Server/`, **or**
- set `NOLF_ARCHIVE_URL` to a zip of that folder, e.g. a LANCommander archive. It is downloaded and extracted on first start, if `Server/NolfServ.exe` doesn't exist yet. `Movies/` and `EReg/` are left out.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # NOLF install (NolfServ.exe, server.dll, NOLF.REZ, Custom/ ...)
    ├── Overlay/           # Your files, layered on top of Server/ (the generated NetHost.txt and startup.txt land here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE#environment).
The `NOLF_*` server settings are written into `NetHost.txt` on every start. Settings left empty are not touched, so you can set them in that file instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `NOLF_SERVER_NAME` | Server name, at most 24 characters (`NetSessionName`) | `No One Lives Forever` |
| `NOLF_GAME_TYPE` | `deathmatch` or `harm` (H.A.R.M. vs. UNITY) | `deathmatch` |
| `NOLF_PORT` | Game and query port (`NetPort`) | `27888` |
| `NOLF_MAX_PLAYERS` | 2-16 (`NetMaxPlayers`) | `16` |
| `NOLF_PASSWORD` | Join password; empty = no password (`NetUsePassword`, `NetPassword`) | |
| `NOLF_LEVELS` | Comma-separated rotation of levels of the game type, e.g. `001ThePad_DM` or `Stasi_AM`. Unknown levels are skipped | every level of the type |
| `NOLF_FRAG_LIMIT` | Deathmatch: frags that end a level, 5-50, `0` = none (`NetEndFrags`) | `25` |
| `NOLF_SCORE_LIMIT` | H.A.R.M. vs. UNITY: team score that ends a level, 30-200, `0` = none (`NetEndScore`) | `50` |
| `NOLF_TIME_LIMIT` | Minutes that end a level, 5-60, `0` = none (`NetEndTime`) | `15` |
| `NOLF_SEND_BANDWIDTH` | Upload limit in bytes per second (`SendBandwidth`). The wizard's presets are 4000 (56k) to 10000000 (T3) | `1000000` |
| `NOLF_CUSTOM_REZ` | Comma-separated add-on `.rez` files in `Custom\` (or paths from the game folder) to load after the retail ones | `MODERNIZER.REZ` |
| `NOLF_RUN_SPEED` | Run speed in percent, 50-150 (`NetRunSpeed`) | |
| `NOLF_RESPAWN_SCALE` | Powerup respawn time in percent, 50-150 (`NetRespawnScale`) | |
| `NOLF_DEFAULT_WEAPON` | Weapon id players respawn with, 20 = none (`NetDefaultWeapon`). See [Docker.md](Documentation/Docker.md#weapons) | |
| `NOLF_WEAPONS_STAY` | Weapon pickups respawn immediately (`NetWeaponsStay`) | |
| `NOLF_HIT_LOCATION` | Location-based damage (`NetHitLocation`) | |
| `NOLF_AUDIO_TAUNTS` | Allow audio taunts (`NetAudioTaunts`) | |
| `NOLF_FALL_DAMAGE` | Fall damage in percent, 0-100 (`NetFallDamageScale`) | |
| `NOLF_ARMOR_HEALTH_BONUS` | Health given with armor pickups, percent of the armor, 0-100 (`NetArmorHealthPercent`) | |
| `NOLF_INTEL_SCORE` | H.A.R.M. vs. UNITY: points for capturing intelligence, 5-50 (`NetIntelScore`) | |
| `NOLF_FRAG_SCORE` | H.A.R.M. vs. UNITY: frags add to the score (`NetFragScore`) | |
| `NOLF_FRIENDLY_FIRE` | H.A.R.M. vs. UNITY: friendly fire (`NetFriendlyFire`) | |
| `NOLF_ARCHIVE_URL` | Zip of the game folder, used if `Server/NolfServ.exe` is missing | |
| `WINE_XVFB` | Run on a virtual display. NolfServ needs one | `true` |
| `START_EXE` | Launcher | `/usr/local/bin/nolf-server` |
| `START_ARGS` | Added to the `NolfServ.exe` command line | |

Flags take `true`/`false` (or `1`/`0`).

Levels in the Game of the Year edition:

- **Deathmatch**: `001ThePad_DM`, `002Rebar_DM`, `003ChillKill_DM`, `004Lotsabrick_DM`, `005Unity_DM`, `006Highlands_DM`, `007ClubDead_DM`, `008Inc2001_DM`, `009SerpentClaw_DM`, `Abduction_DM`, `Checkmate_DM`, `Fastlane_DM`, `Guerilla_Night_DM`, `Guns & HockeyPucks_DM`, `Mudtown_DM`, `Ruination_DM`, `Ruins_DM`, `SpaceCruiser_DM`, `Subway_DM`
- **H.A.R.M. vs. UNITY**: `01ConstructionSite_AM`, `02Blizzard_AM`, `03Marrakech_AM`, `04CityInRuins_AM`, `05Beaujolais_AM`, `06Storm_AM`, `07Hydro_AM`, `Abduction_AM`, `Castle_AM`, `Cloud-City_AM`, `ColdColdGround_AM`, `GreatWall_AM`, `Oasis_AM`, `OrbitalDecay_AM`, `Protect_The_King_AM`, `Stasi_AM`, `Treetop Assault_AM`, `Zipper_AM`

The original release has only the first four deathmatch and first six H.A.R.M. vs. UNITY levels.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/noonelivesforever:local Servers/NoOneLivesForever
```

---

## License

No One Lives Forever and Wine are distributed under their respective licenses.
This directory contains only Docker build logic and helper scripts licensed under MIT.
