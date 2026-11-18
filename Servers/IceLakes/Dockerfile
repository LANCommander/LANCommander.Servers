# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/steamcmd:local
ARG BASE_IMAGE=lancommander/steamcmd:latest
FROM ${BASE_IMAGE}

# Log files LANCommander shows as consoles under the server's Monitor
LABEL app.lancommander.server.log.server-log="/config/Logs/IceLakes_Server.log"

# SteamCMD settings
ENV STEAM_APP_ID="460300"
ENV START_EXE="icelakes-server"
ENV START_ARGS="-batchmode -nographics"

# Values written into the [Server] section of server.cfg on startup (empty = leave as is)
ENV ICELAKES_SERVER_NAME=""
ENV ICELAKES_MAX_PLAYERS=""
ENV ICELAKES_PASSWORD=""
ENV ICELAKES_ADMIN_PASSWORD=""
ENV ICELAKES_PORT=""
ENV ICELAKES_QUERY_PORT=""
ENV ICELAKES_FISH_NOTIFICATIONS=""
ENV ICELAKES_FISH_FIGHT=""
ENV ICELAKES_BATTLE_ROYALE=""

# Server log, followed to stdout by icelakes-server
ENV ICELAKES_LOG_FILE="/config/Logs/IceLakes_Server.log"

# The game has no custom content to download
ENV HTTP_FILESERVER_ENABLED="false"

# Game traffic (UNET), server.cfg Port
EXPOSE 13300/udp
# Steam server queries / LAN server browser, server.cfg OutPort
EXPOSE 27015/udp
# Steam game server (master server communication)
EXPOSE 8766/udp

COPY Hooks/ "${BASE_HOOKS}/"
COPY --chmod=0755 Scripts/icelakes-server /usr/local/bin/icelakes-server

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
