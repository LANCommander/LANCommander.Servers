# Marvel Heroes Server (Docker)

This image provides a Dockerized server for **Marvel Heroes** (Marvel Heroes Omega, game version 1.52.0.1700), using [MHServerEmu](https://github.com/Crypto137/MHServerEmu), the open-source server emulator. The image carries a pinned MHServerEmu release (1.0.3) and the .NET 10 runtime it needs. In place of the Apache server MHServerEmu ships for Windows, nginx serves `SiteConfig.xml` and the store/news pages and passes logins on to MHServerEmu over HTTPS. MHServerEmu reads the game's data from two files of the game client, which you supply.
The image builds on [`lancommander/base`](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/Base). It supports file overlaying using OverlayFS.

---

## Features

- MHServerEmu 1.0.3 (sha256-checked at build time) on .NET 10, running natively on Linux
- The whole server in one container: game frontend (4306/tcp), web files on port 80, HTTPS login on 443
- Clients are pointed at the container's own address on every start (`SiteConfig.xml`, frontend public address, store and news URLs); no hosts-file edits
- Accounts and characters in SQLite (`Data/Account.db`, with rolling backups) in `Overlay/`
- The most-used settings as `MH_*` variables, and any `Config.ini` setting as `MHSE__<Section>__<Key>`
- `docker stop` saves every player and shuts the server down cleanly (`!server shutdown`)
- Server console commands from outside the container: `mhserveremu-command '<command>'`
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  marvelheroes:
    image: lancommander/marvelheroes:latest
    container_name: marvelheroes

    ports:
      - "4306:4306/tcp"
      - "80:80/tcp"
      - "443:443/tcp"

    volumes:
      - ./config:/config

    environment:
      MH_PUBLIC_ADDRESS: "192.168.1.50"   # the address clients reach this server at
      MH_SERVER_NAME: "Marvel Heroes LAN"
      MH_AUTO_UNLOCK_AVATARS: "true"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    stop_grace_period: 30s
    restart: unless-stopped
```

The same file is in this directory as [`compose.yml`](compose.yml).

Put `Calligraphy.sip` and `mu_cdata.sip` from the client in `config/ClientData/` before the first start (see [Game Files](#game-files)).

## Connecting

Start the client (`UnrealEngine3/Binaries/Win64/MarvelHeroesOmega.exe`) with:

```text
-robocopy -nosteam -siteconfigurl=<server address>/SiteConfig.xml
```

The client loads `SiteConfig.xml` over HTTP, logs in over HTTPS at `AuthServerAddress` (port 443) and then connects to the frontend on 4306/tcp. Accounts are created on the server's dashboard at `http://<server address>/Dashboard/`. Add `-emailaddress=<email> -password=<password>` to log in automatically.

---

## Game Files

MHServerEmu needs two files from the `Data/Game/` folder of a Marvel Heroes Omega **1.52.0.1700** client (the last Steam version): `Calligraphy.sip` (47 MB) and `mu_cdata.sip` (28 MB). They're not in the image. Put them in `config/ClientData/` (`MH_CLIENT_DATA_DIR`), either the two files on their own or a whole client install (they're found up to four folders deep). On every start, `PostInitialization/20-InstallMHServerEmu.ps1` copies them into `Data/Game/` (so `Overlay/Data/Game/`) when they're missing or when the ones in `ClientData/` differ in size or date. You can also put them straight into `config/Overlay/Data/Game/`. Without them the server doesn't start.

The same hook copies MHServerEmu from the image into `config/Server/` on first start and whenever the image brings a different version. The installed version is kept in `Server/.mhserveremu-version`. When it replaces another version, it empties `Server/` first and renames the old version's `Config.ini`, `htdocs/SiteConfig.xml` and `htdocs/news/index.html` in `Overlay/` to `<name>.bak-<old version>`, so the new version's files show through. Accounts and everything else in `Overlay/` are kept. A `Server/` with `MHServerEmu.dll` but no version marker (a build you copied in yourself) is left alone.

Clients must run 1.52.0.1700; MHServerEmu turns other versions away (`MHSE__PlayerManager__AllowClientVersionMismatch=true` lets them in).

## Directory Layout (Host)

