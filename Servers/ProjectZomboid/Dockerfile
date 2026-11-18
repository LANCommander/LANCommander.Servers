# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/steamcmd:local
ARG BASE_IMAGE=lancommander/steamcmd:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Project Zomboid Game Server" \
      org.opencontainers.image.description="Dedicated server for Project Zomboid, installed via SteamCMD" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="Project Zomboid" \
      app.lancommander.server.external-id.hq="5e9fadc4-a4f2-470e-bc73-ad0689ec6394" \
      app.lancommander.server.external-id.igdb="3189" \
      app.lancommander.server.external-id.steam="108600"

# Log files LANCommander shows as consoles under the server's Monitor
LABEL app.lancommander.server.log.server-log="/config/Zomboid/server-console.txt"

# SteamCMD settings: Project Zomboid Dedicated Server (app 380870, anonymous).
# Set STEAM_BRANCH (e.g. legacy41) to run an older build.
ENV STEAM_APP_ID="380870"
ENV START_EXE="pz-server"
ENV START_ARGS=""

# Server settings, used by pz-server
#   PZ_SERVER_NAME: name of the server's config/save set (<name>.ini, <name>_SandboxVars.lua, ...)
#   PZ_CACHE_DIR: config, saves, logs and the player database (the game's ~/Zomboid)
#   PZ_MEMORY: JVM heap (-Xms/-Xmx), empty = the value from ProjectZomboid64.json
#   PZ_STEAM: false runs the server with -nosteam (clients must use -nosteam too)
ENV PZ_SERVER_NAME="servertest" \
    PZ_CACHE_DIR="/config/Zomboid" \
    PZ_ADMIN_USERNAME="" \
    PZ_ADMIN_PASSWORD="changeme" \
    PZ_MEMORY="" \
    PZ_STEAM="true"

# Values written into <PZ_SERVER_NAME>.ini on startup (empty = leave as is).
# Any other key can be set with PZ_INI_<Key>, e.g. PZ_INI_SafehouseAllowLoot=false.
ENV PZ_PUBLIC_NAME="" \
    PZ_PUBLIC_DESCRIPTION="" \
    PZ_MAX_PLAYERS="" \
    PZ_PASSWORD="" \
    PZ_PORT="" \
    PZ_UDP_PORT="" \
    PZ_RCON_PORT="" \
    PZ_RCON_PASSWORD="" \
    PZ_PUBLIC="" \
    PZ_PVP="" \
    PZ_PAUSE_EMPTY="" \
    PZ_MAP="" \
    PZ_MODS="" \
    PZ_WORKSHOP_ITEMS=""

# The game has no custom content to download
ENV HTTP_FILESERVER_ENABLED="false"

# Game traffic, .ini DefaultPort
EXPOSE 16261/udp
# Direct connections, .ini UDPPort
EXPOSE 16262/udp
# Steam game server ports
EXPOSE 8766/udp
EXPOSE 8767/udp
# RCON, .ini RCONPort
EXPOSE 27015/tcp

COPY Hooks/ "${BASE_HOOKS}/"
COPY --chmod=0755 Scripts/pz-server /usr/local/bin/pz-server

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
