# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

# ----------------------------
# Server settings
#   - The game files are not downloadable; put a Far Cry 1.4 install (Bin32/FarCry_WinSV.exe,
#     FCData/, Levels/ ...) in /config/Server, or set FC_ARCHIVE_URL to a zip of one
#   - FarCry_WinSV.exe takes console commands as arguments. The launcher runs
#     `"sv_port <FC_PORT>" "log_verbosity <FC_LOG_VERBOSITY>" [START_ARGS] "SProfile_run <FC_PROFILE>"`
#   - The FC_* settings below are written into Profiles/server/<FC_PROFILE>_server.cfg on every
#     start (empty settings are left alone)
#   - FC_MAPCYCLE is a comma-separated rotation of `<map> <FFA|TDM|ASSAULT>` entries
#   - The server needs a window, so it runs under Xvfb
# ----------------------------
ENV FC_ARCHIVE_URL="" \
    FC_PROFILE="LANCommander" \
    FC_PORT="49001" \
    FC_SERVER_NAME="Far Cry Server" \
    FC_SERVER_TYPE="LAN" \
    FC_GAME_TYPE="FFA" \
    FC_MAP="mp_monkeybay" \
    FC_MAPCYCLE="mp_monkeybay FFA,mp_radio FFA,mp_surf FFA,mp_cliffside FFA,mp_monkeybay_n FFA" \
    FC_MAX_PLAYERS="16" \
    FC_TIME_LIMIT="15" \
    FC_SCORE_LIMIT="" \
    FC_RESPAWN_TIME="" \
    FC_FRIENDLY_FIRE="" \
    FC_PASSWORD="" \
    FC_RCON_PASSWORD="" \
    FC_PUNKBUSTER="false" \
    FC_LOG_VERBOSITY="3" \
    WINE_XVFB="true" \
    START_EXE="/usr/local/bin/farcry-server" \
    START_ARGS=""

COPY Scripts/farcry-server /usr/local/bin/farcry-server
RUN chmod +x /usr/local/bin/farcry-server

COPY Hooks/ "${BASE_HOOKS}/"

# 49001/udp: game (FC_PORT)
# 49124/udp: All-Seeing Eye status queries, always the game port + 123
# 5678/udp:  bound by CryNetwork at a fixed port, whatever FC_PORT is
EXPOSE 49001/udp
EXPOSE 49124/udp
EXPOSE 5678/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
