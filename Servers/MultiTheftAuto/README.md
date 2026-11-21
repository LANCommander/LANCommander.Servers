# Multi Theft Auto Server (Docker)

This image provides a Dockerized **Multi Theft Auto: San Andreas** (MTA:SA) dedicated server. On first start it downloads the official Linux x64 server (1.6.0 r24159), its default configuration and the official resource pack (r1602: race, deathmatch, CTF, assault, stealth and more game modes with their maps, the admin panel, the map editor), so you don't need to supply any files. Players need GTA: San Andreas with the MTA:SA 1.6 client.
The image builds on [`lancommander/base`](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/Base). It supports file overlaying using OverlayFS.

---

## Features

- The official MTA:SA 1.6 Linux server, sha256-checked, with the official resources
- **Party rotation** for LAN parties: a few race maps in a row, then everyone votes on the next game mode and map; every other mode votes again when its match ends or after a time limit
- Server name, ports, player slots, password, fps limit and voice are environment variables, written into `mtaserver.conf` on every start; any other `mtaserver.conf` element and any resource setting can be set the same way
- An in-game admin account from `MTA_ADMIN_USER` / `MTA_ADMIN_PASSWORD`
- LAN-only by default: answers the in-game LAN browser, stays off the internet server list and doesn't raise the minimum client version on its own
- Console commands with `docker exec <container> mta-command '<command>'`, and a clean `shutdown` on `docker stop`
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  multitheftauto:
    image: lancommander/multitheftauto:latest
    container_name: multitheftauto

    ports:
      - "22003:22003/udp"
      - "22005:22005/tcp"
      - "22126:22126/udp"
      - "34219:34219/udp"

    volumes:
      - ./config:/config

    environment:
      MTA_SERVER_NAME: "My MTA Server"
      MTA_MAX_PLAYERS: "32"
      MTA_ADMIN_PASSWORD: "changeme"
      MTA_PARTY_ROTATION: "true"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    stdin_open: true                   # console input through the container's stdin
    stop_grace_period: 15s             # time for a clean shutdown on docker stop
    restart: unless-stopped
