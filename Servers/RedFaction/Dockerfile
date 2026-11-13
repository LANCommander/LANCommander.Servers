# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

# Alpine Faction release (GitHub tag without the leading "v")
ARG AF_VERSION=1.4.0_Lupin

# Log files LANCommander shows as consoles under the server's Monitor
LABEL app.lancommander.server.log.server-log="/config/Overlay/logs/AlpineFaction-dedicated-server.log"

# ----------------------------
# Server settings
#   - The game files are not downloadable; put a Red Faction 1.20 NA install in /config/Server,
#     or set RF_ARCHIVE_URL to a zip of one
#   - Alpine Faction is baked into the image and copied into the game folder on every start
#     (AF_INSTALL=false keeps the folder's own copy)
#   - Server rules and the level rotation live in <RF_CONFIG>.toml (an Alpine Faction ADS config),
#     created from a default on first start; the RF_* settings below are written into it on
#     every start (empty settings are left alone)
#   - The server runs headless: in dedicated mode RF opens no window, so Xvfb isn't needed
# ----------------------------
ENV AF_VERSION="${AF_VERSION}" \
    AF_INSTALL="true" \
    RF_ARCHIVE_URL="" \
    RF_CONFIG="server" \
    RF_PORT="7755" \
    RF_LAN_ONLY="true" \
    RF_EXE="" \
    RF_SERVER_NAME="Red Faction Server" \
    RF_MAX_PLAYERS="16" \
    RF_PASSWORD="" \
    RF_RCON_PASSWORD="" \
    WINE_XVFB="false" \
    START_EXE="/usr/local/bin/rf-server" \
    START_ARGS=""

RUN curl -fsSL --retry 3 -o /tmp/alpinefaction.zip \
        "https://github.com/GooberRF/alpinefaction/releases/download/v${AF_VERSION}/AlpineFaction-${AF_VERSION}.zip" \
 && pwsh -NoProfile -Command "Expand-Archive -Path /tmp/alpinefaction.zip -DestinationPath /opt/alpinefaction" \
 && rm -f /tmp/alpinefaction.zip /opt/alpinefaction/_README.txt \
 && test -f /opt/alpinefaction/AlpineFactionLauncher.exe

COPY Scripts/rf-server /usr/local/bin/rf-server
COPY Scripts/server.toml /usr/local/share/redfaction/server.toml
RUN chmod +x /usr/local/bin/rf-server

COPY Hooks/ "${BASE_HOOKS}/"

# 7755/udp: game, server info queries and LAN browser broadcasts (RF_PORT)
EXPOSE 7755/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
