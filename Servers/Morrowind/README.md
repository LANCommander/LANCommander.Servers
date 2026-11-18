# The Elder Scrolls III: Morrowind Server (Docker)

This repository provides a Dockerized multiplayer server for **The Elder Scrolls III: Morrowind**, using [TES3MP](https://tes3mp.com/), the multiplayer fork of [OpenMW](https://openmw.org/). On first start it downloads the official Linux server package of the [TES3MP release](https://github.com/TES3MP/TES3MP/releases) you pick (the latest by default, currently 0.8.1), which holds the server (`tes3mp-server.x86_64`) and its Lua game logic (the CoreScripts). The server doesn't need Morrowind's data files, so you don't need to supply any files. Each player needs their own copy of Morrowind and the TES3MP client of the same version.
The image builds on [`lancommander/base`](https://github.com/LANCommander/LANCommander.Servers.Base). It supports file overlaying using OverlayFS.

---

## Features

- The official TES3MP Linux server: the latest release or the version you choose (`TES3MP_VERSION`), sha256-checked for known versions, or any TES3MP server package
- Switching versions keeps the world and backs up the old version's edited config and scripts
- One persistent, shared world: characters, cells, the world state and custom records are saved as JSON under `server/data/` in `Overlay/`
- The server's name, port, player limit, password and log level, and the most-used CoreScripts settings (game mode, difficulty, console, sharing), are environment variables
- LAN-only by default; one setting announces it to the official TES3MP master server
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  morrowind:
    image: lancommander/morrowind:latest
    container_name: morrowind

    ports:
      - "25565:25565/udp"

    volumes:
      - ./config:/config

    environment:
      TES3MP_VERSION: "latest"   # or e.g. "0.8.1"
      TES3MP_SERVER_NAME: "My Morrowind Server"
      TES3MP_MAX_PLAYERS: "16"
      TES3MP_PASSWORD: ""
      TES3MP_GAME_MODE: "Co-op"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The TES3MP browser only lists servers from the internet master server; there is no LAN discovery. On a LAN, players join by address: set `destinationAddress` (and `port`) in `tes3mp-client-default.cfg` next to `tes3mp.exe`, then start `tes3mp.exe`.

---

## Game Files

On first start `PostInitialization/20-InstallTES3MP.ps1` downloads the Linux server package of `TES3MP_VERSION` (11 MB) from the TES3MP GitHub releases and unpacks it into `config/Server/` (about 9 MB). The source tarball and the CoreScripts' `.git` folder are left out.

- `TES3MP_VERSION=latest` (the default) looks up the newest release that has a Linux x86_64 server package on every start, so a new TES3MP release is installed on the next restart. The newest GitHub release, `tes3mp-0.8.1-vr`, has no server package, so `latest` is currently 0.8.1. If GitHub can't be reached, the installed version keeps running (or 0.8.1 is installed on a fresh volume).
- A version (`0.8.1`, `0.8.0`, or a release tag like `tes3mp-0.8.1`) pins it. 0.8.1 and 0.8.0 are built into the image with their SHA-256, so they install without the GitHub API and are always hash-checked. Other versions are looked up on GitHub. Versions before 0.8.0 are refused: their server needs libGL, and 0.8 clients can't join them.
- `TES3MP_SERVER_URL` installs your own `.tar.gz` or `.zip` of a Linux TES3MP server instead (with `tes3mp-server.x86_64` and the CoreScripts at its root or in one folder), checked against `TES3MP_SERVER_SHA256` when that's set. Or copy the files into `config/Server/` yourself; the hook then leaves them alone.

It reinstalls only when the resolved package changes. When it replaces a different version, it empties `Server/` first and renames the old version's `tes3mp-server-default.cfg` and CoreScripts scripts in `Overlay/` to `<name>.bak-<old version>`, so the new version's files show through. The world in `Overlay/server/data/` is kept, but TES3MP doesn't promise that world data works across versions, so back it up before switching.

Clients must run the same version as the server. LANCommander's Morrowind package is the TES3MP 0.8.1 client (protocol 10, commit `68954091c5`). Pin `TES3MP_VERSION=0.8.1` to keep the server matching it even after a new release. They also need the content files listed in `server/data/requiredDataFiles.json`. By default that's the English or Russian `Morrowind.esm`, `Tribunal.esm` and `Bloodmoon.esm`, in that order.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # TES3MP: tes3mp-server.x86_64, lib/, resources/, server/ (CoreScripts)
    ├── Overlay/           # Your files, layered on top of Server/: the world (server/data/), edited configs, scripts, logs (.config/openmw/)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

Back up `Overlay/server/data/`; it holds every character and the whole shared world.

---

## Environment Variables

These are in addition to the [base image's variables](https://github.com/LANCommander/LANCommander.Servers.Base#environment).
The server settings are written into `tes3mp-server-default.cfg` and the CoreScripts settings into `server/scripts/config.lua` on every start. Settings left empty leave the file's current value alone, so you can edit the files in `Overlay/` instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `TES3MP_VERSION` | TES3MP release to install: `latest` or a version (`0.8.1`, `0.8.0`, ...; 0.8.0 and newer) | `latest` |
| `TES3MP_SERVER_URL` | Package to install instead of `TES3MP_VERSION` (`.tar.gz` or `.zip`, `http(s)://` or `file://`) | |
| `TES3MP_SERVER_SHA256` | Expected SHA-256 of the package. Empty: the built-in hash for 0.8.1/0.8.0, no check otherwise | |
| `TES3MP_PORT` | `[General] port` | `25565` |
| `TES3MP_LAN` | `true`: `[MasterServer] enabled = false`, LAN only. `false`: announced to `master.tes3mp.com` | `true` |
| `TES3MP_MAX_PLAYERS` | `[General] maximumPlayers` | `64` |
| `TES3MP_SERVER_NAME` | `[General] hostname` | `TES3MP Server` |
| `TES3MP_PASSWORD` | `[General] password`, required to join. Always written, so empty clears it | |
| `TES3MP_LOG_LEVEL` | `[General] logLevel`: 0 verbose, 1 info, 2 warnings, 3 errors, 4 fatal only | `1` |
| `TES3MP_GAME_MODE` | `config.gameMode`, the game mode shown in the server browser | (`Default`) |
| `TES3MP_DIFFICULTY` | `config.difficulty`, enforced for all players, -100 to 100 | (`0`) |
| `TES3MP_MAX_CLIENTS_PER_IP` | `config.maxClientsPerIP` | (`3`) |
| `TES3MP_ALLOW_CONSOLE` | `config.allowConsole`: players may use the `~` console | (`false`) |
| `TES3MP_PASS_TIME_WHEN_EMPTY` | `config.passTimeWhenEmpty`: world time passes with nobody online | (`false`) |
| `TES3MP_SHARE_JOURNAL` | `config.shareJournal`: quests and journal entries are shared by all players | (`true`) |
| `TES3MP_SHARE_MAP_EXPLORATION` | `config.shareMapExploration`: map exploration is shared by all players | (`false`) |
| `START_EXE` | Launcher | `/usr/local/bin/tes3mp-server` |
| `START_ARGS` | Extra arguments for `tes3mp-server.x86_64` | |

Values in parentheses are the CoreScripts' own defaults, which apply while the variable is empty.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

```bash
docker build -t lancommander/morrowind:local .
docker build --build-arg BASE_IMAGE=lancommander/base:local -t lancommander/morrowind:local .
```

---

## License

TES3MP and OpenMW are GPLv3; the CoreScripts are GPLv3 as well. They are downloaded at runtime and not included in the image. The Elder Scrolls III: Morrowind is a trademark of Bethesda Softworks / ZeniMax Media; its game files are not used or distributed by the server.
This repository contains only Docker build logic and helper scripts licensed under MIT.
