# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/base:local
ARG BASE_IMAGE=lancommander/base:latest

# ----------------------------
# Build the Hammer of Thyrion (uHexen2) dedicated server, h2ded, from source. Hammer of Thyrion
# publishes Linux binaries only as old 32-bit tarballs.
#   - UHEXEN2_VERSION is pinned to the release LANCommander's Hexen II client runs (1.5.9),
#     so client and server speak the same protocol and game code
#   - UHEXEN2_SHA256 verifies the source tarball; clear it when changing UHEXEN2_VERSION
#   - Built without user directories (~/.hexen2), so everything the server writes (configs,
#     saves, logs) lands next to the game data in Merged/, which is Overlay/
#   - Patches/h2ded-stdin-eof.patch: h2ded polls stdin for console commands, and with stdin at
#     EOF (/dev/null under docker) it reads garbage every frame and spams "Console input too
#     long!". The patch stops polling once stdin hits EOF
# ----------------------------
FROM debian:bookworm-slim AS build

ARG UHEXEN2_VERSION=1.5.9
ARG UHEXEN2_SHA256=67494fe8acb7388c5b07a81a94b50ef8bb5aed79c5e853cf5ef76448b49699e4

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        make \
        gcc \
        libc6-dev \
        patch && \
    rm -rf /var/lib/apt/lists/*

COPY Patches/ /tmp/patches/

RUN curl -fsSL --retry 3 -o /tmp/uhexen2.tar.gz \
        "https://github.com/sezero/uhexen2/archive/refs/tags/uhexen2-${UHEXEN2_VERSION}.tar.gz" && \
    if [ -n "${UHEXEN2_SHA256}" ]; then echo "${UHEXEN2_SHA256}  /tmp/uhexen2.tar.gz" | sha256sum -c -; fi && \
    mkdir -p /src && tar -xzf /tmp/uhexen2.tar.gz -C /src --strip-components=1 && \
    for p in /tmp/patches/*.patch; do patch -d /src -p1 --forward < "$p"; done && \
    sed -i -E 's/^#define[[:space:]]+DO_USERDIRS[[:space:]]+1$/#define\tDO_USERDIRS\t0/' /src/engine/h2shared/h2config.h && \
    grep -Eq '^#define[[:space:]]+DO_USERDIRS[[:space:]]+0$' /src/engine/h2shared/h2config.h && \
    make -C /src/engine/hexen2/server -j"$(nproc)" && \
    mkdir -p /opt/uhexen2 && \
    cp /src/engine/hexen2/server/h2ded /opt/uhexen2/ && \
    strip /opt/uhexen2/h2ded && \
    echo "${UHEXEN2_VERSION}" > /opt/uhexen2/VERSION

# ----------------------------
# Runtime
# ----------------------------
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Hexen II Game Server" \
      org.opencontainers.image.description="Dedicated server for Hexen II, running the Hammer of Thyrion (uHexen2) h2ded with your game data" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="Hexen II" \
      app.lancommander.server.external-id.hq="e8016013-53bc-4aec-8e1d-a8051e279327" \
      app.lancommander.server.external-id.igdb="6637" \
      app.lancommander.server.external-id.steam="9060" \
      app.lancommander.server.external-id.gog="1798886022"

# ----------------------------
# Server settings
#   - Hexen II needs the game data: data1/pak0.pak and data1/pak1.pak (patched to 1.11) in
#     /config/Server. The h2ded binary is in /opt/uhexen2
#   - h2ded execs server.cfg on its own at startup. The HEXEN2_* settings are written into
#     <HEXEN2_GAME or data1>/lancommander.cfg on every start, which the server execs after
#     server.cfg and before +map. Empty settings are left out
# ----------------------------
ENV HEXEN2_GAME="" \
    HEXEN2_PORTALS="" \
    HEXEN2_PORT="26900" \
    HEXEN2_MAX_PLAYERS="16" \
    HEXEN2_PROTOCOL="" \
    HEXEN2_SERVER_NAME="Hexen II Server" \
    HEXEN2_MAP="ravdm1" \
    HEXEN2_DEATHMATCH="1" \
    HEXEN2_COOP="0" \
    HEXEN2_TEAMPLAY="0" \
    HEXEN2_FRAG_LIMIT="20" \
    HEXEN2_TIME_LIMIT="15" \
    HEXEN2_SKILL="1" \
    HEXEN2_RANDOM_CLASS="" \
    HEXEN2_SAME_LEVEL="" \
    HEXEN2_NO_EXIT="" \
    START_EXE="/usr/local/bin/hexen2-server" \
    START_ARGS=""

COPY --from=build /opt/uhexen2/ /opt/uhexen2/

COPY Scripts/hexen2-server /usr/local/bin/hexen2-server
RUN chmod +x /usr/local/bin/hexen2-server

COPY Hooks/ "${BASE_HOOKS}/"

# 26900/udp: game, server info queries and LAN browser (HEXEN2_PORT)
EXPOSE 26900/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
