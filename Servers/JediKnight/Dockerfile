# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

# ----------------------------
# Server settings
#   - The game files are not downloadable; put an OpenJKDF2 install of Jedi Knight
#     (openjkdf2-64.exe next to Episode/ and Resource/) in /config/Server, or set JK_ARCHIVE_URL
#     to a zip of one. Clients must run the same OpenJKDF2 version as the server
#   - The launcher runs `openjkdf2-64.exe -headless -dedicatedServer -debug log -verbose <JK_VERBOSE>
#     [START_ARGS]` under Wine and Xvfb, and streams debug.log
#   - The JK_* settings below are written into registry.json on every start (empty settings are
#     left alone); the dedicated server reads its settings from that file only
# ----------------------------
ENV JK_ARCHIVE_URL="" \
    JK_EXE="openjkdf2-64.exe" \
    JK_PORT="27020" \
    JK_SERVER_NAME="Jedi Knight Server" \
    JK_PASSWORD="" \
    JK_EPISODE="JK1MP" \
    JK_MAP="m2.jkl" \
    JK_MAX_PLAYERS="8" \
    JK_MAX_RANK="8" \
    JK_SCORE_LIMIT="20" \
    JK_TIME_LIMIT="15" \
    JK_TEAMS="false" \
    JK_SINGLE_LEVEL="true" \
    JK_TICK_RATE="" \
    JK_VERBOSE="1" \
    WINE_XVFB="true" \
    START_EXE="/usr/local/bin/jediknight-server" \
    START_ARGS=""

COPY Scripts/jediknight-server /usr/local/bin/jediknight-server
RUN chmod +x /usr/local/bin/jediknight-server

COPY Hooks/ "${BASE_HOOKS}/"

# 27020/udp: game (JK_PORT), Valve GameNetworkingSockets
EXPOSE 27020/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
