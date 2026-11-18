# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/base:local
ARG BASE_IMAGE=lancommander/base:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Soldat Game Server" \
      org.opencontainers.image.description="Dedicated server for Soldat 1.7.1 (SoldatServer 2.8.2, the non-Steam Linux build)" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="Soldat" \
      app.lancommander.server.external-id.hq="b40e3261-df65-4bac-baba-5446007e68af" \
      app.lancommander.server.external-id.igdb="8722" \
      app.lancommander.server.external-id.steam="638490"

# ----------------------------
# Server settings
#   - SOLDAT_SERVER_URL is the official SoldatServer 2.8.2 for game 1.7.1.1 (the non-Steam build,
#     no Steam authentication), from soldat.pl. It is unpacked into /config/Server on first start
#     and verified against SOLDAT_SERVER_SHA256 (empty = no check)
#   - The SOLDAT_* settings below are written into soldat.ini on every start (empty settings are
#     left alone); SOLDAT_MAPS replaces mapslist.txt
#   - SOLDAT_GAME_TYPE takes dm, pm, tm, ctf, rm, inf, htf or the GameStyle number
# ----------------------------
ENV SOLDAT_SERVER_URL="https://static.soldat.pl/downloads/soldatserver2.8.2_1.7.1.1.zip" \
    SOLDAT_SERVER_SHA256="6ec945868029587ac16e2afe42815b04db7cdddbd97a1625601989c04a867099" \
    SOLDAT_PORT="23073" \
    SOLDAT_LAN="true" \
    SOLDAT_SERVER_NAME="Soldat Server" \
    SOLDAT_GREETING="" \
    SOLDAT_SERVER_INFO="" \
    SOLDAT_MAX_PLAYERS="16" \
    SOLDAT_MAX_SPECTATORS="" \
    SOLDAT_GAME_PASSWORD="" \
    SOLDAT_ADMIN_PASSWORD="" \
    SOLDAT_GAME_TYPE="ctf" \
    SOLDAT_MAPS="" \
    SOLDAT_SCORE_LIMIT="" \
    SOLDAT_TIME_LIMIT="" \
    SOLDAT_RESPAWN_TIME="" \
    SOLDAT_FRIENDLY_FIRE="" \
    SOLDAT_BALANCE_TEAMS="" \
    SOLDAT_REALISTIC="" \
    SOLDAT_SURVIVAL="" \
    SOLDAT_BOTS="" \
    SOLDAT_BOT_DIFFICULTY="" \
    START_EXE="/usr/local/bin/soldat-server" \
    START_ARGS=""

# soldatserver is a 32-bit binary that links only libc
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        unzip \
        libc6:i386 && \
    rm -rf /var/lib/apt/lists/*

COPY Scripts/soldat-server /usr/local/bin/soldat-server
RUN chmod +x /usr/local/bin/soldat-server

COPY Hooks/ "${BASE_HOOKS}/"

# 23073/udp: game, lobby and All-Seeing Eye traffic (SOLDAT_PORT). 23073/tcp: Soldat Admin remote
# console (same port, only with an admin password). 23083/tcp: map/file download (game port + 10).
EXPOSE 23073/udp 23073/tcp 23083/tcp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
