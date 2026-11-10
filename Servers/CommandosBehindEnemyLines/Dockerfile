# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Commandos: Behind Enemy Lines Game Server" \
      org.opencontainers.image.description="Multiplayer server for Commandos: Behind Enemy Lines (mpserver.exe) running under Wine" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="Commandos: Behind Enemy Lines" \
      app.lancommander.server.external-id.hq="133543ed-2526-49cf-8d0b-6eb54381c1ed" \
      app.lancommander.server.external-id.igdb="879" \
      app.lancommander.server.external-id.steam="6800"

# ----------------------------
# Server settings
#   - The game files are not downloadable. The server only needs mpserver.exe from the game
#     folder: put it in /config/Server, or set COMMANDOS_ARCHIVE_URL to a zip of the game (only
#     mpserver.exe is extracted)
#   - mpserver.exe is a console program with no options or config file. It listens on
#     4321/tcp and 4322/tcp; players create and join games from the client's multiplayer menu
#     and choose the mission and options there
#   - Its console only writes to a terminal, so the launcher runs it in a pseudo-terminal and
#     passes its output on to docker logs. It needs no display
# ----------------------------
ENV COMMANDOS_ARCHIVE_URL="" \
    WINE_XVFB="false" \
    START_EXE="/usr/local/bin/commandos-server" \
    START_ARGS=""

COPY Scripts/commandos-server /usr/local/bin/commandos-server
RUN chmod +x /usr/local/bin/commandos-server

COPY Hooks/ "${BASE_HOOKS}/"

# 4321/tcp, 4322/tcp: mpserver.exe (fixed, not configurable)
EXPOSE 4321/tcp 4322/tcp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
