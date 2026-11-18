# Giants: Citizen Kabuto Server (Docker)

This image provides a Dockerized **Giants: Citizen Kabuto** (2000) dedicated server. Giants has no Linux server, so the image runs the 1.5 community patch's `GiantsDedicated.exe -dedicated <file>.gdf` under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs `GiantsDedicated.exe` (Giants 1.5) headless under Wine and Xvfb, with a frame limit so the server's render loop doesn't use a whole core
- Native Microsoft DirectPlay is installed into the Wine prefix automatically. Wine's builtin DirectPlay 8 can't host games.
- The server rotation (`.gdf`, the binary file the game's `dedicated.exe` setup tool writes) is generated from environment variables. Its worlds are checked against the installed ones.
- The server log (`Giants.log`) is streamed to `docker logs`
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  giants:
    image: lancommander/giantscitizenkabuto:latest
    container_name: giants

    ports:
      - "19711:19711/udp"

    volumes:
      - ./config:/config

    environment:
      GIANTS_SERVER_NAME: "My Giants Server"
      GIANTS_ROTATION: "m_3way_l1, DM, MvR; m_mecc_desertsnakes, DM, MvM; m_3way_sunsetbay, DMCap, MvR, time_limit=30"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The same file is in this directory as [`compose.yml`](compose.yml).

DirectPlay is LAN-oriented and also opens dynamic UDP ports. A network where the container gets its own LAN IP (macvlan/ipvlan, or `network_mode: host`) is more reliable than port mapping.

---

## Game Files

Giants is retail software with no public download. You must provide an install with the **1.5 community patch** (the folder with `GiantsDedicated.exe`, `Bin/` and the `gg_*.dll` renderers):

- copy it to `config/Server/`, **or**
- set `GIANTS_ARCHIVE_URL` to a zip of that folder. It is downloaded and extracted on first start, if `Server/GiantsDedicated.exe` doesn't exist yet.

Earlier patches have no `GiantsDedicated.exe` (1.4 hosted with `Giants.exe -dedicated`), and clients must run 1.5 too.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Giants 1.5 install (GiantsDedicated.exe, Bin/, Stream/)
    ├── Overlay/           # Your files, layered on top of Server/ (Bin/*.gdf lands here)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix with native DirectPlay (auto-created); Giants.log is in
    │                      #   drive_c/users/lancommander/AppData/Local/Giants/
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers/tree/main/Servers/WINE#environment).

### Server

| Variable | Description | Default |
|----------|-------------|---------|
| `GIANTS_SERVER_NAME` | Game name shown in the server list (30 characters max) | `Giants Server` |
| `GIANTS_MOTD` | Message of the day | |
| `GIANTS_PORT` | Game port (`-port`) | `19711` |
| `GIANTS_MAX_PLAYERS` | Max players, 2-20. The server counts as one of them. | `20` |
| `GIANTS_NO_VOTING` | Turn off player votes | `false` |
| `GIANTS_MASTER_SERVER` | Register with the community master server (the in-game Internet browser). `false` passes `-nomaster`. | `false` |
| `GIANTS_FRAME_LIMIT` | `-framelimit`; empty for none. Idle CPU is about 14% of a core at 20, 34% at 30, 43% at 60, and over 100% with no limit. | `30` |
| `GIANTS_ROTATION` | Games to cycle through, see below | 4 games, see below |
| `GIANTS_GDF_NAME` | Rotation file name in `Bin/`, without `.gdf` | `lancommander` |
| `GIANTS_EXTRA_ARGS` | Raw arguments appended to the command line (for example `-pmarkers 0 -nophff -highbandwidth`) | |
| `GIANTS_ARCHIVE_URL` | Zip of the game folder, used if `Server/GiantsDedicated.exe` is missing | |

### Per-game defaults

These apply to every game in the rotation unless the entry overrides them (see below).

| Variable | Setup tool field | Default |
|----------|------------------|---------|
| `GIANTS_TIME_LIMIT` | Time Limit (minutes) | `20` |
| `GIANTS_POINTS_PER_KILL` | Points Per Kill | `1` |
| `GIANTS_POINTS_PER_CAPTURE` | Points Per Capture | `5` |
| `GIANTS_PLAYER_SCORE_LIMIT` | Player Score Limit (0 = none) | `0` |
| `GIANTS_TEAM_SCORE_LIMIT` | Team Score Limit (0 = none) | `0` |
| `GIANTS_DETENTE` | Detente (minutes before bases can be damaged and flags captured) | `0` |
| `GIANTS_FIRST_BASE_DESTROYED` | First Base Destroyed ends the game (base build/defend games) | `false` |
| `GIANTS_DAMAGE_TEAMMATES` | Damage Teammates | `false` |
| `GIANTS_NO_VIMPS` | No Vimps | `false` |
| `GIANTS_MAX_SMARTIES` | Max Smarties: `15`, `13`, `10`, `7`, `4` or `0` | `15` |
| `GIANTS_VIMP_MEAT_ENERGY` | Vimp Meat Energy: `easy`, `medium` or `hard` | `easy` |
| `GIANTS_MECC_WEAPONS_UNAVAILABLE` | Bit mask of Mecc weapons/items to disable (values in `readme_dedicated.txt`) | `0x400` (pop-up bomb) |
| `GIANTS_REAPER_WEAPONS_UNAVAILABLE` | Bit mask of Reaper weapons/spells/items to disable | `0x400` (tornado) |

The two weapon masks default to what the setup tool calls "Default Weapon Availability". `0` makes everything available.

### Rotation

`GIANTS_ROTATION` is a `;`-separated list of `World, GameType, Teams` entries. Each entry can end with `setting=value` overrides. The setting is named like its `GIANTS_*` variable (`time_limit=30`, `max_smarties=7`, `damage_teammates=true`; case, `_` and `-` don't matter).

The default is `m_3way_l1, DM, MvR; m_mecc_desertsnakes, DM, MvM; m_reaper_l1, DM, RvR; m_3way_sunsetbay, DMCap, MvR`.

| Game type | Setup tool name |
|-----------|-----------------|
| `DM` | Team Deathmatch |
| `DMFullBase` | Team Deathmatch with Full Base |
| `DMCap` | Capture the Smartie |
| `DMCapFullBase` | Capture the Smartie with Full Base |
| `Build` | Base Build Deathmatch |
| `BuildCap` | Base Build and Capture the Smartie |
| `DefendBase` | Defend the Base |
| `DefendBaseCap` | Capture the Smartie and Defend the Base |

| Teams | |
|-------|---|
| `MvM` | Mecc vs Mecc (`m_mecc_*` worlds) |
| `RvR` | Reaper vs Reaper (`m_reaper_*` worlds) |
| `MvR` | Mecc vs Reaper (`m_3way_*` worlds) |
| `MvMvM` | Mecc vs Mecc vs Mecc (`m_3way_*`) |
| `MvRvK` | Mecc vs Reaper vs Kabuto (`m_3way_*`) |
| `MvK` | Mecc vs Kabuto (`m_3way_*`) |
| `RvK` | Reaper vs Kabuto (`m_3way_*`) |

Worlds in the 1.5 patch (`Bin/w_<world>.gzp` and `Bin/Worlds/w_<world>.gck`; add-on `.gck` worlds dropped into `Bin/Worlds/` work too):

- `m_3way_*`: `canyons`, `collage`, `l1`, `l2`, `l3`, `lw1`, `majorcacanwait`, `sunsetbay`, `wishingwell`
- `m_mecc_*`: `caveman`, `desertsnakes`, `grass`, `greatbay`, `harbor`, `islandzone`, `l1`, `l2`, `l3`, `l6`, `lw1`, `meccmyday`, `precipice`, `redhills`, `spectrum`, `split`, `sprinta`, `stillwinter`, `summit`, `vertigo`, `wilderness`
- `m_reaper_*`: `l1`, `l2`, `l3`, `lw1`

To manage the `.gdf` yourself, save one from the game's `dedicated.exe` into `Overlay/Bin/` and set `GIANTS_GDF_NAME` to its name. A generated `.gdf` has a `<name>.gdf.lancommander` marker file next to it, and only those are overwritten.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/giantscitizenkabuto:local Servers/GiantsCitizenKabuto
```

The DirectX February 2010 redistributable (source of the DirectPlay DLLs) is downloaded at build time and verified by sha256. See `DIRECTX_REDIST_URL` / `DIRECTX_REDIST_SHA256` in the Dockerfile.

---

## License

Giants: Citizen Kabuto, Wine and the DirectX redistributable are distributed under their respective licenses.
This directory contains only Docker build logic and helper scripts licensed under MIT.