```text
.
└── config/
    ├── ClientData/        # Calligraphy.sip and mu_cdata.sip (or a client install)
    ├── Server/            # MHServerEmu: MHServerEmu.dll, Config.ini, Data/, htdocs/ (web files)
    ├── Overlay/           # Your files, layered on top of Server/: Data/Account.db, Data/Game/*.sip,
    │                      #   ConfigOverride.ini, edited Config.ini, htdocs/SiteConfig.xml, Logs/
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

Back up `Overlay/Data/Account.db`; it holds every account and character. MHServerEmu keeps up to five backups of it next to it.

---

## Environment Variables

These are in addition to the [base image's variables](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/Base#environment-variables).
`PostInitialization/30-ConfigureMHServerEmu.ps1` writes them into `ConfigOverride.ini`, which MHServerEmu reads over `Config.ini`, on every start. Settings left empty leave `Config.ini`'s value in place.

| Variable | Description | Default |
|----------|-------------|---------|
| `MH_PUBLIC_ADDRESS` | Address clients reach the server at: `[Frontend] PublicAddress`, `SiteConfig.xml`'s `AuthServerAddress`, the store and news URLs. Empty: the container's IPv4 address | |
| `MH_CLIENT_DATA_DIR` | Where `Calligraphy.sip` and `mu_cdata.sip` are copied from | `/config/ClientData` |
| `MH_FRONTEND_PORT` | `[Frontend] Port`, the game connection (tcp) | `4306` |
| `MH_WEB_PORT` | `[WebFrontend] Port`; MHServerEmu's web front end listens on 127.0.0.1 only, nginx passes requests on to it | `8080` |
| `MH_SERVER_NAME` | `[GroupingManager] ServerName`, the sender of server messages in chat | `MHServerEmu` |
| `MH_MOTD` | `[GroupingManager] MotdText`, the message of the day | (Config.ini's) |
| `MH_SERVER_CAPACITY` | `[PlayerManager] ServerCapacity`; more players wait in a queue. 0: unlimited | (`0`) |
| `MH_USE_WHITELIST` | `[PlayerManager] UseWhitelist`: only accounts added with `!account whitelist` can log in | (`false`) |
| `MH_AUTOSAVE_MINUTES` | `[CustomGameOptions] AutosaveIntervalMinutes` | `5` |
| `MH_AUTO_UNLOCK_AVATARS` | `[CustomGameOptions] AutoUnlockAvatars`: every hero unlocked after the tutorial | (`false`) |
| `MH_AUTO_UNLOCK_TEAMUPS` | `[CustomGameOptions] AutoUnlockTeamUps`: every team-up unlocked after the tutorial | (`false`) |
| `MH_STARTING_GAZILLIONITE` | `[MTXStore] GazillioniteBalanceForNewAccounts`, store currency for new accounts | (`10000`) |
| `MH_LOG_LEVEL` | `[Logging] ConsoleMinLevel`: 0 trace, 1 debug, 2 info, 3 warning, 4 error, 5 fatal | `2` |
| `MHSE__<Section>__<Key>` | Any `Config.ini` setting, e.g. `MHSE__CustomGameOptions__DisableInstancedLoot=true`. Written last, so it wins over the `MH_*` variables | |
| `MH_TLS_CERT` / `MH_TLS_KEY` | Certificate and key nginx uses on 443. The client doesn't check it | built-in self-signed |
| `MHSE_VERSION` | MHServerEmu version in the image (informational; set at build time) | `1.0.3` |
| `START_EXE` | Launcher | `/usr/local/bin/mhserveremu-server` |
| `START_ARGS` | Extra arguments for `MHServerEmu.dll` | |

Values in parentheses are MHServerEmu's own defaults, which apply while the variable is empty. Every other setting (game options, loot, PvP, leaderboards, live tuning) is in `Config.ini`; edit it in `Overlay/` or use `MHSE__` variables. Don't edit `ConfigOverride.ini`, it's rewritten on every start.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

```bash
docker build -t lancommander/marvelheroes:local Servers/MarvelHeroes
docker build --build-arg BASE_IMAGE=lancommander/base:local -t lancommander/marvelheroes:local Servers/MarvelHeroes
```

`MHSE_VERSION` and `MHSE_SHA256` build arguments pick another MHServerEmu release.

---

## License

MHServerEmu is AGPLv3 ([source](https://github.com/Crypto137/MHServerEmu)); its release is downloaded at build time and included unmodified in the image. Marvel Heroes is a trademark of Marvel / Gazillion Entertainment; its game files are not included and must be supplied from your own copy of the game.
This directory contains only Docker build logic and helper scripts licensed under MIT.
