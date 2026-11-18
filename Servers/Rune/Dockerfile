# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Rune Game Server" \
      org.opencontainers.image.description="Dedicated server for Rune (Rune Classic 1.10), running the retail Windows UCC server under Wine" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="Rune" \
      app.lancommander.server.external-id.hq="4258f87f-492e-4871-8960-5dd9e6e32b50" \
      app.lancommander.server.external-id.igdb="3085" \
      app.lancommander.server.external-id.steam="210950" \
      app.lancommander.server.external-id.gog="1207660013"

# Log files LANCommander shows as consoles under the server's Monitor
LABEL app.lancommander.server.log.server-log="/config/Overlay/System/server.log"

# ----------------------------
# Server settings
#   - The game files are not downloadable; put a Rune Classic (1.10) install in /config/Server,
#     or set RUNE_ARCHIVE_URL to a zip of one
#   - RUNE_INI is created from System/Default.ini on first start; the RUNE_* settings below are
#     written into it on every start (empty settings are left alone)
#   - RUNE_GAME_TYPE takes deathmatch, team, arena, headball or a game class
#   - UCC is a console program and needs no X display, so Xvfb is off
# ----------------------------
ENV RUNE_ARCHIVE_URL="" \
    RUNE_MAP="DM-Hel" \
    RUNE_GAME_TYPE="deathmatch" \
    RUNE_MAPS="" \
    RUNE_PORT="7777" \
    RUNE_INI="Server.ini" \
    RUNE_SERVER_NAME="Rune Server" \
    RUNE_SHORT_NAME="Rune Server" \
    RUNE_ADMIN_NAME="" \
    RUNE_ADMIN_EMAIL="" \
    RUNE_MOTD="" \
    RUNE_MAX_PLAYERS="16" \
    RUNE_MAX_SPECTATORS="" \
    RUNE_GAME_PASSWORD="" \
    RUNE_ADMIN_PASSWORD="" \
    RUNE_FRAG_LIMIT="" \
    RUNE_TIME_LIMIT="" \
    RUNE_GOAL_TEAM_SCORE="" \
    RUNE_FRIENDLY_FIRE_SCALE="" \
    RUNE_HARDCORE="" \
    RUNE_MEGA_SPEED="" \
    RUNE_LIMB_SEVER="" \
    RUNE_WEB_ADMIN="false" \
    RUNE_WEB_ADMIN_PORT="8080" \
    RUNE_WEB_ADMIN_USER="admin" \
    RUNE_MASTER_SERVER_UPLINK="false" \
    RUNE_URL_OPTIONS="" \
    WINE_XVFB="false" \
    START_EXE="/usr/local/bin/rune-server" \
    START_ARGS=""

COPY Scripts/rune-server /usr/local/bin/rune-server
RUN chmod +x /usr/local/bin/rune-server

COPY Hooks/ "${BASE_HOOKS}/"

# 7777/udp: game. 7778/udp: GameSpy server query (game port + 1). 8777/udp: LAN browser beacon
# (UdpBeacon answers REPORTQUERY broadcasts there). 8080/tcp: web admin, off by default.
EXPOSE 7777/udp 7778/udp 8777/udp 8080/tcp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
