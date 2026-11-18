# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Vietcong Dedicated Server" \
      org.opencontainers.image.description="Dedicated server for Vietcong"

# Log files LANCommander shows as consoles under the server's Monitor
LABEL app.lancommander.server.log.chat="/config/Overlay/dev/chatlog.txt"

# Native DirectPlay comes from the DirectX February 2010 redist. Wine's builtin dpnet cannot host
# (IDirectPlay8Server::Host is a stub), so the redist is cached in the image and installed into the
# prefix with `winetricks directplay` on first start. Microsoft's own URL is gone; this is the mirror
# winetricks pins, checked against the same sha256.
ARG DIRECTX_REDIST_URL="https://files.holarse-linuxgaming.de/mirrors/microsoft/directx_feb2010_redist.exe"
ARG DIRECTX_REDIST_SHA256="f6d191e89a963d7cca34f169d30f49eab99c1ed3bb92da73ec43617caaa1e93f"

# ----------------------------
# Server settings
#   - The game files are not downloadable; put a Vietcong v1.60 install in /config/Server,
#     or set VC_ARCHIVE_URL to a zip of one
#   - The VC_* settings are written to Dedicated/<VC_DED_NAME>.ded on every start
#   - VC_MISSIONS: semicolon-separated "Map, Mode, time|points, value" entries
# ----------------------------
ENV W_CACHE=/opt/winetricks-cache \
    VC_ARCHIVE_URL="" \
    VC_DED_NAME="lancommander" \
    VC_SERVER_NAME="Vietcong Server" \
    VC_PORT="5425" \
    VC_MAX_PLAYERS="32" \
    VC_PASSWORD="" \
    VC_ADMIN_PASSWORD="" \
    VC_JOIN_MESSAGE="" \
    VC_INTERNET_GAME="false" \
    VC_FRIENDLY_FIRE="true" \
    VC_AUTO_BALANCE="true" \
    VC_HRADBA="false" \
    VC_VOICE_CHAT="0" \
    VC_MISSIONS="WaterFall, DM, time, 20:00; Arroyo, DM, time, 20:00; HalongPort, DM, time, 20:00; NVABase, DM, time, 20:00; Storm, DM, time, 20:00; Stream, DM, time, 20:00" \
    VC_SETTINGS="" \
    VC_ADDON="" \
    VC_EXTRA_ARGS="" \
    START_EXE="/usr/local/bin/vc-server" \
    START_ARGS=""

RUN set -eux; \
    mkdir -p "${W_CACHE}/directx9"; \
    curl -fsSL --retry 3 "${DIRECTX_REDIST_URL}" -o "${W_CACHE}/directx9/directx_feb2010_redist.exe"; \
    echo "${DIRECTX_REDIST_SHA256}  ${W_CACHE}/directx9/directx_feb2010_redist.exe" | sha256sum -c -

COPY Scripts/vc-server /usr/local/bin/vc-server
RUN chmod +x /usr/local/bin/vc-server

COPY Hooks/ "${BASE_HOOKS}/"

# 5425/udp: game (DirectPlay host, VC_PORT); it also answers LAN enumeration.
# 6073/udp: DirectPlay session enumeration (dpnsvr), used by the in-game LAN list.
EXPOSE 5425/udp 6073/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
