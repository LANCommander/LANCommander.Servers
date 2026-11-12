# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/base:local
ARG BASE_IMAGE=lancommander/base:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Atomic Bomberman Game Server" \
      org.opencontainers.image.description="Dedicated server for Atomic Bomberman (FPC Atomic 0.14002, the open-source remake, native Linux build)" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="Atomic Bomberman" \
      app.lancommander.server.external-id.hq="8b663561-059e-42b3-8997-f9a85b828628" \
      app.lancommander.server.external-id.igdb="18153"

# Log files LANCommander shows as consoles under the server's Monitor
LABEL app.lancommander.server.log.server-log="/config/Overlay/.config/fpc_atomic/log/server.log"

# ----------------------------
# Server settings
#   - The server is FPC Atomic's atomic_server (https://github.com/PascalCorpsman/fpc_atomic), the
#     open-source Atomic Bomberman remake. Clients must run the same FPC Atomic release
#     (ATOMIC_VERSION); other releases use a different network protocol and can't join.
#   - The release files are baked into ATOMIC_DIST below and copied into /config/Server on first
#     start (and again whenever ATOMIC_VERSION changes). The server only needs the map info files,
#     not the original game's data.
#   - ATOMIC_AI picks the computer player AI: empty = the original (libai.so), ai_smart = the smart AI
# ----------------------------
ENV ATOMIC_VERSION="0.14002" \
    ATOMIC_DIST="/opt/fpc-atomic" \
    ATOMIC_PORT="5521" \
    ATOMIC_TIMEOUT="0" \
    ATOMIC_AI="" \
    ATOMIC_LOG_LEVEL="" \
    START_EXE="/usr/local/bin/atomic-server" \
    START_ARGS=""

# Release binaries (x86-64, linked only against libc), checked against the release's sha256 digests
ADD --chmod=755 --checksum=sha256:1b179e19e1414e1a1d014dd7765411c5e051761217df3ac10bdd863dc8f002e3 \
    https://github.com/PascalCorpsman/fpc_atomic/releases/download/${ATOMIC_VERSION}/atomic_server ${ATOMIC_DIST}/atomic_server
ADD --chmod=644 --checksum=sha256:8988fbfcde072f617907b1b681f0238b6c3d0322ece1c71679e02082c9edda6d \
    https://github.com/PascalCorpsman/fpc_atomic/releases/download/${ATOMIC_VERSION}/libai.so ${ATOMIC_DIST}/libai.so
ADD --chmod=644 --checksum=sha256:6e4737dba229af5b92d380d4fccbaad6a21d1d50c1397aeae051db71c874599b \
    https://github.com/PascalCorpsman/fpc_atomic/releases/download/${ATOMIC_VERSION}/libai_smart.so ${ATOMIC_DIST}/libai_smart.so

# Map definitions (name and mechanics) from the release tag; the server needs no map graphics or sounds
ADD --chmod=644 --checksum=sha256:c8bd7e2574a7a635128769fdefa405cff6eb40b8800a59702042c2cd11b3e5bf \
    https://raw.githubusercontent.com/PascalCorpsman/fpc_atomic/${ATOMIC_VERSION}/data/maps/Field00/info.txt ${ATOMIC_DIST}/data/maps/Field00/info.txt
ADD --chmod=644 --checksum=sha256:0d3500d8d802bf07cf7979c9d5b1538a9634ed41a499cde2e4eb388e1214433a \
    https://raw.githubusercontent.com/PascalCorpsman/fpc_atomic/${ATOMIC_VERSION}/data/maps/Field01/info.txt ${ATOMIC_DIST}/data/maps/Field01/info.txt
ADD --chmod=644 --checksum=sha256:1cd2be999b1cbbab195714ce76aa3a86face9a7a2afa28e9b28d3abb786e9013 \
    https://raw.githubusercontent.com/PascalCorpsman/fpc_atomic/${ATOMIC_VERSION}/data/maps/Field02/info.txt ${ATOMIC_DIST}/data/maps/Field02/info.txt
ADD --chmod=644 --checksum=sha256:fbad21a5197eb9aed9488bdf585621a937987386d0ca7c4eea9a5751014527aa \
    https://raw.githubusercontent.com/PascalCorpsman/fpc_atomic/${ATOMIC_VERSION}/data/maps/Field03/info.txt ${ATOMIC_DIST}/data/maps/Field03/info.txt
ADD --chmod=644 --checksum=sha256:8d55e57506daae48c21e64c94a5833978c2e882194362e1aafdafc74a54391eb \
    https://raw.githubusercontent.com/PascalCorpsman/fpc_atomic/${ATOMIC_VERSION}/data/maps/Field04/info.txt ${ATOMIC_DIST}/data/maps/Field04/info.txt
ADD --chmod=644 --checksum=sha256:418f8cb59ae8ecbcbbb238331f1dbbb3750af6d399f1e61ab66a5845bec46b28 \
    https://raw.githubusercontent.com/PascalCorpsman/fpc_atomic/${ATOMIC_VERSION}/data/maps/Field05/info.txt ${ATOMIC_DIST}/data/maps/Field05/info.txt
ADD --chmod=644 --checksum=sha256:dad9146756881cbd55b49e0f4efd2262d647d449b8f95108e12196b6f5a25a95 \
    https://raw.githubusercontent.com/PascalCorpsman/fpc_atomic/${ATOMIC_VERSION}/data/maps/Field06/info.txt ${ATOMIC_DIST}/data/maps/Field06/info.txt
ADD --chmod=644 --checksum=sha256:20088db4d92605d31b84df5d186150940e0e56df1dd5eb28468fd2ee298be278 \
    https://raw.githubusercontent.com/PascalCorpsman/fpc_atomic/${ATOMIC_VERSION}/data/maps/Field07/info.txt ${ATOMIC_DIST}/data/maps/Field07/info.txt
ADD --chmod=644 --checksum=sha256:596f7ccea30c7819daabaeeb31ea5e98368c050099d4fbc2fa6a211174885d83 \
    https://raw.githubusercontent.com/PascalCorpsman/fpc_atomic/${ATOMIC_VERSION}/data/maps/Field08/info.txt ${ATOMIC_DIST}/data/maps/Field08/info.txt
ADD --chmod=644 --checksum=sha256:495ce121cd8a54abec705c3166187cbec4c2b3cc3b86ba2d97d6150392796296 \
    https://raw.githubusercontent.com/PascalCorpsman/fpc_atomic/${ATOMIC_VERSION}/data/maps/Field09/info.txt ${ATOMIC_DIST}/data/maps/Field09/info.txt
ADD --chmod=644 --checksum=sha256:0ef404f63f171c53bdbff2ff3268bbdb70d848bd9df79fbca06b998e1f5ff699 \
    https://raw.githubusercontent.com/PascalCorpsman/fpc_atomic/${ATOMIC_VERSION}/data/maps/Field10/info.txt ${ATOMIC_DIST}/data/maps/Field10/info.txt

COPY Scripts/atomic-server /usr/local/bin/atomic-server

# ADD --chmod also applies to the directories it creates (data/maps/FieldXX would be 644), so make
# the directories searchable again
RUN chmod +x /usr/local/bin/atomic-server && \
    chmod -R a+rX "${ATOMIC_DIST}"

COPY Hooks/ "${BASE_HOOKS}/"

# 5521/tcp: game connections (ATOMIC_PORT). 8005/udp: LAN game discovery (fixed in the game; clients
# broadcast to it to find open servers).
EXPOSE 5521/tcp 8005/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
