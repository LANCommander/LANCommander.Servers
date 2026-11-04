# Ice Lakes Server (Docker)

This repository provides a Dockerized **Ice Lakes** dedicated server suitable for running an Ice Lakes fishing server in a clean, reproducible way.  
The image is designed for **headless operation**, automatically downloads and updates the game server via SteamCMD (anonymous login, app `460300`), configures the server from environment variables, and supports file overlaying using OverlayFS.

---

## Features

- Ice Lakes dedicated server (native 64-bit Linux Unity build, `IceLakes_Server.x86_64`)
- Automatically downloads and updates the game server via SteamCMD, including the first install on a fresh SteamCMD
- Server name, player limit, passwords, ports and gameplay options set from environment variables
- Map rotation configured with an overlaid `server.cfg`
- Server log shown in `docker logs`
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  icelakes-server:
    image: lancommander/icelakes:latest
    container_name: my-icelakes-server

    # Expose game server ports
    ports:
      - "13300:13300/udp"  # Game traffic
      - "27015:27015/udp"  # Server queries / LAN server browser
      - "8766:8766/udp"    # Steam game server

    # Bind mounts
    volumes:
      - ./config:/config      # Game server configuration and overlay directory

    environment:
      ICELAKES_SERVER_NAME: "My Ice Lakes Server"
      ICELAKES_MAX_PLAYERS: "16"
      ICELAKES_ADMIN_PASSWORD: "change-me"

    user: root

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
    ├── Server/            # Game files downloaded by SteamCMD (auto-created, about 1.8 GB)
    │   ├── IceLakes_Server.x86_64
    │   ├── IceLakes_Server_Data/
    │   └── server.cfg     # Stock server configuration
    ├── Overlay/           # Files to overlay on the game directory (optional)
    │   └── server.cfg     # Your server configuration (created by the image when ICELAKES_* are set)
    ├── Merged/            # Overlayfs merged view (auto-created, if overlayfs enabled)
    ├── .overlay-work/     # Overlayfs work directory (auto-created)
    ├── Logs/
    │   └── IceLakes_Server.log  # Server log of the current run
    ├── Scripts/
    │   └── Hooks/         # Script files in this directory get automatically executed if registered to a hook
    └── ...
```

The `config` directory **must be writable** by Docker. The `Server` directory is automatically created and populated by SteamCMD on first startup.

---

## Configuration

### `server.cfg`

The server reads `server.cfg` in the game directory. Its `[Server]` section holds the server settings; `[Map1]`, `[Map2]`, ... sections are the map rotation, each with a `Level`, `GameMode`, `TimeLimit`, `Season` and `DayTime`. The stock file lists the valid values in its comments.

On every start the image writes the `ICELAKES_*` variables that are set into the `[Server]` section of `/config/Merged/server.cfg`. The first change copies the file to `/config/Overlay/server.cfg`, so SteamCMD updates don't undo it. Variables left empty keep the value in the file.

To change the map rotation, edit `/config/Overlay/server.cfg` (copy it from `/config/Server/server.cfg` if it doesn't exist yet) and restart the container.

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
| `STEAM_APP_ID` | Steam app id of the dedicated server | `460300` |
| `STEAM_VALIDATE` | Validate the game files when SteamCMD updates on startup (`true`/`false`) | `true` |
| `START_EXE` | Server launcher | `icelakes-server` |
| `START_ARGS` | Arguments passed to `IceLakes_Server.x86_64` | `"-batchmode -nographics"` |
| `ICELAKES_SERVER_NAME` | `[Server] Name`: name shown in the server browser | *(unset, stock: `Dedicated Server`)* |
| `ICELAKES_MAX_PLAYERS` | `[Server] MaxPlayers` | *(unset, stock: `32`)* |
| `ICELAKES_PASSWORD` | `[Server] Password`: join password | *(unset, stock: none)* |
| `ICELAKES_ADMIN_PASSWORD` | `[Server] AdminPassword` | *(unset, stock: `admin`)* |
| `ICELAKES_PORT` | `[Server] Port`: game port (UDP) | *(unset, stock: `13300`)* |
| `ICELAKES_QUERY_PORT` | `[Server] OutPort`: server query port (UDP) | *(unset, stock: `27015`)* |
| `ICELAKES_FISH_NOTIFICATIONS` | `[Server] FishNotifications` (`1`/`0`) | *(unset, stock: `1`)* |
| `ICELAKES_FISH_FIGHT` | `[Server] FishFight` (`1`/`0`) | *(unset, stock: `1`)* |
| `ICELAKES_BATTLE_ROYALE` | `[Server] BattleRoyale` (`1`/`0`) | *(unset, stock: `0`)* |
| `ICELAKES_LOG_FILE` | Server log file, followed to `docker logs` | `/config/Logs/IceLakes_Server.log` |
| `HTTP_FILESERVER_ENABLED` | HTTP file server on port 80 (the game has nothing to serve) | `false` |

**Change the stock `AdminPassword`** (`admin`) with `ICELAKES_ADMIN_PASSWORD`.

---

## Running the Server

```bash
mkdir -p config

docker run --rm -it \
  --user root \
  --cap-add SYS_ADMIN \
  --security-opt apparmor:unconfined \
  -p 13300:13300/udp \
  -p 27015:27015/udp \
  -p 8766:8766/udp \
  -v "$(pwd)/config:/config" \
  -e ICELAKES_SERVER_NAME="My Ice Lakes Server" \
  -e ICELAKES_ADMIN_PASSWORD="change-me" \
  lancommander/icelakes:latest
```

---

## Troubleshooting

### `ERROR! Failed to install app '460300' (Missing configuration)`

A fresh SteamCMD fails the first install with this error until it has refreshed the app info. The `PreSteamInstallGame/10-BootstrapInstall.ps1` hook runs `app_info_update 1` and the install in one SteamCMD session (retrying up to three times) when `Server/steamapps/appmanifest_460300.acf` doesn't exist yet. If the first install was interrupted, delete that file and restart the container.

### Server log missing from `docker logs`

Don't pass `-logFile` in `START_ARGS`; `icelakes-server` adds it. Unity can't reopen the container's stdout as the unprivileged server user, so `-logFile /dev/stdout` makes the server fall back to `~/.config/unity3d/Player.log`.

### Settings in `server.cfg` are reset

Edit `/config/Overlay/server.cfg`, not `/config/Server/server.cfg`: SteamCMD restores the stock file on updates. `ICELAKES_*` variables that are set override the matching `[Server]` keys on every start.

### Harmless startup messages

`Couldn't load savedata: IceLakesData.bytes`, `Couldn't read username from steam`, `AddComponent with MonoBehaviour is not allowed` and `DontDestroyOnLoad only work for root GameObjects` are printed on every start and don't affect the server.

---

## License

SteamCMD and game servers are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
