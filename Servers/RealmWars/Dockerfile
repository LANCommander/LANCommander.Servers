# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Realm Wars Game Server" \
      org.opencontainers.image.description="Dedicated server for Realm Wars (Torque Game Engine) running under Wine" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="Realm Wars" \
      app.lancommander.server.external-id.hq="107ec5cb-1c35-40d8-b636-2bafdf4a423c"

# ----------------------------
# Server settings
#   - The game files are not downloadable here; put a Realm Wars install (RealmWars.exe, common/,
#     rw/) in /config/Server, or set REALMWARS_ARCHIVE_URL to a zip of one
#   - Settings are applied from the generated lancommander/main.cs mod, which loads after
#     rw/server/prefs.cs
#   - The GarageGames master server is gone, so the server never registers with it; players find
#     it in the LAN list or join by IP
# ----------------------------
ENV REALMWARS_ARCHIVE_URL="" \
    REALMWARS_SERVER_NAME="Realm Wars Server" \
    REALMWARS_SERVER_INFO="A LANCommander Realm Wars server" \
    REALMWARS_MAX_PLAYERS="16" \
    REALMWARS_PASSWORD="" \
    REALMWARS_ADMIN_PASSWORD="" \
    REALMWARS_TIME_LIMIT="20" \
    REALMWARS_PORT="28000" \
    REALMWARS_MISSION="rw/data/missions/newlands.mis" \
    REALMWARS_EXTRA_ARGS="" \
    START_EXE="/usr/local/bin/realmwars-server" \
    START_ARGS=""

COPY Scripts/realmwars-server /usr/local/bin/realmwars-server
RUN chmod +x /usr/local/bin/realmwars-server

COPY Hooks/ "${BASE_HOOKS}/"

# 28000/udp: game and LAN discovery (REALMWARS_PORT; the game tries the next port if it is taken)
EXPOSE 28000/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
