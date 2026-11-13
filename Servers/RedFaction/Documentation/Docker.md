---
sidebar_label: Docker
---

# Red Faction Docker Container

This Docker container runs a Red Faction dedicated server. It is built on the WINE image and runs the retail game's dedicated mode with Alpine Faction. The container doesn't download the game, so you provide the files.

## Quick Start

```yaml
services:
  redfaction:
    image: lancommander/redfaction:latest
    container_name: redfaction

    ports:
      - 7755:7755/udp

    volumes:
      - "/servers/Red Faction/Default:/config"

    environment:
      RF_SERVER_NAME: "My Red Faction Server"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

Copy a Red Faction 1.20 NA install (the folder with `RF.exe` and the `.vpp` files) into `Server/` before the first start. You can instead set `RF_ARCHIVE_URL` to a zip of that folder. Alpine Faction comes with the image.

## How It Starts

1. `PostInitialization/10-InitializeWinePrefix.ps1` (from the WINE image) creates the Wine prefix in `/config/wineprefix`.
2. `PostInitialization/20-InstallRedFaction.ps1` checks for `Server/RF.exe` (or `RF_120na.exe`). If it's missing and `RF_ARCHIVE_URL` is set, the hook downloads and extracts the archive and remounts the overlay. With `AF_INSTALL=true` it then copies the image's Alpine Faction files into `Merged/` wherever they differ, so they land in `Overlay/`.
3. `PostInitialization/30-ConfigureRedFaction.ps1` creates `<RF_CONFIG>.toml` from the image's default if it doesn't exist, then writes the non-empty `RF_*` settings into its top-level keys. It edits through `Merged/`, so the file lands in `Overlay/`.
4. `START_EXE` (`/usr/local/bin/rf-server`) runs `AlpineFactionLauncher.exe -game -exe-path <RF.exe> -ads <RF_CONFIG>.toml -port <RF_PORT> -lanonly -win32-console` under Wine. The launcher starts RF, injects Alpine Faction and exits, so the script then waits with `wineserver -w` until the game exits.

A successful start prints the full config and rotation, and ends with:

```
-- Game Initializing --
-- Alpine Faction Initializing --
-- Level Initializing: dm02.rfl (DM) --
Applying level-specific rules for server rotation index 0 (dm02.rfl)...
```

Each level change prints another `-- Level Initializing: <level> (<game type>) --` line. Alpine Faction's own log is `logs/AlpineFaction-dedicated-<RF_CONFIG>.log` in `Overlay/`.

## Configuration Options

### Ports

- **7755/udp**: Game, server info and LAN browser queries (`RF_PORT`)

### Environment Variables

See the [README](../README.md#environment-variables) for the full table.

### Server config

`Overlay/<RF_CONFIG>.toml` (`server.toml` by default) is an Alpine Faction dedicated server (ADS) config, and it's yours to edit. Only `server_name`, `max_players`, `password` and `rcon_password` are rewritten on start, and only when their `RF_*` variable is set. The full key reference is in Alpine Faction's [DEDICATED_SERVER_CONFIG.md](https://github.com/GooberRF/alpinefaction/blob/main/docs/reference/DEDICATED_SERVER_CONFIG.md), and [dedi.alpinefaction.com](https://dedi.alpinefaction.com) builds one in the browser.

The file has server settings at the top, then a `[base]` table with the rules for every level, then the rotation as `[[levels]]` entries played in order. A level picks its own game type and overrides rules in a `[levels.rules]` table:

```toml
[base]
game_type = "DM"
time_limit = 600                # seconds

[[levels]]
filename = "dm02"               # DM, from [base]

[[levels]]
filename = "ctf01"
[levels.rules]
game_type = "CTF"
cap_limit = 5

[[levels]]
filename = "dm10"
[levels.rules]
game_type = "GG"                # Gun Game
```

Game types are `DM`, `TDM`, `CTF`, `KOTH` (King of the Hill), `DC` (Damage Control), `REV` (Revolt), `RUN`, `ESC` (Escalation), `BAG`/`TBAG` (Bagman, Team Bagman), `PIT`, `WO` (Wipeout), `GG` (Gun Game), `SAL` (Salvage), `SCAV` (Scavenger) and `PAY` (Payload). Several need levels made for them (KOTH, DC, REV, RUN, ESC, SAL, SCAV, PAY ...). The stock levels are `dm01`-`dm20` (no `dm11` or `dm18`) and `ctf01`-`ctf07`. A rotation level that isn't installed is downloaded from FactionFiles at startup, which needs internet access, and dropped if that fails; add `-nodl` to `START_ARGS` to skip downloads. `dynamic_rotation = true` shuffles the rotation.

Players can vote with `vote level <level> [game type]`, `vote next`, `vote restart` and `vote extend` in chat. Each vote has its own `[vote_*]` table.

Game types and mutators added by Alpine Faction need Alpine Faction clients. Other clients spectate while one is active.

### Hooks

| Hook | When |
|------|------|
| `PreInstallRedFaction` / `PostInstallRedFaction` | Around the game file check/download and the Alpine Faction copy |
| `PreInitializeWinePrefix` / `PostInitializeWinePrefix` | Around Wine prefix creation (WINE image) |

Put `.ps1` scripts in `config/Scripts/Hooks/<HookName>/`.

## Troubleshooting

- **Server not in the LAN browser**: the browser finds servers by UDP broadcast, so the container needs its own LAN address (macvlan/ipvlan) or host networking. Clients can join by IP through port mapping; with a port other than 7755, give `<ip>:<port>`.
- **Server not in the internet browser**: `RF_LAN_ONLY` is `true` by default. Set it to `false` to announce the server to the game tracker set in the `GameTracker` registry value.
- **A level is missing from the rotation**: it isn't installed and couldn't be downloaded. Put the `.rfl` (or its `.vpp`) in `Overlay/user_maps/multi/`.
- **Alpine Faction says the executable is unsupported**: it needs the original 1.20 NA `RF.exe`. Point `RF_EXE` at it.
- **Changing the config without a restart**: `sv_loadconfig` over RCON (a `full_admin` rcon profile) reloads the TOML.
- **No console commands**: the dedicated console reads from its own Win32 console, not `docker attach`. Use RCON from a game client (`rcon_request <password>`, then `rcon <command>`).
