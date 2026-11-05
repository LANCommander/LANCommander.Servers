# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Kiss: Psycho Circus - The Nightmare Child Game Server" \
      org.opencontainers.image.description="Dedicated server for Kiss: Psycho Circus - The Nightmare Child (v1.13), running under Wine" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="Kiss: Psycho Circus - The Nightmare Child" \
      app.lancommander.server.external-id.hq="1d63d88f-e9a5-42c1-ae91-4a41b4a24fe2" \
      app.lancommander.server.external-id.igdb="9096"

# ----------------------------
# Server settings
#   - The game files are not downloadable; put a Kiss: Psycho Circus 1.13 install in /config/Server,
#     or set KPC_ARCHIVE_URL to a zip of one
#   - KPC_CONFIG and MapLists/lancommander.txt are generated from the KPC_* settings on every start
#     (empty settings are left out, so the game's defaults apply)
#   - Dedicated.exe is a console program, so no Xvfb is needed. It reads commands from a real
#     console, so the launcher runs it on a pty and types "start" once it is ready.
# ----------------------------
ENV KPC_ARCHIVE_URL="" \
    KPC_CONFIG="lancommander.cfg" \
    KPC_PORT="42972" \
    KPC_GAMESPY_PORT="42973" \
    KPC_GAMESPY="true" \
    KPC_HOSTNAME="Kiss Psycho Circus Server" \
    KPC_LOCATION="" \
    KPC_MOTD="Welcome to Psycho Circus" \
    KPC_MAPS="PM01,PM02,PM03,PM04,PM05,PM06,PM07,PM08,PM09,PM10" \
    KPC_MAX_PLAYERS="16" \
    KPC_GAME_TYPE="deathmatch" \
    KPC_TEAMPLAY="0" \
    KPC_FRAG_LIMIT="25" \
    KPC_TIME_LIMIT="15" \
    KPC_SPAWN_TYPE="" \
    KPC_FRIENDLY_KILL="" \
    KPC_SUICIDE="" \
    KPC_KEEP_ITEMS="" \
    KPC_FOV_CHANGE="" \
    KPC_GIB_DETAIL="" \
    KPC_EXTRA_SETTINGS="" \
    KPC_IDLE_PATCH="true" \
    WINE_XVFB="false" \
    START_EXE="/usr/local/bin/kpc-server" \
    START_ARGS=""

COPY Scripts/kpc-server Scripts/kpc-console /usr/local/bin/
RUN chmod +x /usr/local/bin/kpc-server /usr/local/bin/kpc-console

COPY Hooks/ "${BASE_HOOKS}/"

# 42972/udp: game (KPC_PORT). 42973/udp: GameSpy query (KPC_GAMESPY_PORT).
EXPOSE 42972/udp 42973/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
