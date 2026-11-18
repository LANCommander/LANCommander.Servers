# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/base:local
ARG BASE_IMAGE=lancommander/base:latest

# ----------------------------
# Build the Ironwail engine from source. Ironwail publishes Windows binaries only.
#   - IRONWAIL_VERSION=latest builds the newest Ironwail release; set a release tag (e.g.
#     v0.8.2) to pin one. Ironwail speaks the standard NetQuake protocols (15, FitzQuake 666,
#     RMQ 999), so clients on other Ironwail/QuakeSpasm versions can join
#   - IRONWAIL_SHA256, when set, verifies the source tarball
#   - Built without user directories, curl and music codecs, none of which a dedicated server uses
# ----------------------------
FROM debian:bookworm-slim AS build

ARG IRONWAIL_VERSION=latest
ARG IRONWAIL_SHA256=

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        make \
        gcc \
        libc6-dev \
        pkg-config \
        libsdl2-dev \
        libgl-dev && \
    rm -rf /var/lib/apt/lists/*

# Changes whenever Ironwail publishes a release, so a cached build doesn't keep an old "latest"
ADD https://api.github.com/repos/andrei-drexler/ironwail/releases/latest /tmp/ironwail-latest.json

RUN version="${IRONWAIL_VERSION}" && \
    if [ "$version" = latest ]; then \
        version="$(grep -o '"tag_name": *"[^"]*"' /tmp/ironwail-latest.json | head -n 1 | cut -d '"' -f 4)"; \
        [ -n "$version" ] || { echo "Could not read the latest Ironwail release" >&2; exit 1; }; \
    fi && \
    echo "Building Ironwail $version" && \
    curl -fsSL --retry 3 -o /tmp/ironwail.tar.gz "https://github.com/andrei-drexler/ironwail/archive/refs/tags/${version}.tar.gz" && \
    if [ -n "${IRONWAIL_SHA256}" ]; then echo "${IRONWAIL_SHA256}  /tmp/ironwail.tar.gz" | sha256sum -c -; fi && \
    mkdir -p /src && tar -xzf /tmp/ironwail.tar.gz -C /src --strip-components=1 && \
    make -C /src/Quake -j"$(nproc)" \
        DO_USERDIRS=0 \
        USE_CURL=0 \
        USE_CODEC_MP3=0 \
        USE_CODEC_VORBIS=0 && \
    mkdir -p /opt/ironwail && \
    cp /src/Quake/ironwail /src/Quake/ironwail.pak /opt/ironwail/ && \
    echo "$version" > /opt/ironwail/VERSION

# ----------------------------
# Runtime
# ----------------------------
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Quake Dedicated Server" \
      org.opencontainers.image.description="Dedicated server for Quake"

# ----------------------------
# Server settings
#   - Quake needs the game data: id1/pak0.pak and id1/pak1.pak (registered) in /config/Server.
#     The Ironwail binary is in /opt/ironwail
#   - The QUAKE_* settings are written into <QUAKE_GAME or id1>/lancommander.cfg on every start,
#     which the server execs before +map. Empty settings are left out
# ----------------------------
ENV QUAKE_GAME="" \
    QUAKE_PORT="26000" \
    QUAKE_MAX_PLAYERS="16" \
    QUAKE_SERVER_NAME="Quake Server" \
    QUAKE_MAP="dm1" \
    QUAKE_DEATHMATCH="1" \
    QUAKE_COOP="0" \
    QUAKE_TEAMPLAY="0" \
    QUAKE_FRAG_LIMIT="20" \
    QUAKE_TIME_LIMIT="15" \
    QUAKE_SKILL="1" \
    QUAKE_SAME_LEVEL="" \
    QUAKE_NO_EXIT="" \
    QUAKE_PROTOCOL="" \
    START_EXE="/usr/local/bin/quake-server" \
    START_ARGS=""

# Ironwail links SDL2 (timers only on a dedicated server) and libGL, which is never initialized
RUN apt-get update && apt-get install -y --no-install-recommends \
        libsdl2-2.0-0 \
        libgl1 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /opt/ironwail/ /opt/ironwail/

COPY Scripts/quake-server /usr/local/bin/quake-server
RUN chmod +x /usr/local/bin/quake-server

COPY Hooks/ "${BASE_HOOKS}/"

# 26000/udp: game, server info queries and LAN browser (QUAKE_PORT)
EXPOSE 26000/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
