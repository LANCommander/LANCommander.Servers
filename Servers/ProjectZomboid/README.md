# Project Zomboid Server (Docker)

This image provides a Dockerized **Project Zomboid** dedicated server suitable for running a Project Zomboid multiplayer server in a clean, reproducible way.  
The image is designed for **headless operation**, automatically downloads and updates the game server via SteamCMD (anonymous login, app `380870`), configures the server from environment variables, and supports file overlaying using OverlayFS.

---

## Features

- Project Zomboid dedicated server (native 64-bit Linux, bundled Java runtime), current public build by default
- Automatically downloads and updates the game server via SteamCMD, including the first install on a fresh SteamCMD
- Older builds through Steam branches (`STEAM_BRANCH=legacy41`)
- Server name, player limit, passwords, ports and any other `.ini` setting set from environment variables
- JVM heap size set from an environment variable, without editing `ProjectZomboid64.json`
- Steam or no-Steam (`-nosteam`) mode
- Server console shown in `docker logs`
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  projectzomboid-server:
    image: lancommander/projectzomboid:latest
    container_name: my-projectzomboid-server

    # Expose game server ports
    ports:
      - "16261:16261/udp"  # Game traffic
      - "16262:16262/udp"  # Direct connections
      - "27015:27015/tcp"  # RCON (optional)

    # Bind mounts
    volumes:
      - ./config:/config      # Game server files, configuration and saves

    environment:
      PZ_SERVER_NAME: "myserver"
      PZ_ADMIN_PASSWORD: "change-me"
      PZ_PUBLIC_NAME: "My Project Zomboid Server"
      PZ_MAX_PLAYERS: "16"
      PZ_MEMORY: "4g"

    user: root

    # For overlayfs support
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    stop_grace_period: 30s
    restart: unless-stopped
```

The same file is in this directory as [`compose.yml`](compose.yml).

---

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Game files downloaded by SteamCMD (auto-created, about 3 GB)
    │   ├── ProjectZomboid64.json
    │   ├── java/
    │   ├── jre64/
    │   └── media/
    ├── Overlay/           # Files to overlay on the game directory (optional)
    ├── Merged/            # Overlayfs merged view (auto-created, if overlayfs enabled)
    ├── .overlay-work/     # Overlayfs work directory (auto-created)
    ├── Zomboid/           # The server's Zomboid folder (PZ_CACHE_DIR)
    │   ├── Server/
    │   │   ├── <name>.ini               # Server settings
    │   │   ├── <name>_SandboxVars.lua   # World/gameplay settings
    │   │   └── <name>_spawnregions.lua  # Where players can spawn
    │   ├── Saves/Multiplayer/<name>/    # The world
    │   ├── db/<name>.db                 # Player accounts
    │   ├── Logs/
    │   └── server-console.txt           # Console log of the current run
    ├── Scripts/
    │   └── Hooks/         # Script files in this directory get automatically executed if registered to a hook
    └── ...
```

The `config` directory **must be writable** by Docker. The `Server` directory is automatically created and populated by SteamCMD on first startup. `<name>` is `PZ_SERVER_NAME`.

---

## Configuration

### Server settings (`<name>.ini`)

On the first start the server writes `/config/Zomboid/Server/<name>.ini`, `<name>_SandboxVars.lua` and `<name>_spawnregions.lua` with default values. Edit them while the server is stopped.

On every start the image writes the `PZ_*` variables that are set into `<name>.ini` (see the table below). Any other `.ini` key can be set with `PZ_INI_<Key>`, e.g. `PZ_INI_SafehouseAllowLoot=false` or `PZ_INI_SpawnItems=Base.Hammer`. Variables left empty keep the value in the file.

### Gameplay (`<name>_SandboxVars.lua`)

Zombie population and behavior, loot, vehicles, XP multipliers, day length, character creation points and so on live in `<name>_SandboxVars.lua`; each option is documented in the file's comments. Most of them only affect parts of the world that haven't been generated yet, so set them before the first player joins, or delete `Zomboid/Saves/Multiplayer/<name>` to start a new world.

### Admin account

`PZ_ADMIN_PASSWORD` is passed with `-adminpassword` and sets the password of the admin account (`admin`, or `PZ_ADMIN_USERNAME`). Without it the server would wait for the password on the console on its first start.

### Steam mode

The server runs in Steam mode by default. With `PZ_STEAM=false` it runs with `-nosteam`, and clients then have to start the game with `-nosteam` too: Steam and no-Steam clients and servers can't connect to each other.

### Custom Scripts

You can create custom scripts in the `/config/Scripts/Hooks/{HookName}` directory to execute at various points in the container's startup. All scripts should be PowerShell scripts.

### File Overlaying

The overlay directory (`/config/Overlay`) allows you to overlay files on top of the game directory without copying files:
- Files in `/config/Overlay` will appear in the merged view at `/config/Merged`
- If a file exists in both `/config/Server` and `/config/Overlay`, the version in `/config/Overlay` takes precedence
- The game server runs from the merged directory

