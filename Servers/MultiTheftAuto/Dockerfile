# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/base:local
ARG BASE_IMAGE=lancommander/base:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Multi Theft Auto Game Server" \
      org.opencontainers.image.description="Dedicated server for Multi Theft Auto: San Andreas 1.6 with the official resources and a LAN party mode/map vote rotation" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="Multi Theft Auto" \
      app.lancommander.server.external-id.hq="41138c7f-a5a7-4596-9654-5bdf6de36ae1" \
      app.lancommander.server.external-id.igdb="140059"

# Log files LANCommander shows as consoles under the server's Monitor
LABEL app.lancommander.server.log.server-log="/config/Overlay/mods/deathmatch/logs/server.log" \
      app.lancommander.server.log.debug-log="/config/Overlay/mods/deathmatch/logs/scripts.log"

# ----------------------------
# Server settings
#   - MTA_SERVER_URL is the Linux x64 server build (1.6.0 r24159, the build of the 1.6 Windows
#     installer released alongside it), MTA_BASECONFIG_URL the default mtaserver.conf, acl.xml and
#     vehiclecolors.conf, MTA_RESOURCES_URL the official resource pack (game modes, maps, admin).
#     They're installed into /config/Server on first start and again whenever a URL changes.
#     An empty *_SHA256 skips the check
#   - The MTA_* settings below are written into mods/deathmatch/mtaserver.conf (in Overlay/) on
#     every start; empty ones leave the file's value alone. MTA_CONFIG sets any other element
#   - MTA_PARTY_ROTATION installs the LAN party rotation as the mapcycler resource: a vote between
#     game modes and maps after each match, a few race maps in a row (see the README)
#   - MTA_RESOURCE_SETTINGS sets resource settings (mods/deathmatch/settings.xml)
# ----------------------------
ENV MTA_SERVER_URL="https://nightly.multitheftauto.com/multitheftauto_linux_x64-1.6.0-rc-24159.tar.gz" \
    MTA_SERVER_SHA256="8ee4bf07215e892e5c79492a8f5ea4fdde4c7afb0fb4435dcb28cc4aed4f9350" \
    MTA_BASECONFIG_URL="https://linux.multitheftauto.com/dl/baseconfig.tar.gz" \
    MTA_BASECONFIG_SHA256="161beb7823bc77df9952339e6e7048c61a426bd186ff6313e1e50b3b61804465" \
    MTA_RESOURCES_URL="https://mirror-cdn.multitheftauto.com/mtasa/resources/mtasa-resources-r1602.zip" \
    MTA_RESOURCES_SHA256="12cf1d374e07e95e242c8c0f361cae3cfd74dc8a2d95929da867456fae95fac4" \
    MTA_SERVER_NAME="Multi Theft Auto Server" \
    MTA_PORT="22003" \
    MTA_HTTP_PORT="22005" \
    MTA_MAX_PLAYERS="32" \
    MTA_PASSWORD="" \
    MTA_LAN="true" \
    MTA_FPS_LIMIT="60" \
    MTA_VOICE="false" \
    MTA_CONFIG="" \
    MTA_ADMIN_USER="admin" \
    MTA_ADMIN_PASSWORD="" \
    MTA_START_RESOURCES="" \
    MTA_PARTY_ROTATION="true" \
    MTA_PARTY_GAMEMODES="race,deathmatch,tdma,ctf,assault,stealth,briefcaserace,ctv,fallout,hay" \
    MTA_PARTY_START="race" \
    MTA_PARTY_RACE_MAPS="3" \
    MTA_PARTY_TIME_LIMIT="15" \
    MTA_PARTY_VOTE_OPTIONS="6" \
    MTA_RESOURCE_SETTINGS="" \
    START_EXE="/usr/local/bin/mta-server" \
    START_ARGS=""

# mta-server64 links libncursesw6 and zlib (dbconmy.so, the MySQL connector, also wants OpenSSL
# 1.1, which Debian 12 doesn't ship; it's only loaded by dbConnect("mysql", ...))
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        libncursesw6 \
        unzip \
        zlib1g && \
    rm -rf /var/lib/apt/lists/*

COPY Scripts/mta-server Scripts/mta-command /usr/local/bin/
RUN chmod +x /usr/local/bin/mta-server /usr/local/bin/mta-command

# Resources the configure hook copies into mods/deathmatch/resources
COPY Resources/ /opt/lancommander/mta-resources/

COPY Hooks/ "${BASE_HOOKS}/"

# 22003/udp: game (MTA_PORT)
# 22005/tcp: built-in HTTP server: client resource downloads and the web admin (MTA_HTTP_PORT)
# 22126/udp: server browser queries, MTA_PORT + 123
# 34219/udp: LAN server browser broadcasts
EXPOSE 22003/udp
EXPOSE 22005/tcp
EXPOSE 22126/udp
EXPOSE 34219/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
