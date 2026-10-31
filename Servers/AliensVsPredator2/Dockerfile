# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

# ----------------------------
# Server settings
#   - The game files are not downloadable; put an AvP2 1.0.9.6 install with the Master Server
#     Patch 2.4 dedicated server (AVP2Serv.exe, AVP2.REZ, ServerData\ ...) in /config/Server, or
#     set AVP2_ARCHIVE_URL to a zip of one
#   - AVP2Serv.exe is a GUI app. `-config <name>` loads ServerData\<name>.txt and hosts right away.
#     The configure hook creates that file from ServerData\unnamed.txt and writes the AVP2_*
#     settings below into it on every start (empty settings are left alone)
#   - AVP2_GAME_TYPE: deathmatch, teamdeathmatch, hunt, survivor, overrun, evac, ctf, domination
#     (or 1-8)
#   - AVP2_MAPS is a comma-separated rotation for that game type; bare names are looked up in
#     Worlds\Multi\DM (Evac\ for evac_*, Overrun\ for over_*). Empty uses the retail maps every
#     1.0.9.6 client has; "config" keeps the list in the config file
#   - The server needs a window, so it runs under Xvfb
# ----------------------------
ENV AVP2_ARCHIVE_URL="" \
    AVP2_CONFIG="lancommander" \
    AVP2_SERVER_NAME="Aliens vs. Predator 2" \
    AVP2_PORT="27888" \
    AVP2_GAME_TYPE="deathmatch" \
    AVP2_MAPS="" \
    AVP2_MAX_PLAYERS="16" \
    AVP2_MAX_PLAYERS_PER_RACE="" \
    AVP2_TIME_LIMIT="" \
    AVP2_FRAG_LIMIT="" \
    AVP2_SCORE_LIMIT="" \
    AVP2_ROUND_LIMIT="" \
    AVP2_CAPTURE_LIMIT="" \
    AVP2_PASSWORD="" \
    AVP2_CONTROL_PASSWORD="" \
    AVP2_LAN="true" \
    AVP2_BANDWIDTH="" \
    AVP2_FRIENDLY_FIRE="" \
    AVP2_CLASS_WEAPONS="" \
    WINE_XVFB="true" \
    START_EXE="/usr/local/bin/avp2-server" \
    START_ARGS=""

COPY Scripts/avp2-server /usr/local/bin/avp2-server
RUN chmod +x /usr/local/bin/avp2-server

COPY Hooks/ "${BASE_HOOKS}/"

# 27888/udp: game and GameSpy status queries (AVP2_PORT)
EXPOSE 27888/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