The container must run with `--cap-add SYS_ADMIN` or `--privileged`.

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `STEAM_APP_ID` | Steam app id of the dedicated server | `380870` |
| `STEAM_BRANCH` | Steam branch to install, e.g. `legacy41` for Build 41 | *(unset, public build)* |
| `START_EXE` | Server launcher | `pz-server` |
| `START_ARGS` | Extra arguments passed to the server | *(empty)* |
| `PZ_SERVER_NAME` | Name of the server's config and save set | `servertest` |
| `PZ_CACHE_DIR` | The server's Zomboid folder (config, saves, logs, accounts) | `/config/Zomboid` |
| `PZ_ADMIN_USERNAME` | Admin account name | *(unset, `admin`)* |
| `PZ_ADMIN_PASSWORD` | Admin account password | `changeme` |
| `PZ_MEMORY` | JVM heap (`-Xms`/`-Xmx`), e.g. `4g` | *(unset, from `ProjectZomboid64.json`)* |
| `PZ_STEAM` | `false` runs the server with `-nosteam` | `true` |
| `PZ_PUBLIC_NAME` | `PublicName`: name shown in the server browser | *(unset)* |
| `PZ_PUBLIC_DESCRIPTION` | `PublicDescription` | *(unset)* |
| `PZ_MAX_PLAYERS` | `MaxPlayers` | *(unset, stock: `32`)* |
| `PZ_PASSWORD` | `Password`: join password | *(unset, stock: none)* |
| `PZ_PORT` | `DefaultPort`: game port (UDP) | *(unset, stock: `16261`)* |
| `PZ_UDP_PORT` | `UDPPort`: direct connection port (UDP) | *(unset, stock: `16262`)* |
| `PZ_RCON_PORT` | `RCONPort` (TCP) | *(unset, stock: `27015`)* |
| `PZ_RCON_PASSWORD` | `RCONPassword`; RCON is off while it's empty | *(unset)* |
| `PZ_PUBLIC` | `Public`: list the server on the Steam server browser | *(unset, stock: `false`)* |
| `PZ_PVP` | `PVP` | *(unset, stock: `true`)* |
| `PZ_PAUSE_EMPTY` | `PauseEmpty`: stop the clock while nobody is online | *(unset, stock: `true`)* |
| `PZ_MAP` | `Map` | *(unset, stock: `Muldraugh, KY`)* |
| `PZ_MODS` | `Mods` | *(unset)* |
| `PZ_WORKSHOP_ITEMS` | `WorkshopItems` | *(unset)* |
| `PZ_INI_<Key>` | Sets any other `<Key>` in `<name>.ini` | |
| `HTTP_FILESERVER_ENABLED` | HTTP file server on port 80 (the game has nothing to serve) | `false` |

**Change the default admin password** with `PZ_ADMIN_PASSWORD`.

---

## Running the Server

```bash
mkdir -p config

docker run --rm -it \
  --user root \
  --cap-add SYS_ADMIN \
  --security-opt apparmor:unconfined \
  -p 16261:16261/udp \
  -p 16262:16262/udp \
  -v "$(pwd)/config:/config" \
  -e PZ_SERVER_NAME="myserver" \
  -e PZ_ADMIN_PASSWORD="change-me" \
  lancommander/projectzomboid:latest
```

---

## Troubleshooting

### `ERROR! Failed to install app '380870' (Missing configuration)`

A fresh SteamCMD fails the first install with this error until it has refreshed the app info. The `PreSteamInstallGame/10-BootstrapInstall.ps1` hook runs `app_info_update 1` and the install in one SteamCMD session (retrying up to three times) when `Server/steamapps/appmanifest_380870.acf` doesn't exist yet. If the first install was interrupted, delete that file and restart the container.

### Clients get "Server version is different"

Clients have to run the same build as the server. The image installs the current public build; set `STEAM_BRANCH` to match older clients (e.g. `legacy41`).

### The server is killed or runs out of memory

`ProjectZomboid64.json` asks for an 8 GB heap. Set `PZ_MEMORY` to what the host can spare (4 GB is plenty for a handful of players).

### Sandbox changes don't show up in game

Most sandbox options are applied when a part of the world is first generated. Change them before anyone joins, or delete `Zomboid/Saves/Multiplayer/<name>` to start a new world.

### "Waiting for response from Steam servers" at startup

In Steam mode the server waits up to about 40 seconds for Steam when it has no internet connection, then carries on.

### Harmless startup messages

`SLF4J(W): No SLF4J providers were found`, `Could not find icon`, `Missing ThumpSound for breakable object` and `Property Name not found: WindowShape` are printed on every start and don't affect the server.

---

## License

SteamCMD and game servers are distributed under their respective licenses.
This directory contains only Docker build logic and helper scripts licensed under MIT.
