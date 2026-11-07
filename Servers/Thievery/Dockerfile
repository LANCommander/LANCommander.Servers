# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Thievery Game Server" \
      org.opencontainers.image.description="Dedicated server for Thievery, the Unreal Tournament mod, running the Windows UCC server under Wine" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="Thievery" \
      app.lancommander.server.external-id.hq="0eaca3b5-72fd-4a60-8005-1aa18ce3a460"

# ----------------------------
# Server settings
#   - Thievery is a mod for Unreal Tournament (1999, patch 436). Put a UT install with Thievery
#     1.7.1 on top of it in /config/Server, or set THIEVERY_UT_ARCHIVE_URL and
#     THIEVERY_ARCHIVE_URL to zips of each (file:// URLs are read in place)
#   - Thievery ships Windows-only native DLLs, so it runs the Windows UCC.exe under Wine
#   - THIEVERY_INI is created from System/ThAux.ini on first start; the server settings below are
#     written into it on every start, the gameplay settings and the map rotation into
#     System/ThieveryMod.ini (empty settings are left alone)
#   - THIEVERY_GAME_TYPE takes teams, thiefmatch, coop or a game class
#   - UCC is a console program and needs no X display, so Xvfb is off
# ----------------------------
ENV THIEVERY_UT_ARCHIVE_URL="" \
    THIEVERY_ARCHIVE_URL="" \
    THIEVERY_MAP="TH-Theatre" \
    THIEVERY_GAME_TYPE="teams" \
    THIEVERY_MAPS="" \
    THIEVERY_PORT="7777" \
    THIEVERY_INI="Server.ini" \
    THIEVERY_USER_INI="ThieveryUser.ini" \
    THIEVERY_SERVER_NAME="Thievery Server" \
    THIEVERY_SHORT_NAME="Thievery Server" \
    THIEVERY_ADMIN_NAME="" \
    THIEVERY_ADMIN_EMAIL="" \
    THIEVERY_MOTD="" \
    THIEVERY_MAX_PLAYERS="16" \
    THIEVERY_MAX_SPECTATORS="" \
    THIEVERY_GAME_PASSWORD="" \
    THIEVERY_ADMIN_PASSWORD="" \
    THIEVERY_TIME_LIMIT="" \
    THIEVERY_BALANCE_TEAMS="" \
    THIEVERY_FRIENDLY_FIRE_SCALE="" \
    THIEVERY_GUARD_START_MONEY="" \
    THIEVERY_THIEVES_START_MONEY="" \
    THIEVERY_PREGAME_WAIT="" \
    THIEVERY_AI_SKILL="" \
    THIEVERY_MASTER_SERVER_UPLINK="false" \
    THIEVERY_URL_OPTIONS="" \
    WINE_XVFB="false" \
    START_EXE="/usr/local/bin/thievery-server" \
    START_ARGS=""

COPY Scripts/thievery-server /usr/local/bin/thievery-server
RUN chmod +x /usr/local/bin/thievery-server

COPY Hooks/ "${BASE_HOOKS}/"

# 7777/udp: game. 7778/udp: GameSpy server query (game port + 1). 8777/udp: LAN browser beacon
# (UdpBeacon answers REPORTQUERY broadcasts there).
EXPOSE 7777/udp 7778/udp 8777/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
