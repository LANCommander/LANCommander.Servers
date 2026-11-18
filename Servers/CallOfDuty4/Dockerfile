# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/base:local
ARG BASE_IMAGE=lancommander/base:latest
FROM ${BASE_IMAGE}

# Log files LANCommander shows as consoles under the server's Monitor
LABEL app.lancommander.server.log.games-log="/config/Overlay/main/games_mp.log"

# ----------------------------
# Server settings
#   - COD4_SERVER_URL is the official 1.7 Linux dedicated server (cod4_lnxded), mirrored as this
#     repo's server-1.7 release. It is unpacked into /config/Server on first start, next to the
#     retail game data you supply, and verified against COD4_SERVER_SHA256 (empty = no check)
#   - The COD4_* settings below are written into <COD4_FS_GAME or main>/lancommander.cfg on
#     every start (empty settings are left out); the server execs it before map_rotate
#   - HTTP_FILESERVER_* serve mod .iwd/.ff files from Merged/ on port 80 for sv_wwwDownload
#     (COD4_WWW_BASE_URL); off by default
# ----------------------------
ENV COD4_SERVER_URL="https://github.com/LANCommander/LANCommander.Servers.CallOfDuty4/releases/download/server-1.7/cod4-lnxded-1.7.tar.xz" \
    COD4_SERVER_SHA256="735d757534241126ff70166f6302141e09b20598a5820e85633b6db55a17892e" \
    COD4_PORT="28960" \
    COD4_LAN="true" \
    COD4_FS_GAME="" \
    COD4_SERVER_NAME="Call of Duty 4 Server" \
    COD4_MOTD="" \
    COD4_MAX_PLAYERS="24" \
    COD4_PASSWORD="" \
    COD4_RCON_PASSWORD="" \
    COD4_GAME_TYPE="war" \
    COD4_MAPS="mp_crash mp_backlot mp_bloc mp_bog mp_broadcast mp_carentan mp_cargoship mp_citystreets mp_convoy mp_countdown mp_crash_snow mp_creek mp_crossfire mp_farm mp_killhouse mp_overgrown mp_pipeline mp_shipment mp_showdown mp_strike mp_vacant" \
    COD4_TIME_LIMIT="" \
    COD4_SCORE_LIMIT="" \
    COD4_HARDCORE="" \
    COD4_FRIENDLY_FIRE="" \
    COD4_KILLCAM="" \
    COD4_ALLOW_VOTE="" \
    COD4_PUNKBUSTER="0" \
    COD4_ALLOW_DOWNLOAD="1" \
    COD4_WWW_BASE_URL="" \
    HTTP_FILESERVER_ENABLED="false" \
    HTTP_FILESERVER_WEB_ROOT="/config/Merged" \
    HTTP_FILESERVER_FILE_PATTERN="^/.*\.(iwd|ff)$" \
    START_EXE="/usr/local/bin/cod4-server" \
    START_ARGS=""

# cod4_lnxded is a 32-bit binary (libstdc++.so.6, libgcc_s.so.1)
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        xz-utils \
        bzip2 \
        unzip \
        libc6:i386 \
        libgcc-s1:i386 \
        libstdc++6:i386 && \
    rm -rf /var/lib/apt/lists/*

COPY Scripts/cod4-server /usr/local/bin/cod4-server
RUN chmod +x /usr/local/bin/cod4-server

COPY Hooks/ "${BASE_HOOKS}/"

# 28960/udp: game, queries, RCON and LAN browser (COD4_PORT)
# 80/tcp:    HTTP fast download (HTTP_FILESERVER_ENABLED=true only)
EXPOSE 28960/udp 80/tcp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
