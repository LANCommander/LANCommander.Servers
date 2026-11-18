# Minecraft Server (Docker)

This image provides a Dockerized **Minecraft: Java Edition** dedicated server. On start it downloads the server jar for `MINECRAFT_VERSION`: [Paper](https://papermc.io/) (the default), Mojang's vanilla server, or any jar you point it at, plus the plugins you list. It runs on a bundled Eclipse Temurin 25 JRE and defaults to **offline mode**, so LAN clients without Microsoft accounts (such as the LANCommander Minecraft package, which uses the player's LANCommander name) can join.
The image builds on [`lancommander/base`](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/Base). It supports file overlaying using OverlayFS.

---

## Features

- Paper (any build, or the newest stable one), vanilla or a custom server jar, sha256/sha1-checked, reinstalled when the version changes
- Plugins installed from a list of URLs (`MINECRAFT_PLUGINS`)
- Common `server.properties` settings as environment variables; the rest of the file stays editable
- Offline (LAN) mode by default, with operators set by name (`MINECRAFT_OPS`)
- Listed under "LAN Worlds" in clients' multiplayer screen, like an "Open to LAN" world
- Console commands from `docker exec` (`minecraft-command`) or the container's stdin, and a clean save on `docker stop`
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  minecraft:
    image: lancommander/minecraft:latest
    container_name: minecraft

    ports:
      - "25565:25565/tcp"

    volumes:
      - ./config:/config

    environment:
      MINECRAFT_EULA: "true"           # you accept https://aka.ms/MinecraftEULA
      MINECRAFT_VERSION: "26.2"
      MINECRAFT_MOTD: "My Minecraft Server"
      MINECRAFT_OPS: "SomePlayer"
      MINECRAFT_MEMORY: "4G"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    stdin_open: true                   # console input through the container's stdin
    stop_grace_period: 30s             # time to save the worlds on docker stop
    restart: unless-stopped
```

The same file is in this directory as [`compose.yml`](compose.yml).

The "LAN Worlds" announcement is multicast, so it only reaches clients when the container is on the LAN itself (macvlan/ipvlan, or `network_mode: host`). With port mapping, clients add the server by IP.

---

## Game Files

`PostInitialization/20-InstallMinecraft.ps1` downloads the server jar to `config/Server/server.jar`:

- `paper`: build `PAPER_BUILD` of Paper `MINECRAFT_VERSION` from the PaperMC API (`latest` = the newest stable build), checked against its sha256. On first start Paper also downloads Mojang's jar and its libraries into `cache/`, `libraries/` and `versions/` (in `Overlay/`).
- `vanilla`: Mojang's server jar for `MINECRAFT_VERSION`, checked against its sha1.
- `custom`: `MINECRAFT_SERVER_URL`, checked against `MINECRAFT_SERVER_SHA256` when set.

It reinstalls when the resolved URL changes, so changing `MINECRAFT_VERSION` or `PAPER_BUILD` upgrades the server. If the download site can't be reached and a jar is installed, the server starts with that jar.

`MINECRAFT_PLUGINS` jars go to `config/Server/plugins/`. Removing a URL from the list removes its jar. Plugin configs and data are written to `plugins/<name>/` in `Overlay/`. Plugins you copy into `Overlay/plugins/` yourself are left alone.

Clients must run the same Minecraft version as the server (Paper and vanilla don't accept other versions).

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # server.jar, plugins/*.jar (installed by the image)
    ├── Overlay/           # Everything the server writes: worlds, server.properties, ops.json, plugin data, logs/
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [base image's variables](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/Base#environment-variables).
The `server.properties` settings are written on every start. Settings left empty leave the key as it is, so you can edit it in `Overlay/server.properties` instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `MINECRAFT_EULA` | `true` accepts the [Minecraft EULA](https://aka.ms/MinecraftEULA); the server doesn't start without it | `false` |
| `MINECRAFT_VERSION` | Minecraft version (`26.2`, `1.21.11`, ...) | `26.2` |
| `MINECRAFT_SERVER_TYPE` | `paper`, `vanilla` or `custom` | `paper` |
| `PAPER_BUILD` | Paper build number, or `latest` for the newest stable build | `135` |
| `MINECRAFT_SERVER_URL` | Server jar for `custom` | |
| `MINECRAFT_SERVER_SHA256` | Expected SHA-256 of `MINECRAFT_SERVER_URL`; empty skips the check | |
| `MINECRAFT_PLUGINS` | Plugin jar URLs, separated by whitespace | |
| `MINECRAFT_MEMORY` | Java heap (`-Xms`/`-Xmx`) | `2G` |
| `MINECRAFT_JVM_ARGS` | Extra Java options, separated by whitespace | |
| `MINECRAFT_PORT` | `server-port` (and `query.port`) | `25565` |
| `MINECRAFT_ONLINE_MODE` | `online-mode`: `false` lets players in without a Microsoft account, under any name | `false` |
| `MINECRAFT_ENFORCE_SECURE_PROFILE` | `enforce-secure-profile`: must be `false` for offline clients | `false` |
| `MINECRAFT_MOTD` | `motd`, also the name in the LAN list | `A LANCommander Minecraft Server` |
| `MINECRAFT_MAX_PLAYERS` | `max-players` | `20` |
| `MINECRAFT_LEVEL_NAME` | `level-name`, the world folder | |
| `MINECRAFT_LEVEL_TYPE` | `level-type` (`minecraft:normal`, `minecraft:flat`, ...) | |
| `MINECRAFT_GAMEMODE` | `gamemode` | |
| `MINECRAFT_DIFFICULTY` | `difficulty` | |
| `MINECRAFT_PVP` | `pvp` | |
| `MINECRAFT_SPAWN_PROTECTION` | `spawn-protection` radius | |
| `MINECRAFT_VIEW_DISTANCE` | `view-distance` | |
| `MINECRAFT_ALLOW_NETHER` | `allow-nether` | |
| `MINECRAFT_PROPERTIES` | Any other `key=value` lines, separated by newlines or `;` | |
| `MINECRAFT_OPS` | Player names made operators (offline mode only), separated by spaces or commas | |
| `MINECRAFT_RCON_PASSWORD` | Enables RCON with this password; empty disables it | |
| `MINECRAFT_RCON_PORT` | `rcon.port` | `25575` |
| `MINECRAFT_LAN_ANNOUNCE` | List the server under "LAN Worlds" (multicast 224.0.2.60:4445) | `true` |
| `START_EXE` | Launcher | `/usr/local/bin/minecraft-server` |
| `START_ARGS` | Extra server arguments, after `--nogui` | |

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

```bash
docker build -t lancommander/minecraft:local Servers/Minecraft
docker build --build-arg BASE_IMAGE=lancommander/base:local -t lancommander/minecraft:local Servers/Minecraft
```

---

## License

Minecraft is © Mojang Studios / Microsoft; its server is downloaded at runtime under the [Minecraft EULA](https://aka.ms/MinecraftEULA) and isn't included in the image. Paper is GPLv3/MIT. Eclipse Temurin is GPLv2 with the Classpath Exception.
This directory contains only Docker build logic and helper scripts licensed under MIT.
