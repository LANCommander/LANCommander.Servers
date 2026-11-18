# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/base:local
ARG BASE_IMAGE=lancommander/base:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Medal of Honor: Allied Assault Game Server" \
      org.opencontainers.image.description="Dedicated server for Medal of Honor: Allied Assault, Spearhead and Breakthrough, running on OpenMoHAA" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="Medal of Honor: Allied Assault" \
      app.lancommander.server.external-id.hq="315d8678-4db5-41fb-8cc0-112f2a36110e" \
      app.lancommander.server.external-id.igdb="326"

# ----------------------------
# OpenMoHAA (open-source MOH:AA engine, compatible with the original 1.11/2.15/2.40 clients)
#   - Only the dedicated server (omohaaded), game.so and the bundled libcurl are kept, in
#     /opt/openmohaa. The game data comes from /config/Merged (fs_basepath)
# ----------------------------
ARG OPENMOHAA_VERSION=0.82.1
ARG OPENMOHAA_SHA256=57692d057a684afb7f7e91a61fcd8c062b29ab1b639f27453830084a88cd653c

ADD --checksum=sha256:${OPENMOHAA_SHA256} \
    https://github.com/openmoh/openmohaa/releases/download/v${OPENMOHAA_VERSION}/openmohaa-v${OPENMOHAA_VERSION}-linux-amd64.zip \
    /tmp/openmohaa.zip

RUN pwsh -NoProfile -Command "Expand-Archive -Path /tmp/openmohaa.zip -DestinationPath /tmp/openmohaa" && \
    mkdir -p /opt/openmohaa && \
    mv /tmp/openmohaa/omohaaded /tmp/openmohaa/game.so /tmp/openmohaa/libcurl.so.4 /opt/openmohaa/ && \
    chmod 755 /opt/openmohaa/omohaaded && \
    rm -rf /tmp/openmohaa /tmp/openmohaa.zip

# ----------------------------
# Server settings
#   - MOHAA_GAME picks the game: aa (Allied Assault, main/), sh (Spearhead, mainta/) or
#     bt (Breakthrough, maintt/)
#   - The MOHAA_* settings below are written into <game dir>/lancommander.cfg on every start
#     (empty settings are left out); it execs server.cfg first and ends by loading the first map
# ----------------------------
ENV OPENMOHAA_VERSION="${OPENMOHAA_VERSION}" \
    MOHAA_GAME="aa" \
    MOHAA_PORT="12203" \
    MOHAA_GAMESPY_PORT="12300" \
    MOHAA_LAN="true" \
    MOHAA_SERVER_NAME="Medal of Honor Server" \
    MOHAA_MAX_PLAYERS="20" \
    MOHAA_PASSWORD="" \
    MOHAA_RCON_PASSWORD="" \
    MOHAA_GAME_TYPE="tdm" \
    MOHAA_MAPS="" \
    MOHAA_TIME_LIMIT="20" \
    MOHAA_FRAG_LIMIT="" \
    MOHAA_ROUND_LIMIT="" \
    MOHAA_TEAM_DAMAGE="" \
    MOHAA_ALLOW_VOTE="" \
    START_EXE="/usr/local/bin/mohaa-server" \
    START_ARGS=""

COPY Scripts/mohaa-server /usr/local/bin/mohaa-server
RUN chmod +x /usr/local/bin/mohaa-server

COPY Hooks/ "${BASE_HOOKS}/"

# 12203/udp: game and RCON (MOHAA_PORT)
# 12300/udp: GameSpy queries, used by the server browser and the LAN search (MOHAA_GAMESPY_PORT)
EXPOSE 12203/udp 12300/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
