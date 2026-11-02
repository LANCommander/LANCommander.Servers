# Vietcong Server (Docker)

This repository provides a Dockerized **Vietcong** (2003) dedicated server. Vietcong has no Linux server, so the image runs the game's own dedicated server launcher, `vcded.exe -dedicated <file>.ded`, under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers.WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs the retail v1.60 `vcded.exe` headless under Wine and Xvfb. Its setup dialog is skipped.
- Native Microsoft DirectPlay is installed into the Wine prefix automatically. Wine's builtin DirectPlay 8 can't host games.
- The server definition (`.ded`) is generated from environment variables, and the map rotation is checked against the base game's map/mode list
- The chat log (`dev/chatlog.txt`) is streamed to `docker logs`
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  vietcong:
    image: lancommander/vietcong:latest
    container_name: vietcong

    ports:
      - "5425:5425/udp"
      - "6073:6073/udp"

    volumes:
      - ./config:/config

    environment:
      VC_SERVER_NAME: "My Vietcong Server"
      VC_ADMIN_PASSWORD: "changeme"
      VC_MISSIONS: "WaterFall, DM, time, 20:00; Arroyo, TDM, time, 20:00; Stream, CTF, points, 5"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

DirectPlay is LAN-oriented and also opens dynamic UDP ports. A network where the container gets its own LAN IP (macvlan/ipvlan, or `network_mode: host`) is more reliable than port mapping.

---

## Game Files

Vietcong is retail software with no public download. You must provide a **v1.60** install (the folder with `vcded.exe`, `game.dll`, `logs.dll` and the `vietcong_*.cbf` archives):

- copy it to `config/Server/`, **or**
- set `VC_ARCHIVE_URL` to a zip of that folder. It is downloaded and extracted on first start, if `Server/vcded.exe` doesn't exist yet.

Clients must run the same patch level (v1.60, protocol `gamever 198`). Installs with VCStarter work too. VCStarter clients can't join HradBa servers, so HradBa is off by default.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Vietcong v1.60 install (vcded.exe, game.dll, vietcong_*.cbf)
    ├── Overlay/           # Your files, layered on top of Server/ (Dedicated/*.ded, logs, dev/ land here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix with native DirectPlay (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers.WINE#environment).
The `VC_*` settings are written to `Dedicated/<VC_DED_NAME>.ded` on every start.

| Variable | `.ded` setting | Default |
|----------|----------------|---------|
| `VC_DED_NAME` | file name, without `.ded` | `lancommander` |
| `VC_SERVER_NAME` | `Server name` | `Vietcong Server` |
| `VC_PORT` | `Port number` | `5425` |
| `VC_MAX_PLAYERS` | `Maximum players` (each map also has its own cap) | `32` |
| `VC_PASSWORD` | `Password` (join password) | |
| `VC_ADMIN_PASSWORD` | `Admin password` (in-game `startadmin <password>`) | |
| `VC_JOIN_MESSAGE` | `Server join message` | |
| `VC_INTERNET_GAME` | `Internet game` (register with the master server) | `false` |
| `VC_FRIENDLY_FIRE` | `Friendly fire` | `true` |
| `VC_AUTO_BALANCE` | `Auto balanced teams` | `true` |
| `VC_HRADBA` | `Hradba enable` / `Hradba auto update` (anti-cheat) | `false` |
| `VC_VOICE_CHAT` | `Voice chat`: 0 off, 1 low, 2 high quality | `0` |
| `VC_MISSIONS` | `Mission = ...` lines, see below | DM on the six DM maps, 20 min each |
| `VC_SETTINGS` | any other setting, as `Key = value` pairs separated by `;` | |
| `VC_ADDON` | `-addon <name>` (e.g. `fistalpha`, `reddawn`; must be installed) | |
| `VC_EXTRA_ARGS` | raw arguments appended to the command line | |
| `VC_ARCHIVE_URL` | zip of the game folder, used if `Server/vcded.exe` is missing | |

### Map rotation

`VC_MISSIONS` is a `;`-separated list of `Map, Mode, EndRule, Value` entries. `EndRule` is `time` (minutes, or `mm:ss`) or `points`.
The default is `WaterFall, DM, time, 20:00; Arroyo, DM, time, 20:00; HalongPort, DM, time, 20:00; NVABase, DM, time, 20:00; Storm, DM, time, 20:00; Stream, DM, time, 20:00`.

Base v1.60 maps and their modes:

| Map | Modes |
|-----|-------|
| Ambush | RW, Coop |
| Arroyo | ATG, CTF, DM, TDM, LMS |
| Bahnar | ATG, RW, TT, CTF |
| HalongPort | ATG, CTF, DM, TDM, LMS |
| NVABase | ATG, CTF, Coop, DM, RW, TDM, LMS |
| RadioRelay | ATG, RW, Coop |
| Storm | ATG, Coop, DM, LMS, RW, TDM, TT, CTF |
| WaterFall | ATG, CTF, DM, TDM, LMS |
| Stream | ATG, Coop, DM, LMS, RW, TDM, TT, CTF |

Mode names are the abbreviations from vcded's setup dialog (for example DM deathmatch, TDM team deathmatch, CTF capture the flag; ATG is round-based team deathmatch). Each map also has its own player cap (WaterFall: 10), which the server reports instead of `VC_MAX_PLAYERS` when it's lower.

### Other settings

`VC_SETTINGS` sets any other `.ded` key, for example `Vietnam mode = 1; Team kill = 5; CTF respawn time = 15`. The full key list is in [Documentation/Docker.md](Documentation/Docker.md#server-definition-file).

To manage the `.ded` file yourself, save one from vcded's setup dialog (or edit the generated one) and delete its first line, the `// Generated by the LANCommander image` marker. A file without the marker is never overwritten.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/vietcong:local .
```

The DirectX February 2010 redistributable (source of the DirectPlay DLLs) is downloaded at build time and verified by sha256. See `DIRECTX_REDIST_URL` / `DIRECTX_REDIST_SHA256` in the Dockerfile.

---

## License

Vietcong, Wine and the DirectX redistributable are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.
