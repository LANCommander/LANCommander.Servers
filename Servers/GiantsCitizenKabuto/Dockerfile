# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Giants: Citizen Kabuto Dedicated Server" \
      org.opencontainers.image.description="Dedicated server for Giants: Citizen Kabuto 1.5, running GiantsDedicated.exe under Wine" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="Giants: Citizen Kabuto" \
      app.lancommander.server.external-id.hq="2095a29d-c79b-460b-93ad-a24ddba3c97d" \
      app.lancommander.server.external-id.igdb="34" \
      app.lancommander.server.external-id.steam="557750" \
      app.lancommander.server.external-id.gog="1207658650"

# Log files LANCommander shows as consoles under the server's Monitor
LABEL app.lancommander.server.log.server-log="/config/wineprefix/drive_c/users/lancommander/AppData/Local/Giants/Giants.log" \
      app.lancommander.server.log.chat="/config/Overlay/chatlog.txt"

# Native DirectPlay comes from the DirectX February 2010 redist. Wine's builtin dpnet cannot host
# (IDirectPlay8Server::Host returns E_NOTIMPL, logged by Giants as "Cannot host a multiplayer game
# (Code 80004001)"), so the redist is cached in the image and installed into the prefix with
# `winetricks directplay` on first start. Microsoft's own URL is gone; this is the mirror winetricks
# pins, checked against the same sha256.
ARG DIRECTX_REDIST_URL="https://files.holarse-linuxgaming.de/mirrors/microsoft/directx_feb2010_redist.exe"
ARG DIRECTX_REDIST_SHA256="f6d191e89a963d7cca34f169d30f49eab99c1ed3bb92da73ec43617caaa1e93f"

# ----------------------------
# Server settings
#   - The game files are not downloadable; put a Giants 1.5 install in /config/Server, or set
#     GIANTS_ARCHIVE_URL to a zip of one
#   - The GIANTS_* settings are written to Bin/<GIANTS_GDF_NAME>.gdf on every start
#   - GIANTS_ROTATION: semicolon-separated "World, GameType, Teams[, setting=value ...]" entries
#   - The other per-game settings (time limit, scores, ...) are the defaults for every entry
# ----------------------------
ENV W_CACHE=/opt/winetricks-cache \
    GIANTS_ARCHIVE_URL="" \
    GIANTS_GDF_NAME="lancommander" \
    GIANTS_SERVER_NAME="Giants Server" \
    GIANTS_MOTD="" \
    GIANTS_PORT="19711" \
    GIANTS_MAX_PLAYERS="20" \
    GIANTS_NO_VOTING="false" \
    GIANTS_MASTER_SERVER="false" \
    GIANTS_FRAME_LIMIT="30" \
    GIANTS_ROTATION="m_3way_l1, DM, MvR; m_mecc_desertsnakes, DM, MvM; m_reaper_l1, DM, RvR; m_3way_sunsetbay, DMCap, MvR" \
    GIANTS_TIME_LIMIT="20" \
    GIANTS_POINTS_PER_KILL="1" \
    GIANTS_POINTS_PER_CAPTURE="5" \
    GIANTS_PLAYER_SCORE_LIMIT="0" \
    GIANTS_TEAM_SCORE_LIMIT="0" \
    GIANTS_DETENTE="0" \
    GIANTS_FIRST_BASE_DESTROYED="false" \
    GIANTS_DAMAGE_TEAMMATES="false" \
    GIANTS_NO_VIMPS="false" \
    GIANTS_MAX_SMARTIES="15" \
    GIANTS_VIMP_MEAT_ENERGY="easy" \
    GIANTS_MECC_WEAPONS_UNAVAILABLE="0x400" \
    GIANTS_REAPER_WEAPONS_UNAVAILABLE="0x400" \
    GIANTS_EXTRA_ARGS="" \
    START_EXE="/usr/local/bin/giants-server" \
    START_ARGS=""

RUN set -eux; \
    mkdir -p "${W_CACHE}/directx9"; \
    curl -fsSL --retry 3 "${DIRECTX_REDIST_URL}" -o "${W_CACHE}/directx9/directx_feb2010_redist.exe"; \
    echo "${DIRECTX_REDIST_SHA256}  ${W_CACHE}/directx9/directx_feb2010_redist.exe" | sha256sum -c -

COPY Scripts/giants-server /usr/local/bin/giants-server
RUN chmod +x /usr/local/bin/giants-server

COPY Hooks/ "${BASE_HOOKS}/"

# 19711/udp: game (DirectPlay 8 host, GIANTS_PORT); it also answers DirectPlay session enumeration.
EXPOSE 19711/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
