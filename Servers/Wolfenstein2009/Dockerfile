# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Wolfenstein (2009) Game Server" \
      org.opencontainers.image.description="Dedicated server for Wolfenstein (2009), run under Wine from the game's own files" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="Wolfenstein" \
      app.lancommander.server.external-id.hq="a76bcd63-2618-467a-ad7d-66f154eaff78" \
      app.lancommander.server.external-id.igdb="569" \
      app.lancommander.server.external-id.steam="10170"

# Log files LANCommander shows as consoles under the server's Monitor
LABEL app.lancommander.server.log.console="/config/wineprefix/drive_c/users/lancommander/Documents/id Software/WolfMP/base/console.log"

# ----------------------------
# Server settings
#   - The server is the game's own Wolf2MPLite.exe (multiplayer 1.2, the "MP" folder of an
#     installed game). It can't be redistributed: put the installed MP folder in /config/Server,
#     or point WOLF_ARCHIVE / WOLF_ARCHIVE_URL at a zip of the game (or of its MP folder)
#   - The WOLF_* settings are written into base/lancommander.cfg on every start, unless
#     WOLF_MANAGE_CONFIG=false; the server execs it after its own configs
#   - WOLF_MAPS: comma-separated, played in this order; empty = all eight. A map can carry its own
#     rules: mp_bank:stopwatch. WOLF_RULES is the rules for the rest: objective, stopwatch, tdm
#   - The server is a GUI program and exits without a display, so it runs under Xvfb
# ----------------------------
ENV WOLF_ARCHIVE="" \
    WOLF_ARCHIVE_URL="" \
    WOLF_MANAGE_CONFIG="true" \
    WOLF_PORT="27758" \
    WOLF_LAN_ONLY="true" \
    WOLF_SERVER_NAME="LANCommander Wolfenstein" \
    WOLF_PASSWORD="" \
    WOLF_RCON_PASSWORD="" \
    WOLF_MAX_PLAYERS="12" \
    WOLF_MAX_PLAYERS_PER_TEAM="" \
    WOLF_MIN_PLAYERS="0" \
    WOLF_TIME_LIMIT="20" \
    WOLF_TEAM_DAMAGE="false" \
    WOLF_RULES="objective" \
    WOLF_MAPS="" \
    WOLF_MOTD="" \
    WOLF_EXTRA_CONFIG="" \
    WINE_XVFB="true" \
    START_EXE="/usr/local/bin/wolf-server" \
    START_ARGS=""

COPY Scripts/wolf-server /usr/local/bin/wolf-server
RUN chmod +x /usr/local/bin/wolf-server

COPY Hooks/ "${BASE_HOOKS}/"

# 27758/udp: game (WOLF_PORT). 3074/udp: DemonWare/sdnet session traffic.
EXPOSE 27758/udp 3074/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
