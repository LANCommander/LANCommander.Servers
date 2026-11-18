# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Daikatana Dedicated Server" \
      org.opencontainers.image.description="Dedicated server for Daikatana"

# Log files LANCommander shows as consoles under the server's Monitor
LABEL app.lancommander.server.log.console="/config/Overlay/data/dk_console.log"

# ----------------------------
# Server settings
#   - The game files are not downloadable; put a Daikatana v1.3 install (the folder holding
#     dk_ded.exe and data/) in /config/Server, or set DAIKATANA_ARCHIVE_URL to a zip of one
#   - The DAIKATANA_* settings are written into data/lancommander.cfg on every start (empty
#     settings are left out); put your own cvars in data/server.cfg
#   - dk_ded.exe is a GUI program and exits without an X display, so Xvfb is on
# ----------------------------
ENV DAIKATANA_ARCHIVE_URL="" \
    DAIKATANA_MODE="dm" \
    DAIKATANA_MAP="e1dm1" \
    DAIKATANA_MAPS="" \
    DAIKATANA_PORT="27992" \
    DAIKATANA_SERVER_NAME="Daikatana Server" \
    DAIKATANA_MAX_PLAYERS="8" \
    DAIKATANA_FRAG_LIMIT="" \
    DAIKATANA_TIME_LIMIT="" \
    DAIKATANA_SKILL="" \
    DAIKATANA_PASSWORD="" \
    DAIKATANA_RCON_PASSWORD="" \
    DAIKATANA_PUBLIC="0" \
    WINE_XVFB="true" \
    START_EXE="/usr/local/bin/daikatana-server" \
    START_ARGS=""

COPY Scripts/daikatana-server /usr/local/bin/daikatana-server
RUN chmod +x /usr/local/bin/daikatana-server

COPY Hooks/ "${BASE_HOOKS}/"

# 27992/udp: game (DAIKATANA_PORT). 27982/udp: GameSpy query (game port - 10).
EXPOSE 27992/udp 27982/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
