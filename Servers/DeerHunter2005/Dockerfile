# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Deer Hunter 2005 Dedicated Server" \
      org.opencontainers.image.description="Dedicated server for Deer Hunter 2005"

# Log files LANCommander shows as consoles under the server's Monitor
LABEL app.lancommander.server.log.server-log="/config/Overlay/Game/Game.LOG" \
      app.lancommander.server.log.patch-log="/config/Overlay/dh2005patch.log"

# Native DirectPlay comes from the DirectX February 2010 redist. Wine's builtin dpnet cannot host
# (IDirectPlay8Server::Host is a stub), so the redist is cached in the image and installed into the
# prefix with `winetricks directplay` on first start. Microsoft's own URL is gone; this is the mirror
# winetricks pins, checked against the same sha256.
ARG DIRECTX_REDIST_URL="https://files.holarse-linuxgaming.de/mirrors/microsoft/directx_feb2010_redist.exe"
ARG DIRECTX_REDIST_SHA256="f6d191e89a963d7cca34f169d30f49eab99c1ed3bb92da73ec43617caaa1e93f"

# ----------------------------
# Server settings
#   - The game files are not downloadable; put a Deer Hunter 2005 v1.2 install in /config/Server,
#     or set DH2005_ARCHIVE_URL to a zip of one
#   - Each DH2005_* setting maps to a -Name:value argument; empty settings are left out
# ----------------------------
ENV W_CACHE=/opt/winetricks-cache \
    DH2005_ARCHIVE_URL="" \
    DH2005_SERVER_NAME="Deer Hunter 2005 Server" \
    DH2005_MESSAGE_OF_THE_DAY="Welcome! Have fun!" \
    DH2005_PASSWORD="" \
    DH2005_GAME_TYPE="BEST_TROPHY" \
    DH2005_MAX_PLAYERS="16" \
    DH2005_LOCATION="" \
    DH2005_SEASON="" \
    DH2005_DIFFICULTY="" \
    DH2005_RANDOM_MAPS="TRUE" \
    DH2005_TIME_LIMIT="20" \
    DH2005_SHOW_HUNTERS_IN_GPS="TRUE" \
    DH2005_PUBLISH_IN_GAMESPY="FALSE" \
    DH2005_AUTO_KICK_PEOPLE_SHOOTERS="TRUE" \
    DH2005_ALLOW_VOTING="TRUE" \
    DH2005_VIEW_DISTANCE="" \
    DH2005_TREE_DENSITY="" \
    DH2005_WEATHER="" \
    DH2005_TIME_MULTIPLIER="" \
    DH2005_FIRST_DAY_HOUR="" \
    DH2005_DISABLED_ITEMS="" \
    DH2005_EXTRA_ARGS="" \
    START_EXE="/usr/local/bin/dh2005-server" \
    START_ARGS=""

# ----------------------------
# Modern patch (https://github.com/LANCommander/LANCommander.Patches.DeerHunter2005)
#   - DH2005_PATCH_ENABLED: install dinput8.dll and a generated dh2005patch.ini next to DH2005.exe
#   - The patch raises the player cap to DH2005_MAX_PLAYERS (up to 64) and sets the animals below
#   - Empty animal settings keep the patch's defaults
# ----------------------------
ENV DH2005_PATCH_ENABLED="true" \
    DH2005_POPULATION="" \
    DH2005_POPULATION_BY_SPECIES="" \
    DH2005_NEARBY_ANIMALS="" \
    DH2005_NEARBY_SAME_SPECIES="" \
    DH2005_NEARBY_BY_SPECIES="" \
    DH2005_ALLOW_RESPAWN_BY_SPECIES="" \
    DH2005_RESPAWN_DISTANCE="" \
    DH2005_RESPAWN_DISTANCE_BY_SPECIES=""

# ----------------------------
# LANCommander match statistics (reported by the patch)
#   - MATCH_STATS_ENABLED: auto (on when MATCH_STATS_SERVER_URL and MATCH_STATS_TOKEN are set),
#     true or false
#   - The token stays in the environment: the ini reads %MATCH_STATS_TOKEN%
# ----------------------------
ENV MATCH_STATS_ENABLED="auto" \
    MATCH_STATS_SERVER_URL="" \
    MATCH_STATS_TOKEN="" \
    MATCH_STATS_GAME_ID="" \
    MATCH_STATS_SERVER_ID="" \
    MATCH_STATS_REPORTER_NAME="" \
    MATCH_STATS_RECORD_CHAT=""

ARG DH2005_PATCH_VERSION=1.1.1
ARG DH2005_PATCH_SHA256=5682385822a94ce5182121f93e885cb22fc6920d33e701731387eb3658c7a041

RUN set -eux; \
    curl -fsSL --retry 8 --retry-delay 15 --retry-all-errors -o /tmp/dh2005patch.zip \
      "https://github.com/LANCommander/LANCommander.Patches.DeerHunter2005/releases/download/v${DH2005_PATCH_VERSION}/dh2005patch-v${DH2005_PATCH_VERSION}-dinput8.zip"; \
    echo "${DH2005_PATCH_SHA256}  /tmp/dh2005patch.zip" | sha256sum -c -; \
    mkdir -p /opt/dh2005patch; \
    unzip -q -j /tmp/dh2005patch.zip dinput8.dll dh2005patch.ini -d /opt/dh2005patch; \
    rm /tmp/dh2005patch.zip

RUN set -eux; \
    mkdir -p "${W_CACHE}/directx9"; \
    curl -fsSL --retry 3 "${DIRECTX_REDIST_URL}" -o "${W_CACHE}/directx9/directx_feb2010_redist.exe"; \
    echo "${DIRECTX_REDIST_SHA256}  ${W_CACHE}/directx9/directx_feb2010_redist.exe" | sha256sum -c -

COPY Scripts/dh2005-server /usr/local/bin/dh2005-server
RUN chmod +x /usr/local/bin/dh2005-server

COPY Hooks/ "${BASE_HOOKS}/"

# 23459/udp: game (DirectPlay host). 6073/udp: DirectPlay session enumeration (dpnsvr).
EXPOSE 23459/udp 6073/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
