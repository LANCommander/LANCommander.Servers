# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/base:local
ARG BASE_IMAGE=lancommander/base:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="The Elder Scrolls III: Morrowind Game Server" \
      org.opencontainers.image.description="TES3MP multiplayer server for The Elder Scrolls III: Morrowind (the official Linux build, latest or a chosen version)" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="The Elder Scrolls III: Morrowind" \
      app.lancommander.server.external-id.hq="27f61f63-f6eb-4103-a5b2-8d42d7aff9eb" \
      app.lancommander.server.external-id.igdb="56" \
      app.lancommander.server.external-id.steam="22320" \
      app.lancommander.server.external-id.gog="1440163901"

# ----------------------------
# Server settings
#   - TES3MP_VERSION picks the official TES3MP Linux server package from the GitHub releases:
#     "latest" (the newest release that has a Linux server, looked up on every start) or a version
#     such as 0.8.1 or 0.8.0 (0.8.0 and newer are supported). 0.8.1 and 0.8.0 are pinned with
#     their SHA-256 and install without the GitHub API. Clients must run the same version
#   - TES3MP_SERVER_URL installs another package instead (.tar.gz or .zip, file:// too), checked
#     against TES3MP_SERVER_SHA256 when set
#   - The package (tes3mp-server.x86_64, its libraries and the CoreScripts) is unpacked into
#     /config/Server on first start and whenever the resolved package changes. The server needs no
#     Morrowind data files; clients bring their own
#   - The [General]/[MasterServer] settings are written into tes3mp-server-default.cfg and the
#     CoreScripts settings into <CoreScripts>/scripts/config.lua on every start. Empty settings
#     are left alone
# ----------------------------
ENV TES3MP_VERSION="latest" \
    TES3MP_SERVER_URL="" \
    TES3MP_SERVER_SHA256="" \
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
