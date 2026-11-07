# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/base:local
ARG BASE_IMAGE=lancommander/base:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="The Elder Scrolls III: Morrowind Game Server" \
      org.opencontainers.image.description="TES3MP 0.8.1 multiplayer server for The Elder Scrolls III: Morrowind (the official Linux build)" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="The Elder Scrolls III: Morrowind" \
      app.lancommander.server.external-id.hq="27f61f63-f6eb-4103-a5b2-8d42d7aff9eb" \
      app.lancommander.server.external-id.igdb="56" \
      app.lancommander.server.external-id.steam="22320" \
      app.lancommander.server.external-id.gog="1440163901"

# ----------------------------
# Server settings
#   - TES3MP_SERVER_URL is the official TES3MP 0.8.1 Linux server package (tes3mp-server.x86_64,
#     its libraries and the CoreScripts in server/). It is unpacked into /config/Server on first
#     start and verified against TES3MP_SERVER_SHA256 (empty = no check). The server needs no
#     Morrowind data files; clients bring their own
#   - The [General]/[MasterServer] settings are written into tes3mp-server-default.cfg and the
#     CoreScripts settings into server/scripts/config.lua on every start. Empty settings are
#     left alone
# ----------------------------
ENV TES3MP_SERVER_URL="https://github.com/TES3MP/TES3MP/releases/download/tes3mp-0.8.1/tes3mp-server-GNU%2BLinux-x86_64-release-0.8.1-68954091c5-6da3fdea59.tar.gz" \
    TES3MP_SERVER_SHA256="106a56e32a00ff7a92b574fae0e25671e90a199f509b16d483a8d7da6fc3bcf0" \
    TES3MP_PORT="25565" \
    TES3MP_LAN="true" \
    TES3MP_MAX_PLAYERS="64" \
    TES3MP_SERVER_NAME="TES3MP Server" \
    TES3MP_PASSWORD="" \
    TES3MP_LOG_LEVEL="1" \
    TES3MP_GAME_MODE="" \
    TES3MP_DIFFICULTY="" \
    TES3MP_MAX_CLIENTS_PER_IP="" \
    TES3MP_ALLOW_CONSOLE="" \
    TES3MP_PASS_TIME_WHEN_EMPTY="" \
    TES3MP_SHARE_JOURNAL="" \
    TES3MP_SHARE_MAP_EXPLORATION="" \
    START_EXE="/usr/local/bin/tes3mp-server" \
    START_ARGS=""

# tes3mp-server.x86_64 ships its own Boost libraries but links the system LuaJIT
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        unzip \
        libluajit-5.1-2 && \
    rm -rf /var/lib/apt/lists/*

COPY Scripts/tes3mp-server /usr/local/bin/tes3mp-server
RUN chmod +x /usr/local/bin/tes3mp-server

COPY Hooks/ "${BASE_HOOKS}/"

# 25565/udp: game and server info queries (TES3MP_PORT)
EXPOSE 25565/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
