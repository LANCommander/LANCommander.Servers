# Age of Chivalry Server (Docker)

This repository provides a Dockerized **Age of Chivalry** game server suitable for running an AoC server in a clean, reproducible way.  
The image is designed for **headless operation**, automatically downloads and updates the game server via SteamCMD (anonymous login, app `17515`), and supports file overlaying using OverlayFS.

---

## Features

- Age of Chivalry dedicated server (version `1.0.0.6`, the final release)
- Runs the native 32-bit Linux Orange Box dedicated server (`srcds_i486`) through `srcds_run`
- Automatically downloads and updates the game server via SteamCMD, including the first install on a fresh SteamCMD
- Supports file overlaying using OverlayFS (no file copying required)
- Optional HTTP file server for FastDL
- Updates the game server on every start, with optional file validation

## Docker Compose Example

```yaml
services:
  aoc-server:
    image: lancommander/ageofchivalry:latest
    container_name: my-aoc-server

    # Expose game server ports
    ports:
      - "27015:27015/udp"  # Game server port
      - "27015:27015/tcp"  # RCON
      - "27020:27020/udp"  # SourceTV port (optional)

    # Bind mounts
    volumes:
      - ./config:/config      # Game server configuration and overlay directory

    environment:
      START_ARGS: "-game ageofchivalry -console -norestart -insecure +maxplayers 16 +map aoc_battleground"

    user: root

    # The server only prints its console when stdout is a TTY
    tty: true

    # For overlayfs support
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

---

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/              # Game files downloaded by SteamCMD (auto-created, about 3.9 GB)
    │   └── ageofchivalry/   # Age of Chivalry game directory
    ├── Overlay/             # Files to overlay on game directory (optional)
    │   └── ageofchivalry/   # Age of Chivalry overlay directory
    │       ├── maps/        # Custom maps
    │       ├── cfg/         # Server configuration files (server.cfg, etc.)
    │       └── ...          # Any other files you want to overlay
    ├── Merged/              # Overlayfs merged view (auto-created, if overlayfs enabled)
    ├── .overlay-work/       # Overlayfs work directory (auto-created)
    ├── Scripts/
    │   └── Hooks/           # Script files in this directory get automatically executed if registered to a hook
    └── ...                  # Your game server configuration files
```

The `config` directory **must be writable** by Docker. The `Server` directory is automatically created and populated by SteamCMD on first startup.

---

## Configuration

### Custom Scripts

You can create custom scripts in the `/config/Scripts/Hooks/{HookName}` directory to execute at various points in the container's startup. This is useful for:
- Installing additional dependencies
- Setting up environment variables
- Downloading additional files
- Modifying configuration before the game server starts

All scripts should be PowerShell scripts.

### File Overlaying

The overlay directory (`/config/Overlay`) allows you to overlay files on top of the game directory without copying files. This is useful for:
- Replacing game files (maps, scripts, assets)
- Adding custom content
- Modifying game files without touching the base installation

**How it works:**
- Files in `/config/Overlay` will appear in the merged view at `/config/Merged`
- If a file exists in both `/config/Server` and `/config/Overlay`, the version in `/config/Overlay` takes precedence
- The game server runs from the merged directory

**Requirements:**
- Container must run with `--cap-add SYS_ADMIN` or `--privileged` flag

**Example overlay structure:**
```text
/config/Overlay/
└── ageofchivalry/
    ├── cfg/
    │   └── server.cfg
    ├── maps/
    │   └── aoc_custom.bsp
    └── mapcycle.txt
```

### `server.cfg`, LAN mode and RCON

The stock `ageofchivalry/cfg/server.cfg` only sets `hostname "Age of Chivalry Server"` and `sv_lan 0`. It runs on every map load, after the command line, so it overrides `+sv_lan` and `+hostname` in `START_ARGS`. Put your own `server.cfg` in `/config/Overlay/ageofchivalry/cfg/` and set `hostname`, `sv_lan 1` (for LAN play) and `rcon_password` there.

### Maps

The server ships 18 maps: `aoc_battleground`, `aoc_darkforest`, `aoc_fight_pub`, `aoc_firecrag`, `aoc_galadan`, `aoc_helms_deep`, `aoc_invasion`, `aoc_meleefields`, `aoc_monastery`, `aoc_overlook`, `aoc_siege`, `aoc_sorrow`, `aoc_stoneshill`, `aoc_theshore`, `aoc_tombs`, `aoc_tournament`, `aoc_valley` and `aoc_westerlyn`. The rotation is in `ageofchivalry/mapcycle.txt`, and each map also has a `maps/<map>.cfg` with its display name, `time` value and the next map for each winning side. See [Documentation/Docker.md](Documentation/Docker.md) for details.

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `STEAM_APP_ID` | Steam app id of the dedicated server | `17515` |
| `STEAM_VALIDATE` | Validate the game files when SteamCMD updates on startup (`true`/`false`) | `true` |
| `START_EXE` | Server executable (relative to the game directory) | `srcds_run` |
| `START_ARGS` | Arguments used to start the game server | `"-game ageofchivalry -console -norestart -insecure +maxplayers 16 +map aoc_battleground"` |
| `HTTP_FILESERVER_ENABLED` | Serve custom content over HTTP (FastDL) on port 80 | `true` |
| `HTTP_FILESERVER_WEB_ROOT` | Directory served by the HTTP file server | `/config/Merged/ageofchivalry` |
| `HTTP_FILESERVER_FILE_PATTERN` | Regex of request paths the file server allows | maps, materials, models and sound files |

