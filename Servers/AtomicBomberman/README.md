# Atomic Bomberman Server (Docker)

This image provides a Dockerized **Atomic Bomberman** dedicated server. Atomic Bomberman is Interplay's 1997 PC Bomberman game for up to 10 players. The image runs the server of [FPC Atomic](https://github.com/PascalCorpsman/fpc_atomic), the open-source Free Pascal remake by Uwe Schächterle (PascalCorpsman), which is what LANCommander installs as Atomic Bomberman. It uses the official native Linux build of **FPC Atomic 0.14002**.
The image builds on [`lancommander/base`](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/Base). It supports file overlaying using OverlayFS.

---

## Features

- FPC Atomic 0.14002 server (`atomic_server`), native Linux, baked into the image and checked against the release's SHA256 digests
- No game files needed: the server only uses the map definitions (`data/maps/*/info.txt`), which come with the image. The players' clients need the original game's data
- Original and smart computer player AI (`ATOMIC_AI`)
- Runs until stopped (`-t 0`), instead of closing when the last player leaves
- Shows up in the client's LAN server list (UDP 8005 discovery)
- Console output goes to `docker logs` as it happens; statistics and logs are kept in `config/Overlay/.config/fpc_atomic/`
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  atomicbomberman:
    image: lancommander/atomicbomberman:latest
    container_name: atomicbomberman

    ports:
      - "5521:5521/tcp"
      - "8005:8005/udp"

    volumes:
      - ./config:/config

    environment:
      ATOMIC_AI: "ai_smart"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The same file is in this directory as [`compose.yml`](compose.yml).

---

## Server Files

The FPC Atomic release files are in the image (`/opt/fpc-atomic`). On first start they are copied into `config/Server/`, and again when the image's `ATOMIC_VERSION` changes. The installed version is in `config/Server/.atomic-version`.

**Clients must run the same FPC Atomic release (0.14002).** Every FPC Atomic release with network changes bumps its protocol version, and a client of another release can't join. In particular, the 0.11009 build in older LANCommander archives doesn't work with this server. Update the client with the FPC Atomic launcher's **Updates...** button, or replace the executables with the ones from the [0.14002 release](https://github.com/PascalCorpsman/fpc_atomic/releases/tag/0.14002).

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # FPC Atomic server (atomic_server, libai.so, libai_smart.so, data/maps/)
    ├── Overlay/           # Your files, layered on top of Server/
    │   └── .config/
    │       └── fpc_atomic/    # stats.txt, Playerstats.csv, log/, ai_smart.ini (written by the server)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [base image's variables](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/Base#environment-variables).

| Variable | Description | Default |
|----------|-------------|---------|
| `ATOMIC_VERSION` | FPC Atomic release in the image. Set by the image; the server is reinstalled into `Server/` when it changes | `0.14002` |
| `ATOMIC_DIST` | Where the image keeps the release files | `/opt/fpc-atomic` |
| `ATOMIC_PORT` | Game port, TCP (`-p`) | `5521` |
| `ATOMIC_TIMEOUT` | Close the server after this many ms with nobody connected (`-t`). `0` = never | `0` |
| `ATOMIC_AI` | Computer player AI (`-ai`): empty = the original AI (`libai.so`), `ai_smart` = the smart AI (`libai_smart.so`) | |
| `ATOMIC_LOG_LEVEL` | Log level (`-l`); the server's default is 2 | |
| `START_EXE` | Launcher | `/usr/local/bin/atomic-server` |
| `START_ARGS` | Appended to the `atomic_server` command line, e.g. `-ats 7` (the bombers' animation speed, default 5) | |

The game rules (game mode, mods, number of wins, maps) aren't server settings: the first player to join (the master) picks them in the client, and the client sends them to the server.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/base:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/base:local -t lancommander/atomicbomberman:local Servers/AtomicBomberman
```

---

## License

FPC Atomic is distributed under its own license (Postcardware or a modified LGPL, see its [license.md](https://github.com/PascalCorpsman/fpc_atomic/blob/main/license.md)). Atomic Bomberman's game data belongs to its rights holders and isn't part of this image.
This directory contains only Docker build logic and helper scripts licensed under MIT.