```

The same file is in this directory as [`compose.yml`](compose.yml).

## Party Rotation

With `MTA_PARTY_ROTATION=true` (the default) the image replaces the stock `mapcycler` resource with its own (same name, so the stock game modes report their match ends to it):

1. The server starts with `MTA_PARTY_START` (race) on a random map.
2. Race plays `MTA_PARTY_RACE_MAPS` maps, each picked by race's own next-map vote. After that, race's vote is replaced by a vote between `MTA_PARTY_VOTE_OPTIONS` choices of game mode + map from `MTA_PARTY_GAMEMODES` (race is always one of them), plus "Play again".
3. Every other mode votes again when its match ends (a deathmatch round, a CTF win, both assault halves, a stealth match, a briefcase race), or after `MTA_PARTY_TIME_LIMIT` minutes for modes that never end on their own (`fallout`, `hay`, `tdma`, `ctv`).
4. If nobody votes, a random choice wins. On an empty server the vote waits for the first player.

Admins (and the console) can start the vote at any time with `skipmap`. Set `MTA_PARTY_ROTATION=false` for the stock map cycler (`mapcycler` and `play` freeroam, as in the default `mtaserver.conf`).

Game modes in the resource pack: `race` (70 maps, including dogfights, derbies and boat/plane races), `deathmatch`, `tdma` (team deathmatch arena), `tdm`, `ctf`, `assault`, `stealth`, `briefcaserace`, `ctv` (capture the vehicle), `fallout`, `hay` and `play` (freeroam).

## Game Files

On first start `PostInitialization/20-InstallMultiTheftAuto.ps1` downloads `MTA_SERVER_URL` (13 MB), `MTA_BASECONFIG_URL` and `MTA_RESOURCES_URL` (6 MB), checks their SHA-256 and installs them into `config/Server/` (the configs and resources go to `mods/deathmatch/`). It reinstalls, replacing `Server/` as a whole, only when one of the URLs changes.

Clients connect with any MTA:SA 1.6 client. The server's `minclientversion` decides the oldest one it accepts (`minclientversion_auto_update` is off on a LAN).

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # MTA: mta-server64, x64/, mods/deathmatch/ (default configs, resources/)
    ├── Overlay/           # Your files, layered on top of Server/ (mtaserver.conf, acl.xml, settings.xml, your resources, logs, databases)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [base image's variables](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/Base#environment-variables).
The settings are written into `mods/deathmatch/mtaserver.conf` on every start. Settings left empty leave the file's value alone, so you can edit the file (in `Overlay/`) instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `MTA_SERVER_URL` | Linux x64 server `.tar.gz` | the 1.6.0 r24159 nightly build |
| `MTA_SERVER_SHA256` | Expected SHA-256; empty skips the check | hash of that file |
| `MTA_BASECONFIG_URL` | `.tar.gz` with the default `mtaserver.conf`, `acl.xml`, `vehiclecolors.conf` | the official `baseconfig.tar.gz` |
| `MTA_BASECONFIG_SHA256` | Expected SHA-256; empty skips the check | hash of that file |
| `MTA_RESOURCES_URL` | Resource pack `.zip`; empty installs none | `mtasa-resources-r1602.zip` |
| `MTA_RESOURCES_SHA256` | Expected SHA-256; empty skips the check | hash of that file |
| `MTA_SERVER_NAME` | `servername` | `Multi Theft Auto Server` |
| `MTA_PORT` | `serverport` (UDP); the browser query port is this + 123 | `22003` |
| `MTA_HTTP_PORT` | `httpport` (TCP): resource downloads and the web admin | `22005` |
| `MTA_MAX_PLAYERS` | `maxplayers` | `32` |
| `MTA_PASSWORD` | `password`, required to join (always written; empty = none) | |
| `MTA_LAN` | `true`: LAN browser only (`ase 0`), no automatic `minclientversion` raise, no crash dump upload, no admin serial authorization. `false`: also listed on the internet server list (`ase 1`) | `true` |
| `MTA_FPS_LIMIT` | `fpslimit`, the players' frame rate cap | `60` |
| `MTA_VOICE` | `voice` chat | `false` |
| `MTA_CONFIG` | Any other `mtaserver.conf` elements, `name=value` separated by `;` (e.g. `bandwidth_reduction=none;bullet_sync=1`) | |
| `MTA_ADMIN_USER` | Admin account name | `admin` |
| `MTA_ADMIN_PASSWORD` | Admin account password (created or updated on start, added to the `Admin` ACL group); empty = no account | |
| `MTA_START_RESOURCES` | More resources to start with the server, separated by commas; `-name` stops one starting | |
| `MTA_PARTY_ROTATION` | Use the party rotation (see above) | `true` |
| `MTA_PARTY_GAMEMODES` | Game modes the vote picks from, comma-separated | `race,deathmatch,tdma,ctf,assault,stealth,briefcaserace,ctv,fallout,hay` |
| `MTA_PARTY_START` | First game mode; empty = random | `race` |
| `MTA_PARTY_RACE_MAPS` | Race maps in a row before the mode vote | `3` |
| `MTA_PARTY_TIME_LIMIT` | Minutes before a non-race map votes anyway (0 = off) | `15` |
| `MTA_PARTY_VOTE_OPTIONS` | Choices per vote (2-8) | `6` |
| `MTA_RESOURCE_SETTINGS` | Resource settings, `resource.setting=value` separated by `;` (e.g. `race.ghostmode=true;race.duration=480`). Prefix `#` or `@` for private or protected settings | |
| `START_EXE` | Launcher | `/usr/local/bin/mta-server` |
| `START_ARGS` | Extra `mta-server64` arguments | |

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

```bash
docker build -t lancommander/multitheftauto:local Servers/MultiTheftAuto
docker build --build-arg BASE_IMAGE=lancommander/base:local -t lancommander/multitheftauto:local Servers/MultiTheftAuto
```

---

## License

Multi Theft Auto is free software (GPLv3) by the MTA team; the server and resources are downloaded at runtime and not included in the image. Grand Theft Auto: San Andreas is required on the clients and is not part of this image.
This directory contains only Docker build logic, helper scripts and Lua resources licensed under MIT.
