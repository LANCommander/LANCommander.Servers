# LANCommander Game Server Base (Docker)

The base layer every LANCommander game server image is built on. It provides the PowerShell 7
entrypoint, an OverlayFS view that keeps the vanilla server files apart from your changes,
lifecycle hooks, and an optional nginx file server for HTTP downloads.

You don't normally run this image directly. Game images build `FROM lancommander/base:latest`
(directly, or through [`lancommander/steamcmd`](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/SteamCMD)
or [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE))
and set `START_EXE` plus hooks that install the game.

---

## Features

- Debian 12 with PowerShell 7 (`mcr.microsoft.com/powershell:debian-12`)
- OverlayFS: `/config/Server` (vanilla files) + `/config/Overlay` (your changes) → `/config/Merged` (what runs)
- Hook points that run PowerShell scripts in name order
- Runs the server as an unprivileged user through `gosu`
- Optional nginx file server on port 80 (for game HTTP/fast downloads)
- Bundled PowerShell modules: `Logging`, `Hooks`, `OverlayFS`, `AptTools`

---

## Docker Compose Example

```yaml
services:
  my-server:
    image: lancommander/base:latest
    container_name: my-server

    volumes:
      - ./config:/config

    environment:
      START_EXE: "./my-server-binary"
      START_ARGS: "-port 27015"

    # The entrypoint must be root to mount OverlayFS; the server itself runs as UID/GID
    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The same file is in this directory as [`compose.yml`](compose.yml).

---

## Directory Layout (Host)

```text
./config/
├── Server/      # Vanilla server files (installed by a game image's hooks, or by you)
├── Overlay/     # Your configs and changes; mirrors Server/
├── Merged/      # OverlayFS view of Server/ + Overlay/, the server's working directory
└── Scripts/
    ├── Hooks/   # Your own hook scripts (base hooks are copied in on start)
    └── Modules/ # PowerShell modules (base modules are copied in on start)
```

Put configuration changes in `Overlay/`. Don't edit `Merged/` directly: it only exists while the
container runs.

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `START_EXE` | *(empty)* | Executable to run. A path is resolved relative to `/config/Merged`; a bare name is looked up in the working directory, then on `PATH` (which includes `/config/Merged`). |
| `START_ARGS` | *(empty)* | Arguments for `START_EXE`. Split on spaces; `"double"` or `'single'` quotes keep spaces together. |
| `UID` / `GID` | `1000` / `1000` | User and group the server runs as. `/config` is chowned to them on start. |
| `USER` / `GROUP` | `lancommander` | Names for the run user and group. |
| `HTTP_FILESERVER_ENABLED` | *(empty)* | `true` or `1` starts nginx on port 80. |
| `HTTP_FILESERVER_WEB_ROOT` | *(unset)* | Directory nginx serves. Set it when enabling the file server (usually a path under `/config/Merged`). |
| `HTTP_FILESERVER_FILE_PATTERN` | *(empty)* | Only serve matching files, e.g. `*.bsp`. Directories are always listed. |
| `CONFIG_DIR` | `/config` | Root of the mounted volume. |
| `SERVER_DIR` | `/config/Server` | OverlayFS lower directory (vanilla files). |
| `OVERLAY_DIR` | `/config/Overlay` | OverlayFS upper directory (your changes). |
| `SERVER_ROOT` | `/config/Merged` | OverlayFS mount point and the server's working directory. |
| `WORK_DIR` | `/config/.overlay-work` | OverlayFS work directory, recreated on every start. |
| `USER_HOOKS` | `/config/Scripts/Hooks` | Hook scripts run from here. |
| `USER_MODULES` | `/config/Scripts/Modules` | PowerShell modules loaded from here. |
| `BASE_HOOKS` | `/usr/local/share/powershell/Hooks` | Hooks shipped in the image (derived images `COPY` theirs here). |
| `BASE_MODULES` | `/usr/local/share/powershell/Modules` | Modules shipped in the image. |

---

## Startup and Hooks

1. Base modules and hooks are copied into `/config/Scripts/`.
2. **`PreInitialization`** hooks run.
3. `/config` is chowned to `UID:GID` and OverlayFS is mounted at `/config/Merged`.
4. **`PostInitialization`** hooks run (game images install the game here).
5. nginx starts if `HTTP_FILESERVER_ENABLED` is set.
6. **`ServerStarted`** hooks run, then `START_EXE START_ARGS` runs as `UID:GID` from `/config/Merged`.
7. When the server exits, **`ServerStopped`** hooks run and the container exits with the server's exit code.

Hooks are `.ps1` files in `Scripts/Hooks/<HookPoint>/`, run in name order (use `NN-` prefixes).
A hook can fire its own hook points with `Invoke-Hook "<Name>"`.

---

## Requirements

Mounting OverlayFS needs the container to start as root with `SYS_ADMIN` (or `privileged: true`).
On hosts with AppArmor, also set `security_opt: apparmor:unconfined`.

---

## License

MIT. See [LICENSE](../../LICENSE).
