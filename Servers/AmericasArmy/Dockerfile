# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

# Log files LANCommander shows as consoles under the server's Monitor
LABEL app.lancommander.server.log.server-log="/config/Overlay/System/server.log"

# ----------------------------
# Server settings
#   - The game files are not downloadable; put an America's Army 2.8.5 install in /config/Server,
#     or set AA_ARCHIVE_URL to a zip of one
#   - The AA_* settings below are written into System/<AA_INI> on every start (empty settings are
#     left alone)
#   - Server.exe is a console program and needs no X display, so Xvfb is off
# ----------------------------
ENV AA_ARCHIVE_URL="" \
    AA_MODE="LAN" \
    AA_MAP="Bridge" \
    AA_PORT="1716" \
    AA_INI="server.ini" \
    AA_SERVER_NAME="America's Army Server" \
    AA_ADMIN_NAME="" \
    AA_ADMIN_EMAIL="" \
    AA_MOTD="" \
    AA_MAX_PLAYERS="" \
    AA_GAME_PASSWORD="" \
    AA_ADMIN_PASSWORD="" \
    AA_TIME_LIMIT="" \
    AA_ROUNDS_PER_MATCH="" \
    AA_MAPS="" \
    AA_GAMESPY_IP="" \
    AA_URL_OPTIONS="" \
    WINE_XVFB="false" \
    START_EXE="/usr/local/bin/aa-server" \
    START_ARGS=""

COPY Scripts/aa-server /usr/local/bin/aa-server
RUN chmod +x /usr/local/bin/aa-server

COPY Hooks/ "${BASE_HOOKS}/"

# 1716/udp: game. 1717/udp: GameSpy query (game port + 1). 1718/udp: master server query.
# 8777/udp: standard Unreal query.
EXPOSE 1716/udp 1717/udp 1718/udp 8777/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
