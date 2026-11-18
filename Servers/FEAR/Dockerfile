# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="F.E.A.R. Dedicated Server" \
      org.opencontainers.image.description="Dedicated server for F.E.A.R."

# Log files LANCommander shows as consoles under the server's Monitor
LABEL app.lancommander.server.log.server-log="/config/Overlay/Monolith Productions/FEARCombat/fearserver.log"

# ----------------------------
# Server settings
#   - The game files are not downloadable; put a F.E.A.R. Combat (or F.E.A.R.) 1.08 install with
#     FEARServer.exe in /config/Server, or set FEAR_ARCHIVE_URL to a zip of one
#   - FEARServer.exe is a GUI app. `-userdirectory <dir> -optionsfile <name>` loads
#     <dir>\ServerOptions\<name>.txt and hosts right away. The configure hook creates that file
#     and writes the FEAR_* settings below into it on every start (empty settings are left alone)
#   - FEAR_USER_DIR is relative to the game folder and holds ServerOptions\, MPCustomizations.txt,
#     the ban lists and the server log
#   - FEAR_GAME_TYPE: deathmatch, teamdeathmatch, elimination, teamelimination, slowmodeathmatch,
#     teamslowmodeathmatch, ctf, slowmoctf, conquerall, control
#   - FEAR_MAPS is a comma-separated rotation for that game type; bare names are looked up in
#     Worlds\ReleaseMultiplayer. Empty lets the server play every map of the game type;
#     "config" keeps the list in the options file
#   - The server needs a window, so it runs under Xvfb. Its console log is copied to stdout
# ----------------------------
ENV FEAR_ARCHIVE_URL="" \
    FEAR_USER_DIR="Monolith Productions/FEARCombat" \
    FEAR_CONFIG="lancommander" \
    FEAR_SERVER_NAME="F.E.A.R. Combat" \
    FEAR_SERVER_MESSAGE="" \
    FEAR_PORT="27888" \
    FEAR_GAME_TYPE="deathmatch" \
    FEAR_MAPS="" \
    FEAR_MAX_PLAYERS="16" \
    FEAR_SCORE_LIMIT="" \
    FEAR_TIME_LIMIT="" \
    FEAR_ROUNDS="" \
    FEAR_FRIENDLY_FIRE="" \
    FEAR_PASSWORD="" \
    FEAR_SCMD_PASSWORD="" \
    FEAR_LAN_ONLY="true" \
    FEAR_CONTENT_DOWNLOAD="" \
    WINE_XVFB="true" \
    START_EXE="/usr/local/bin/fear-server" \
    START_ARGS=""

COPY Scripts/fear-server /usr/local/bin/fear-server
RUN chmod +x /usr/local/bin/fear-server

COPY Hooks/ "${BASE_HOOKS}/"

# 27888/udp: game and GameSpy status queries (FEAR_PORT)
EXPOSE 27888/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