### `STEAM_VALIDATE`

SteamCMD updates the game server on every container start. With `STEAM_VALIDATE` set to `true` (the default) it also checks every game file, which takes longer; set it to `false` for faster restarts.

### `START_ARGS`

Arguments passed to the game server executable at startup. Default:

```bash
START_ARGS="-game ageofchivalry -console -norestart -insecure +maxplayers 16 +map aoc_battleground"
```

`-norestart` makes `srcds_run` replace itself with the server process instead of restarting it in a loop, so the container stops when the server does and the restart policy takes over. `-insecure` disables VAC. You can customize this with additional server parameters:

```bash
START_ARGS="-game ageofchivalry -console -norestart -insecure +maxplayers 32 +map aoc_theshore"
```

---

## Running the Server

### Basic run (with automatic updates)

```bash
mkdir -p config

docker run --rm -it \
  --user root \
  --cap-add SYS_ADMIN \
  --security-opt apparmor:unconfined \
  -p 27015:27015/udp \
  -p 27015:27015/tcp \
  -v "$(pwd)/config:/config" \
  -e START_ARGS="-game ageofchivalry -console -norestart -insecure +maxplayers 16 +map aoc_battleground" \
  lancommander/ageofchivalry:latest
```

### Skip file validation on startup

```bash
docker run --rm -it \
  --user root \
  --cap-add SYS_ADMIN \
  --security-opt apparmor:unconfined \
  -p 27015:27015/udp \
  -v "$(pwd)/config:/config" \
  -e STEAM_VALIDATE="false" \
  lancommander/ageofchivalry:latest
```

---

## OverlayFS Details

The container uses Linux OverlayFS to merge the server directory (`/config/Server`) with the overlay directory (`/config/Overlay`) into a merged view (`/config/Merged`). This allows you to:

1. **Replace files** without modifying the base game installation
2. **Add files** that don't exist in the base game
3. **Avoid copying** large files - OverlayFS is a union filesystem

**Technical details:**
- **Lower layer**: `/config/Server` (base game files from SteamCMD)
- **Upper layer**: `/config/Overlay` (your custom files)
- **Merged view**: `/config/Merged` (where the game server runs from)
- **Work directory**: `/config/.overlay-work` (required by OverlayFS)

If OverlayFS cannot be mounted (e.g., missing privileges), the container will fall back to using `/config/Server` directly and log a warning.

---

## Troubleshooting

### No server console output in `docker logs`

The 2007 server only writes its console (map loads, `Network: IP ...` and so on) to stdout when stdout is a TTY. Without one, the log stops after `Using SSE2 Optimised binary.` while the server runs normally. Set `tty: true` in compose (or `-t` with `docker run`), or add `-condebug` to `START_ARGS` to write `ageofchivalry/console.log`.

### OverlayFS not working

If you see warnings about OverlayFS, ensure your container has the required privileges:

```bash
# Option 1: Add SYS_ADMIN capability (recommended)
docker run --cap-add SYS_ADMIN --security-opt apparmor:unconfined ...

# Option 2: Use privileged mode (less secure)
docker run --privileged ...
```

### Game server not starting

1. Verify `START_ARGS` contains `-game ageofchivalry` and a valid `+map`
2. Check container logs: `docker logs <container-name>`
3. Ensure the server directory was downloaded: check `/config/Server/ageofchivalry` in the container
4. Verify the server configuration files are correct (e.g., `server.cfg`)

### `+sv_lan 1` or `+hostname` has no effect

The stock `ageofchivalry/cfg/server.cfg` sets `hostname` and `sv_lan 0` on every map load, after the command line. Set them in your own `/config/Overlay/ageofchivalry/cfg/server.cfg`. RCON listens on the container's IP address, not on `127.0.0.1`.

### SourceMod / MetaMod

The image doesn't install SourceMod. Age of Chivalry runs on the original 2007 Orange Box engine, and MetaMod:Source 1.11 and 1.12 (`metamod.2.ep2.so`) both hang the server right after `Network: IP ..., mode MP, dedicated Yes` at startup.

### `ERROR! Failed to install app '17515' (Missing configuration)`

A fresh SteamCMD can fail the first install with this error until it has refreshed the app info. The `PreSteamInstallGame/10-BootstrapInstall.ps1` hook runs `app_info_update 1` and the install in one SteamCMD session when `Server/steamapps/appmanifest_17515.acf` doesn't exist yet. If the first install was interrupted, delete that file and restart the container.

### Harmless startup messages

`Unable to load Steam library.`, `Particles: Missing '...pcf'`, `Failed to load $include VMT file`, `Error Vertex File for 'AoC_Weapon/w_spear.mdl'` and `ConVarRef mat_dxlevel doesn't point to an existing ConVar` appear on every start. `Unable to load Steam library` refers to the legacy Steam ticket validation library, which the depot doesn't include; the server loads maps and answers queries without it. Run with `-insecure` and `sv_lan 1` so it doesn't try to validate clients with Steam.

### Permission errors

If you encounter permission errors:

1. Ensure mounted volumes are writable
2. Check file ownership in the container
3. Review logs for specific permission error messages

---

## License

SteamCMD and game servers are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
