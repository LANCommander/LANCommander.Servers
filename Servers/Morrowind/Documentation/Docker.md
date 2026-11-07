---
sidebar_label: Docker
---

# The Elder Scrolls III: Morrowind Docker Container

This Docker container runs a TES3MP multiplayer server for The Elder Scrolls III: Morrowind. It is built on the base image and runs the official TES3MP 0.8.1 Linux server (`tes3mp-server.x86_64`, protocol 10, commit `68954091c5`). The server package is downloaded on first start. The server doesn't use Morrowind's data files, so you don't need to supply game files.

## Quick Start

```yaml
services:
  morrowind:
    image: lancommander/morrowind:latest
    container_name: morrowind

    ports:
      - 25565:25565/udp

    volumes:
      - "/data/Servers/The Elder Scrolls III Morrowind/Co-op:/config"

    environment:
      TES3MP_SERVER_NAME: "My Morrowind Server"
      TES3MP_MAX_PLAYERS: "16"
      TES3MP_GAME_MODE: "Co-op"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

## How It Starts

1. `PostInitialization/20-InstallTES3MP.ps1` downloads `TES3MP_SERVER_URL` if `Server/tes3mp-server.x86_64` or `Server/server/scripts/serverCore.lua` is missing or the URL changed. It checks `TES3MP_SERVER_SHA256`, unpacks the folder holding `tes3mp-server.x86_64` into `Server/` (without `source.tar.gz` and `server/.git`) and remounts the overlay.
2. `PostInitialization/30-ConfigureTES3MP.ps1` writes the `TES3MP_*` settings into `tes3mp-server-default.cfg` and `server/scripts/config.lua`. It edits them through `Merged/`, so the edited copies land in `Overlay/`. Only the matching lines change.
3. `START_EXE` (`/usr/local/bin/tes3mp-server`) runs `./tes3mp-server.x86_64 <START_ARGS>` from `Merged/` with `LD_LIBRARY_PATH=./lib`. Output is line-buffered so it reaches `docker logs` straight away. The launcher skips the package's `tes3mp-prelaunch`, which would copy the config and CoreScripts into `~/.config/openmw`. It sets `XDG_CONFIG_HOME=Merged/.config`, so the server's log files (`.config/openmw/tes3mp-server-<date>.log`) persist in `Overlay/`.

A successful start ends with:

```
Loading settings file: /config/Merged/tes3mp-server-default.cfg
[...] [INFO]: TES3MP dedicated server 0.8.1 (Linux 64-bit)
Protocol version: 10
Oldest compatible commit hash: 68954091c5
...
[...] [INFO]: [Script]: Reading requiredDataFiles.json
[Script]: - 1: "Morrowind.esm": [7B6AF5B9, 34282D67, ]
[Script]: - 2: "Tribunal.esm": [F481F334, 211329EF, ]
[Script]: - 3: "Bloodmoon.esm": [43DD2132, 9EB62F26, ]
[...] [INFO]: [Script]: Called "OnServerPostInit"
```

## Configuration Options

### Ports

- **25565/udp**: Game and RakNet pings from the server browser (`TES3MP_PORT`).

The server doesn't answer LAN broadcasts. With `TES3MP_LAN=false` it registers with `master.tes3mp.com:25561`, and the in-game browser lists it from there.

### Environment Variables

See the [README](../README.md#environment-variables) for the full table.

### Joining

TES3MP clients connect to the address in `tes3mp-client-default.cfg` (next to `tes3mp.exe`):

```ini
[General]
destinationAddress = <server ip>
port = 25565
password =
```

Then start `tes3mp.exe` directly. The browser (`tes3mp-browser.exe`) can also add a server by address. A client's TES3MP version and content files (`content=` lines in its `openmw.cfg`) must match the server's (see [Required data files](#required-data-files)).

### tes3mp-server-default.cfg

The server reads `tes3mp-server-default.cfg` from its working directory. It reads `~/.config/openmw/tes3mp-server.cfg` over that, which in this image is `Merged/.config/openmw/tes3mp-server.cfg`. The hook only changes `port`, `maximumPlayers`, `hostname`, `logLevel`, `password` (always) and `[MasterServer] enabled`. Edit anything else (e.g. `localAddress`, the master server address) in `Overlay/tes3mp-server-default.cfg`.

### CoreScripts (server/scripts/config.lua)

The game rules live in the CoreScripts' `server/scripts/config.lua`. The hook replaces the `config.<name> = ...` line for each non-empty `TES3MP_*` CoreScripts variable. Clearing the variable later leaves the last written value in place; edit `Overlay/server/scripts/config.lua` to change it back. Other settings worth knowing (edit them in that file): `config.gameSettings`, `config.defaultTimeTable`, `config.respawnAtImperialShrine` / `respawnAtTribunalTemple`, `config.deathTime`, `config.shareFactionRanks`, `config.shareTopics`, `config.shareBounty`, `config.shareReputation`, `config.shareVideos`, `config.useInstancedSpawn`, `config.allowWildernessRest`, `config.allowWait`.

Custom scripts go in `Overlay/server/scripts/custom/` and are loaded from `server/scripts/customScripts.lua` (`require("custom/<name>")`).

### Required data files

`server/data/requiredDataFiles.json` lists the content files every client must have, in load order, each with the CRC32 checksums it accepts. The default allows the English and Russian `Morrowind.esm`, `Tribunal.esm` and `Bloodmoon.esm`. To run mods, add their `.esp`/`.esm` names (and checksums, or `[]` for any) in the clients' load order to `Overlay/server/data/requiredDataFiles.json`.

### World data

Everything the server saves is JSON under `server/data/` in `Overlay/`: `player/` (characters), `cell/`, `world/`, `recordstore/` (custom records), `map/`. Stop the server before editing or restoring it. Deleting `Overlay/server/data/` resets the world; the package's empty folders then show through from `Server/`.

### Admins

TES3MP has no rcon. Staff ranks are stored per character: stop the server, set `"staffRank": 2` (2 = admin, 3 = server owner; 1 = moderator) in the `settings` section of `Overlay/server/data/player/<name>.json`, and start it again. Staff get the `/` commands in `server/scripts/commandHandler.lua` (`/kick`, `/addmoderator`, `/addadmin`, `/sethour`, `/setday`, `/setdifficulty`, `/teleport`, ...; `/help` lists them). An owner can then promote others in game with `/addadmin <pid>`.

### Hooks

| Hook | When |
|------|------|
| `PreInstallTES3MP` / `PostInstallTES3MP` | Around the TES3MP download |

Put `.ps1` scripts in `config/Scripts/Hooks/<HookName>/`.

## Troubleshooting

- **`SHA256 mismatch`**: `TES3MP_SERVER_URL` points at a different package than the official 0.8.1 one. Clear `TES3MP_SERVER_SHA256` (or set the package's hash).
- **`Could not find Lua CJSON!`** at startup: harmless. CoreScripts fall back to the bundled pure-Lua dkjson. Debian's `lua-cjson` can't be used here because CoreScripts call functions that exist only in the OpenResty fork.
- **Clients get a version mismatch**: they need TES3MP 0.8.1 with commit `68954091c5`. 0.7.x clients can't join a 0.8.x server.
- **Clients are kicked for their data files**: their `content=` list doesn't match `requiredDataFiles.json` (a German/French Morrowind, a missing expansion, or extra plugins). See [Required data files](#required-data-files).
- **The server isn't in the in-game browser**: the browser only shows servers from the master server. Join by address, or set `TES3MP_LAN=false` to register (needs the port reachable from the internet).
- **"kicked because this server allows a maximum of 3 clients from the same IP address"**: `config.maxClientsPerIP` defaults to 3; raise `TES3MP_MAX_CLIENTS_PER_IP` when more players share one address (NAT).
- **A setting reverted to an old value after clearing its variable**: CoreScripts settings stay as last written; see [CoreScripts](#corescripts-serverscriptsconfiglua).
