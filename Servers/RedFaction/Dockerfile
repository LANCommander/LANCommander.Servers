# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

# Log files LANCommander shows as consoles under the server's Monitor
LABEL app.lancommander.server.log.server-log="/config/Overlay/logs/DashFaction-dedicated-dm.log"

# ----------------------------
# Server settings
#   - The game files are not downloadable; put a Red Faction 1.20 NA install with Dash Faction in
#     /config/Server, or set RF_ARCHIVE_URL to a zip of one
#   - Server rules live in dedicated_server.txt, one block per "$Name:" game configuration;
#     RF_CONFIG picks the block and the RF_* settings below are written into it on every start
#     (empty settings are left alone)
#   - The server runs headless: in dedicated mode RF opens no window, so Xvfb isn't needed
# ----------------------------
ENV RF_ARCHIVE_URL="" \
    RF_CONFIG="dm" \
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

COPY Scripts/rf-server /usr/local/bin/rf-server
RUN chmod +x /usr/local/bin/rf-server

COPY Hooks/ "${BASE_HOOKS}/"

# 7755/udp: game, server info queries and LAN browser broadcasts (RF_PORT)
EXPOSE 7755/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
