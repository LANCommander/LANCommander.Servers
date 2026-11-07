# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="No One Lives Forever Game Server" \
      org.opencontainers.image.description="Dedicated server for The Operative: No One Lives Forever (1.004 GOTY, with the NOLF Modernizer), running the retail Windows NolfServ under Wine" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="The Operative: No One Lives Forever" \
      app.lancommander.server.external-id.hq="4770b8dd-5af6-4079-a56c-1dc56bd979ae" \
      app.lancommander.server.external-id.igdb="897"

# ----------------------------
# Server settings
#   - The game files are not downloadable; put a No One Lives Forever install (NolfServ.exe,
#     NOLF.REZ ...) in /config/Server, or set NOLF_ARCHIVE_URL to a zip of one
#   - NolfServ.exe is a GUI app. -nowiz skips its setup wizard and reuses the settings in
#     NetHost.txt; the NOLF_* settings below are written into that file on every start (empty
#     settings are left alone)
#   - NOLF_GAME_TYPE is deathmatch or harm (H.A.R.M. vs. UNITY)
#   - NOLF_LEVELS is a comma-separated rotation for that game type; empty = every level of the
#     type in the loaded rez files. Unknown levels are dropped (an unknown first level hangs the
#     server)
#   - NOLF_FRAG_LIMIT / NOLF_SCORE_LIMIT / NOLF_TIME_LIMIT end a level; 0 turns that limit off
#   - NOLF_CUSTOM_REZ lists add-on rez files in Custom\ to load after the retail ones. The
#     default loads the NOLF Modernizer when it is there, so the server matches clients that use it
#   - The server needs a window, so it runs under Xvfb
# ----------------------------
ENV NOLF_ARCHIVE_URL="" \
    NOLF_SERVER_NAME="No One Lives Forever" \
    NOLF_GAME_TYPE="deathmatch" \
    NOLF_PORT="27888" \
    NOLF_MAX_PLAYERS="16" \
    NOLF_PASSWORD="" \
    NOLF_LEVELS="" \
    NOLF_FRAG_LIMIT="25" \
    NOLF_SCORE_LIMIT="50" \
    NOLF_TIME_LIMIT="15" \
    NOLF_SEND_BANDWIDTH="1000000" \
    NOLF_CUSTOM_REZ="MODERNIZER.REZ" \
    NOLF_RUN_SPEED="" \
    NOLF_RESPAWN_SCALE="" \
    NOLF_DEFAULT_WEAPON="" \
    NOLF_WEAPONS_STAY="" \
    NOLF_HIT_LOCATION="" \
    NOLF_AUDIO_TAUNTS="" \
    NOLF_FALL_DAMAGE="" \
    NOLF_ARMOR_HEALTH_BONUS="" \
    NOLF_INTEL_SCORE="" \
    NOLF_FRAG_SCORE="" \
    NOLF_FRIENDLY_FIRE="" \
    WINE_XVFB="true" \
    START_EXE="/usr/local/bin/nolf-server" \
    START_ARGS=""

COPY Scripts/nolf-server /usr/local/bin/nolf-server
RUN chmod +x /usr/local/bin/nolf-server

COPY Hooks/ "${BASE_HOOKS}/"

# 27888/udp: game, and GameSpy \status\ queries (NOLF_PORT)
EXPOSE 27888/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
