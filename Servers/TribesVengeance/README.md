# Tribes: Vengeance Dedicated Server (Docker)

This image provides a Dockerized **Tribes: Vengeance dedicated server via WINE** suitable for running multiplayer Tribes: Vengeance servers in a clean, reproducible way.  
The image is designed for **headless operation**, supports bind-mounted configuration, and handles runtime dependencies required by Tribes: Vengeance.

---

## Features

- Runs the **Tribes: Vengeance dedicated server** (`Beta_Dedicated_Server.exe`)
- Automated build & push via GitHub Actions

## Docker Compose Example
```yaml
services:
  tribesvengeance:
    image: lancommander/tribesvengeance:latest
    container_name: tribesvengeance-server

    # Tribes: Vengeance uses UDP
    ports:
      - "7777:7777/udp"
      - "7778:7778/udp"

    # Bind mounts so files appear on the host
    volumes:
      - ./config:/config

    # Ensure container restarts if the server crashes or host reboots
    restart: unless-stopped
```

The same file is in this directory as [`compose.yml`](compose.yml).

---

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Base Tribes: Vengeance dedicated server install
    ├── Overlay/           # Files to overlay on game directory (optional)
    │   └── savedata/      # Tribes: Vengeance savedata
    │       └── ...        # Any other files you want to overlay
    ├── Merged/            # Overlayfs merged view (auto-created)
    ├── .overlay-work/     # Overlayfs work directory (auto-created)
    ├── Scripts/
        └── Hooks/         # Script files in this directory get automatically executed if registered to a hook
```
Both directories **must be writable** by Docker.

---

## Environment Variables

| Variable | Description | Default |
|--------|-------------|---------|
| `SERVER_ARGS` | Additional Tribes: Vengeance command-line arguments (advanced) | `Program/Bin/Beta_Dedicated_Server.exe MP-REV-CanyonCrusade?game=GameClasses.ModeCTF?maxplayers=32` |

---

## Running the Server
### Basic run (recommended)
```bash
mkdir -p config

docker run --rm -it \
  -p 7777:7777/udp \
  -p 7778:7778/udp
  -v "$(pwd)/config:/config" \
  lancommander/tribesvengeance:latest
```

## Ports
- **UDP 7777/7778** – default Tribes: Vengeance server port

## License
Tribes: Vengeance is distributed under its own license.
This directory contains Docker build logic and helper scripts licensed under MIT.