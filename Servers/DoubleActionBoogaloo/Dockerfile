# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

# The Double Action Dedicated Server's game content ships only Windows server binaries
# (dab/bin/server.dll), so the server runs the Windows srcds.exe under Wine.

# ----------------------------
# Server settings
#   - STEAM_*: Double Action Dedicated Server, installed with SteamCMD (Windows depot, anonymous)
#   - DAB_*: server settings, passed as srcds arguments by dab-server
# ----------------------------
ENV STEAM_APP_ID="317800" \
    STEAM_APP_UPDATE="true" \
    STEAM_VALIDATE="false" \
    STEAM_USERNAME="anonymous" \
    STEAM_PASSWORD="" \
    STEAM_BRANCH="" \
    STEAM_BRANCH_PASSWORD="" \
    STEAM_INSTALL_ATTEMPTS="3" \
    DAB_PORT="27015" \
    DAB_MAP="da_cocaine" \
    DAB_MAX_PLAYERS="16" \
    DAB_HOSTNAME="Double Action: Boogaloo Server" \
    DAB_PASSWORD="" \
    DAB_RCON_PASSWORD="" \
    DAB_LAN="1" \
    DAB_SERVER_CFG="server.cfg" \
    DAB_EXTRA_ARGS="-insecure" \
    START_EXE="/usr/local/bin/dab-server" \
    START_ARGS=""

# ----------------------------
# SteamCMD (32-bit Linux client, installs the Windows depot)
# ----------------------------
RUN set -eux; \
    apt-get update; \
    apt-get install --no-install-recommends -y \
        lib32gcc-s1 \
        lib32stdc++6 \
        libc6-i386; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    \
    mkdir -p /opt/steamcmd; \
    curl -fsSL --retry 3 "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" \
      | tar -xz -C /opt/steamcmd; \
    chmod +x /opt/steamcmd/steamcmd.sh

COPY Scripts/dab-server /usr/local/bin/dab-server
RUN chmod +x /usr/local/bin/dab-server

COPY Hooks/ "${BASE_HOOKS}/"

# 27015/udp: game + server queries. 27015/tcp: RCON.
EXPOSE 27015/udp 27015/tcp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
