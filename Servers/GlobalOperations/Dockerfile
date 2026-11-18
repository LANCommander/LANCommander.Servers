# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Global Operations Game Server" \
      org.opencontainers.image.description="Dedicated server for Global Operations 4.0a, running the retail Windows server under Wine" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="Global Operations" \
      app.lancommander.server.external-id.hq="02df3c5d-8def-4f96-a41e-5f27df51bc45" \
      app.lancommander.server.external-id.igdb="8744"

# ----------------------------
# Server settings
#   - The game files are not downloadable; put a Global Operations 4.0a install (goserver.exe,
#     server.dll, Globalops\) in /config/Server, or set GO_ARCHIVE_URL to a zip of one
#   - goserver.exe is a GUI app with no command-line settings. It fills its Server Settings dialog
#     from Globalops\server.cfg and starts hosting when OK is pressed. The configure hook writes the
#     GO_* settings into server.cfg on every start and the launcher presses OK with xdotool.
#   - An empty GO_* variable keeps the value already in server.cfg
#   - GO_MAPS is a comma-separated rotation. "config" keeps the maps in server.cfg
#   - GO_BANDWIDTH: 56k, isdn, dsl, t1, t3 or custom (uses GO_CUSTOM_BANDWIDTH, bytes/s)
#   - GO_LOG_EVENTS writes Globalops\logs\*.log, which the launcher copies to the container log
# ----------------------------
ENV GO_ARCHIVE_URL="" \
    GO_SERVER_NAME="Global Operations Server" \
    GO_PASSWORD="" \
    GO_ADMIN_NAME="" \
    GO_ADMIN_EMAIL="" \
    GO_WEBSITE="" \
    GO_REMOTE_ADMIN_PASSWORD="" \
    GO_MAX_PLAYERS="24" \
    GO_MAPS="antarctica,argentina,chechnya,colombia,lima,mexico,nafrica,quebec,schinasea,srilanka,tunnel,uganda,usa" \
    GO_TIME_LIMIT="30" \
    GO_ROUNDS="5" \
    GO_TEAM_FLIP="false" \
    GO_TEAM_FLIP_ROUNDS="1" \
    GO_LAN="true" \
    GO_FRIENDLY_FIRE="50" \
    GO_FRIENDLY_FIRE_ALLIES="50" \
    GO_MIRROR_DAMAGE="true" \
    GO_MIRROR_DAMAGE_PERCENT="50" \
    GO_MIRROR_CASH="50" \
    GO_TEAM_KILL_PUNISH="true" \
    GO_TEAM_KILLS_TO_KICK="5" \
    GO_CIVILIAN_KILLS_TO_KICK="5" \
    GO_AUTO_TEAM_BALANCE="true" \
    GO_FORCE_TEAM_BALANCE="true" \
    GO_ALLOW_BADGES="true" \
    GO_LOG_EVENTS="true" \
    GO_VOICE="false" \
    GO_BANDWIDTH="t3" \
    GO_CUSTOM_BANDWIDTH="" \
    GO_AFK_KICK="8" \
    GO_TIME_SYNC="true" \
    GO_VOTING="true" \
    GO_VOTE_KICK_RATIO="60" \
    GO_VOTE_MAP_RATIO="60" \
    WINE_XVFB="true" \
    START_EXE="/usr/local/bin/go-server" \
    START_ARGS=""

# xdotool presses OK in the Server Settings dialog; netcat queries the server's GameSpy port so the
# launcher can log when the server is up
RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xdotool netcat-openbsd; \
    rm -rf /var/lib/apt/lists/*

COPY Scripts/go-server /usr/local/bin/go-server
RUN chmod +x /usr/local/bin/go-server

COPY Hooks/ "${BASE_HOOKS}/"

# 27888/udp: game (LithTech). 28672/udp: GameSpy status queries, reported as the host port.
# Neither can be changed.
EXPOSE 27888/udp 28672/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
