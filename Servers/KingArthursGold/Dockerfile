# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/base:local
ARG BASE_IMAGE=lancommander/base:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="King Arthur's Gold Game Server" \
      org.opencontainers.image.description="Dedicated server for King Arthur's Gold (the official Linux build from kag2d.com)" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="King Arthur's Gold" \
      app.lancommander.server.external-id.hq="4f9a9327-1ff0-4300-b759-5deab66902fb" \
      app.lancommander.server.external-id.igdb="7209" \
      app.lancommander.server.external-id.steam="219830"

# ----------------------------
# Server settings
#   - KAG_SERVER_URL is Transhuman Design's Linux dedicated server (build 2844, May 2024). It is
#     unpacked into /config/Server on first start and verified against KAG_SERVER_SHA256
#     (empty = no check). The URL always serves the newest release, so clear the hash if THD
#     ever ships a new build
#   - The KAG_* settings below are written into autoconfig.cfg on every start (empty settings are
#     left alone); KAG_MAP_CYCLE writes lancommander_mapcycle.cfg and points sv_mapcycle at it
# ----------------------------
ENV KAG_SERVER_URL="https://dl.kag2d.com/kag-linux32-dedicated-release.tar.gz" \
    KAG_SERVER_SHA256="1d01eb5bed85bf049591b56ce1634848035fa4b45ff77402364093d5d8a7560c" \
    KAG_PORT="50301" \
    KAG_LAN="true" \
    KAG_SERVER_NAME="King Arthur's Gold Server" \
    KAG_SERVER_INFO="" \
    KAG_MAX_PLAYERS="16" \
    KAG_SPECTATOR_SLOTS="" \
    KAG_PASSWORD="" \
    KAG_RCON_PASSWORD="" \
    KAG_TCPR="" \
    KAG_GAME_MODE="CTF" \
    KAG_MAP_CYCLE="" \
    KAG_MAP_CYCLE_SHUFFLE="" \
    KAG_CAN_PAUSE="" \
    START_EXE="/usr/local/bin/kag-server" \
    START_ARGS=""

# KAGdedi and libJuxta_dedi.so are 32-bit and link libc, libstdc++ and libgcc_s; the server
# downloads its update manifest over HTTPS with the bundled curl-ca-bundle.crt
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        libc6:i386 \
        libgcc-s1:i386 \
        libstdc++6:i386 && \
    rm -rf /var/lib/apt/lists/*

COPY Scripts/kag-server /usr/local/bin/kag-server
RUN chmod +x /usr/local/bin/kag-server

COPY Hooks/ "${BASE_HOOKS}/"

# 50301/udp: game (KAG_PORT). 50301/tcp: TCP RCON (same port, only with KAG_TCPR=true).
EXPOSE 50301/udp 50301/tcp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
