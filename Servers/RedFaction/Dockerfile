# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest

# ----------------------------
# rf-stats-bridge (StatsBridge/): stands in for FactionFiles' stats API and reports Alpine
# Faction's games to LANCommander through the LANCommander Interposer. Built on Debian 12, as
# the base image is
# ----------------------------
FROM debian:bookworm AS stats-bridge

ARG INTERPOSER_VERSION=v1.6.0
ARG YAML_CPP_VERSION=0.8.0
ARG HTTPLIB_VERSION=0.18.3
ARG HTTPLIB_SHA256=a0a0c13dc086663863dbe6730a19716f7d3744904b6205496e8301750814dbd5

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        build-essential cmake git ca-certificates curl libssl-dev nlohmann-json3-dev \
 && rm -rf /var/lib/apt/lists/*

# The Interposer wants yaml-cpp's namespaced CMake target, which Debian 12's 0.7 lacks
RUN git clone --quiet --depth 1 --branch "${YAML_CPP_VERSION}" https://github.com/jbeder/yaml-cpp /src/yaml-cpp \
 && cmake -S /src/yaml-cpp -B /src/yaml-cpp/build -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DYAML_BUILD_SHARED_LIBS=OFF -DYAML_CPP_BUILD_TESTS=OFF -DYAML_CPP_BUILD_TOOLS=OFF -DYAML_CPP_BUILD_CONTRIB=OFF \
 && cmake --build /src/yaml-cpp/build -j"$(nproc)" \
 && cmake --install /src/yaml-cpp/build

RUN git clone --quiet --depth 1 --branch "${INTERPOSER_VERSION}" \
        https://github.com/LANCommander/LANCommander.Interposer /src/interposer \
 && mkdir -p /src/httplib \
 && curl -fsSL --retry 8 --retry-delay 15 --retry-all-errors -o /src/httplib/httplib.h \
        "https://raw.githubusercontent.com/yhirose/cpp-httplib/v${HTTPLIB_VERSION}/httplib.h" \
 && echo "${HTTPLIB_SHA256}  /src/httplib/httplib.h" | sha256sum -c -

COPY StatsBridge/ /src/bridge/
RUN cmake -S /src/bridge -B /src/bridge/build -DCMAKE_BUILD_TYPE=Release \
        -DLANCOMMANDER_INTERPOSER_DIR=/src/interposer -DHTTPLIB_DIR=/src/httplib \
        -DINTERPOSER_VERSION="${INTERPOSER_VERSION}" \
 && cmake --build /src/bridge/build -j"$(nproc)" \
 && strip /src/bridge/build/rf-stats-bridge

FROM ${BASE_IMAGE}

# Alpine Faction release (GitHub tag without the leading "v")
ARG AF_VERSION=1.4.0_Lupin

# Log files LANCommander shows as consoles under the server's Monitor
LABEL app.lancommander.server.log.server-log="/config/Overlay/logs/AlpineFaction-dedicated-server.log"

# ----------------------------
# Server settings
#   - The game files are not downloadable; put a Red Faction 1.20 NA install in /config/Server,
#     or set RF_ARCHIVE_URL to a zip of one
#   - Alpine Faction is baked into the image and copied into the game folder on every start
#     (AF_INSTALL=false keeps the folder's own copy)
#   - Server rules and the level rotation live in <RF_CONFIG>.toml (an Alpine Faction ADS config),
#     created from a default on first start; the RF_* settings below are written into it on
#     every start (empty settings are left alone)
#   - The server runs headless: in dedicated mode RF opens no window, so Xvfb isn't needed
# ----------------------------
ENV AF_VERSION="${AF_VERSION}" \
    AF_INSTALL="true" \
    RF_ARCHIVE_URL="" \
    RF_CONFIG="server" \
    RF_PORT="7755" \
    RF_LAN_ONLY="true" \
    RF_EXE="" \
    RF_SERVER_NAME="Red Faction Server" \
    RF_MAX_PLAYERS="16" \
    RF_PASSWORD="" \
    RF_RCON_PASSWORD="" \
    WINE_XVFB="false" \
    START_EXE="/usr/local/bin/rf-server" \
    START_ARGS=""

# ----------------------------
# LANCommander match statistics
#   - Alpine Faction reports every game (kills, awards, flag/point/bag events, Gun Game levels,
#     each player's scoreboard summary) to FactionFiles. With the match statistics on, the
#     image's rf-stats-bridge answers in FactionFiles' place, inside the container, and sends
#     the games to LANCommander through the LANCommander Interposer
#   - MATCH_STATS_ENABLED: auto (on when MATCH_STATS_SERVER_URL and MATCH_STATS_TOKEN are set),
#     true or false
#   - MATCH_STATS_DEMOS: record each level (demo_auto_record) and attach the demo to its match
#   - Undelivered matches and the Interposer's logs are kept in /config/.interposer/
# ----------------------------
ENV MATCH_STATS_ENABLED="auto" \
    MATCH_STATS_SERVER_URL="" \
    MATCH_STATS_TOKEN="" \
    MATCH_STATS_GAME_ID="" \
    MATCH_STATS_SERVER_ID="" \
    MATCH_STATS_REPORTER_NAME="" \
    MATCH_STATS_MIN_PLAYERS="1" \
    MATCH_STATS_DEMOS="true" \
    MATCH_STATS_RECORD_BOTS="true" \
    MATCH_STATS_RECORD_VOTES="true" \
    MATCH_STATS_RECORD_SPAWNS="false" \
    MATCH_STATS_RECORD_ITEMS="false"

RUN curl -fsSL --retry 3 -o /tmp/alpinefaction.zip \
        "https://github.com/GooberRF/alpinefaction/releases/download/v${AF_VERSION}/AlpineFaction-${AF_VERSION}.zip" \
 && pwsh -NoProfile -Command "Expand-Archive -Path /tmp/alpinefaction.zip -DestinationPath /opt/alpinefaction" \
 && rm -f /tmp/alpinefaction.zip /opt/alpinefaction/_README.txt \
 && test -f /opt/alpinefaction/AlpineFactionLauncher.exe

COPY --from=stats-bridge /src/bridge/build/rf-stats-bridge /usr/local/bin/rf-stats-bridge
COPY Scripts/rf-server /usr/local/bin/rf-server
COPY Scripts/server.toml /usr/local/share/redfaction/server.toml
RUN chmod +x /usr/local/bin/rf-server

COPY Hooks/ "${BASE_HOOKS}/"

# 7755/udp: game, server info queries and LAN browser broadcasts (RF_PORT)
EXPOSE 7755/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
