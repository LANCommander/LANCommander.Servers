# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

# Native DirectPlay comes from the DirectX February 2010 redist. LegendServ.exe hosts through
# DirectPlay's "Internet TCP/IP" service provider, which Wine's builtin dplayx can't load
# (DPERR_UNAVAILABLE, and the server hangs at "Starting world.."). The redist is cached in the image
# and installed into the prefix with `winetricks directplay` on first start. Microsoft's own URL is
# gone; this is the mirror winetricks pins, checked against the same sha256.
ARG DIRECTX_REDIST_URL="https://files.holarse-linuxgaming.de/mirrors/microsoft/directx_feb2010_redist.exe"
ARG DIRECTX_REDIST_SHA256="f6d191e89a963d7cca34f169d30f49eab99c1ed3bb92da73ec43617caaa1e93f"

# ----------------------------
# Server settings
#   - The game files are not downloadable; put a Legends of Might and Magic 1.1 install
#     (LegendServ.exe, server.dll, Data\) in /config/Server, or set LOMM_ARCHIVE_URL to a zip of one
#   - LegendServ.exe is a GUI app with no command-line settings. It reads them from the registry
#     and ROTATION.TXT, shows its Host Settings dialog, and hosts when OK is pressed. The configure
#     hook writes the LOMM_* settings on every start and the launcher presses OK with xdotool.
#   - LOMM_MAPS is a comma-separated rotation. Empty uses the 20 retail maps; "config" keeps
#     ROTATION.TXT as it is
#   - LOMM_CONNECTION_TYPE: 56k, isdn, cable, dsl, t1 or custom (uses LOMM_UPLOAD_BANDWIDTH)
#   - LOMM_ALLOW_SHARED_CD_KEYS patches Data\object.lto so players with the same CD key can join
#     (the digital releases all share one key)
# ----------------------------
ENV W_CACHE=/opt/winetricks-cache \
    LOMM_ARCHIVE_URL="" \
    LOMM_SERVER_NAME="Legends of Might&Magic" \
    LOMM_PASSWORD="" \
    LOMM_MAX_PLAYERS="16" \
    LOMM_MAPS="" \
    LOMM_MAP_TIME="20" \
    LOMM_ROUND_TIME="5" \
    LOMM_PURCHASE_TIME="5" \
    LOMM_FRIENDLY_FIRE="false" \
    LOMM_ALLOW_VOTING="true" \
    LOMM_BALANCE_TEAMS="true" \
    LOMM_MONSTERS="true" \
    LOMM_SUPER_WEAPONS="true" \
    LOMM_DAMAGE_THROUGH_WALLS="true" \
    LOMM_LOCKED_CHASE_CAM="false" \
    LOMM_LAN_ONLY="false" \
    LOMM_CONNECTION_TYPE="t1" \
    LOMM_UPLOAD_BANDWIDTH="" \
    LOMM_PORT="29800" \
    LOMM_GAMESPY_PORT="29801" \
    LOMM_ALLOW_SHARED_CD_KEYS="true" \
    WINE_XVFB="true" \
    START_EXE="/usr/local/bin/lomm-server" \
    START_ARGS=""

# xdotool presses OK in the Host Settings dialog; netcat queries the server's GameSpy port so the
# launcher can log the current map
RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xdotool netcat-openbsd; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p "${W_CACHE}/directx9"; \
    curl -fsSL --retry 3 "${DIRECTX_REDIST_URL}" -o "${W_CACHE}/directx9/directx_feb2010_redist.exe"; \
    echo "${DIRECTX_REDIST_SHA256}  ${W_CACHE}/directx9/directx_feb2010_redist.exe" | sha256sum -c -

COPY Scripts/lomm-server /usr/local/bin/lomm-server
RUN chmod +x /usr/local/bin/lomm-server

COPY Hooks/ "${BASE_HOOKS}/"

# 29800/udp: game (DirectPlay TCP/IP, LOMM_PORT). 29801/udp: GameSpy status queries (LOMM_GAMESPY_PORT).
EXPOSE 29800/udp 29801/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
