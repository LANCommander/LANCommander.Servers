# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="XIII Dedicated Server" \
      org.opencontainers.image.description="Dedicated server for XIII"

# Log files LANCommander shows as consoles under the server's Monitor
LABEL app.lancommander.server.log.server-log="/config/Overlay/System/server.log"

# ----------------------------
# Server settings
#   - The game files are not downloadable; put an XIII install (patch 1.4) in /config/Server, or
#     set XIII_ARCHIVE_URL to a zip of one
#   - The game rules below go on the UCC command line, like the game's ServerLauncher.exe does
#   - XIII_INI is created from System/XIII.ini on first start (engine settings, server actors)
# ----------------------------
ENV XIII_ARCHIVE_URL="" \
    XIII_MAP="DM_Banque" \
    XIII_MAP_NAME="" \
    XIII_GAME_TYPE="dm" \
    XIII_PORT="7777" \
    XIII_SERVER_NAME="XIII Server" \
    XIII_MAX_PLAYERS="8" \
    XIII_FRAG_LIMIT="20" \
    XIII_TIME_LIMIT="15" \
    XIII_FRIENDLY_FIRE="false" \
    XIII_PASSWORD="" \
    XIII_ADMIN_PASSWORD="" \
    XIII_MUTATORS="" \
    XIII_LAN="true" \
    XIII_INI="Server.ini" \
    XIII_MASTER_SERVER_UPLINK="false" \
    XIII_PATCH_ENGINE="true" \
    XIII_URL_OPTIONS="" \
    START_EXE="/usr/local/bin/xiii-server" \
    START_ARGS=""

COPY Scripts/xiii-server /usr/local/bin/xiii-server
RUN chmod +x /usr/local/bin/xiii-server

COPY Hooks/ "${BASE_HOOKS}/"

# 7777/udp: game. 7099/udp: server query (fixed, not game port + 1). 8777/udp: LAN browser beacon
# (answers REPORTQUERY broadcasts with "XIII 7099").
EXPOSE 7777/udp 7099/udp 8777/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
