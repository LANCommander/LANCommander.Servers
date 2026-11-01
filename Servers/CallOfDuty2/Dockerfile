# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/base:local
ARG BASE_IMAGE=lancommander/base:latest
FROM ${BASE_IMAGE}

# ----------------------------
# Server settings
#   - COD2_SERVER_URL is the official 1.3 Linux dedicated server (cod2_lnxded and the PunkBuster
#     server libraries), mirrored as this repo's server-1.3 release. It is unpacked into
#     /config/Server on first start, next to the retail game data you supply, and verified
#     against COD2_SERVER_SHA256 (empty = no check)
#   - The COD2_* settings below are written into <COD2_FS_GAME or main>/lancommander.cfg on
#     every start (empty settings are left out); the server execs it before map_rotate
#   - HTTP_FILESERVER_* serve .iwd files from Merged/ on port 80 for sv_wwwDownload
#     (COD2_WWW_BASE_URL); off by default
# ----------------------------
ENV COD2_SERVER_URL="https://github.com/LANCommander/LANCommander.Servers.CallOfDuty2/releases/download/server-1.3/cod2-lnxded-1.3.tar.xz" \
    COD2_SERVER_SHA256="6a6fe4a0494eeda7e4bddb77977fbf314e5bdf6be16b9b8c924378ab86d1952b" \
    COD2_PORT="28960" \
    COD2_LAN="true" \
    COD2_FS_GAME="" \
    COD2_SERVER_NAME="Call of Duty 2 Server" \
    COD2_MOTD="" \
    COD2_MAX_PLAYERS="20" \
    COD2_PASSWORD="" \
    COD2_RCON_PASSWORD="" \
    COD2_GAME_TYPE="tdm" \
    COD2_MAPS="mp_toujane mp_burgundy mp_dawnville mp_matmata mp_carentan mp_leningrad mp_brecourt mp_decoy mp_downtown mp_farmhouse mp_railyard mp_trainstation mp_breakout mp_harbor mp_rhine" \
    COD2_TIME_LIMIT="" \
    COD2_SCORE_LIMIT="" \
    COD2_FRIENDLY_FIRE="" \
    COD2_KILLCAM="" \
    COD2_ALLOW_VOTE="" \
    COD2_PUNKBUSTER="0" \
    COD2_ALLOW_DOWNLOAD="1" \
    COD2_WWW_BASE_URL="" \
    HTTP_FILESERVER_ENABLED="false" \
    HTTP_FILESERVER_WEB_ROOT="/config/Merged" \
    HTTP_FILESERVER_FILE_PATTERN="^/.*\.iwd$" \
    START_EXE="/usr/local/bin/cod2-server" \
    START_ARGS=""

# cod2_lnxded is a 32-bit binary built with gcc 3.3 (libstdc++.so.5)
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        xz-utils \
        unzip \
        libc6:i386 \
        libgcc-s1:i386 \
        libstdc++5:i386 && \
    rm -rf /var/lib/apt/lists/*

COPY Scripts/cod2-server /usr/local/bin/cod2-server
RUN chmod +x /usr/local/bin/cod2-server

COPY Hooks/ "${BASE_HOOKS}/"

# 28960/udp: game, queries, RCON and LAN browser (COD2_PORT)
# 80/tcp:    HTTP fast download (HTTP_FILESERVER_ENABLED=true only)
EXPOSE 28960/udp 80/tcp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
