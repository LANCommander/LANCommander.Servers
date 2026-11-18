# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

# Log files LANCommander shows as consoles under the server's Monitor
LABEL app.lancommander.server.log.server-log="/config/wineprefix/drive_c/users/lancommander/Documents/Devastation/server.log"

# ----------------------------
# Server settings
#   - The game files are not downloadable; put a Devastation (390) install in /config/Server, or
#     set DEVASTATION_ARCHIVE_URL to a zip of one
#   - DEVASTATION_INI is created from System/Default.ini on first start; the DEVASTATION_*
#     settings below are written into it on every start (empty settings are left alone)
#   - DEVASTATION_GAME_TYPE takes territories, ctf, streetwar, teamstreetwar or a game class
#   - UCC is a console program and needs no X display, so Xvfb is off
# ----------------------------
ENV DEVASTATION_ARCHIVE_URL="" \
    DEVASTATION_MAP="DTT-Union" \
    DEVASTATION_GAME_TYPE="territories" \
    DEVASTATION_PORT="7777" \
    DEVASTATION_INI="Server.ini" \
    DEVASTATION_SERVER_NAME="Devastation Server" \
    DEVASTATION_SHORT_NAME="Devastation Server" \
    DEVASTATION_ADMIN_NAME="" \
    DEVASTATION_ADMIN_EMAIL="" \
    DEVASTATION_MOTD="" \
    DEVASTATION_MAX_PLAYERS="16" \
    DEVASTATION_GAME_PASSWORD="" \
    DEVASTATION_ADMIN_PASSWORD="" \
    DEVASTATION_TIME_LIMIT="" \
    DEVASTATION_FRAG_LIMIT="" \
    DEVASTATION_ROUND_LIMIT="" \
    DEVASTATION_ROUND_TIME_LIMIT="" \
    DEVASTATION_SUDDEN_DEATH_SECONDS="" \
    DEVASTATION_BOTS="" \
    DEVASTATION_SIMULATION="" \
    DEVASTATION_FULL_PHYSICS="" \
    DEVASTATION_MAPS="" \
    DEVASTATION_MASTER_SERVER_UPLINK="false" \
    DEVASTATION_URL_OPTIONS="" \
    WINE_XVFB="false" \
    START_EXE="/usr/local/bin/devastation-server" \
    START_ARGS=""

COPY Scripts/devastation-server /usr/local/bin/devastation-server
RUN chmod +x /usr/local/bin/devastation-server

COPY Hooks/ "${BASE_HOOKS}/"

# 7777/udp: game. 7787/udp: GameSpy server query (game port + 10). 7900/udp: ASE query (game
# port + 123). 8777/udp: LAN browser beacon (UdpBeacon answers REPORTQUERY broadcasts there).
EXPOSE 7777/udp 7787/udp 7900/udp 8777/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
