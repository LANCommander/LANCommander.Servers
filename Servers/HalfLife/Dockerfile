# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/steamcmd:local
ARG BASE_IMAGE=lancommander/steamcmd:latest
FROM ${BASE_IMAGE}

# SteamCMD settings
# App 90 is the shared GoldSrc dedicated server (HLDS). Other GoldSrc games use
# the same app and select their content with GAME_MOD (cstrike, dod, tfc, ...).
ENV STEAM_APP_ID="90"
ENV STEAM_INSTALL_ATTEMPTS="3"
ENV GAME_MOD="valve"
ENV START_EXE="hlds_run"
ENV START_ARGS="-game valve -console -port 27015 +maxplayers 16 +map crossfire"
ENV HTTP_FILESERVER_ENABLED="false"
ENV HTTP_FILESERVER_WEB_ROOT="/config/Merged/valve"
ENV HTTP_FILESERVER_FILE_PATTERN="^/(maps|models|sound|sprites|gfx|overviews)/.*\.(bsp|res|txt|wad|mdl|wav|spr|tga|bmp)$"

# ----------------------------
# Dependencies
# ----------------------------
USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    lib32z1 \
    unzip \
    xz-utils \
  && rm -rf /var/lib/apt/lists/*

# ----------------------------
# LANCommander match statistics (https://github.com/LANCommander/LANCommander.MatchStatistics.MetaMod)
#   - MATCH_STATS_ENABLED: auto (on when MATCH_STATS_SERVER_URL and MATCH_STATS_TOKEN are set),
#     true or false. When on, the Metamod plugin is copied into <game>/addons/lancommander, and
#     Metamod-P is put in front of the game DLL unless liblist.gam already loads a Metamod
#   - The MATCH_STATS_* settings become lc_* cvars in <game>/addons/lancommander/lancommander.cfg,
#     which Metamod's exec.cfg runs. Empty settings are left out, so they can be set in server.cfg
# ----------------------------
ENV MATCH_STATS_ENABLED="auto" \
    MATCH_STATS_SERVER_URL="" \
    MATCH_STATS_TOKEN="" \
    MATCH_STATS_GAME_ID="" \
    MATCH_STATS_SERVER_ID="" \
    MATCH_STATS_REPORTER_NAME="" \
    MATCH_STATS_MIN_PLAYERS="" \
    MATCH_STATS_MODE="" \
    MATCH_STATS_RECORD_BOTS="" \
    MATCH_STATS_RECORD_CHAT=""

ARG METAMOD_P_VERSION=1.21p109
ARG METAMOD_P_SHA256=3b77d804cd5687ee18a8535ec02d085e42c9d0da1c12a0683c6aeb25e88d3e1e
ARG MATCH_STATS_VERSION=1.0.0
ARG MATCH_STATS_SHA256=ff00dd99463fd32c1ff1afeb6f212cbf22c3f63715123b3043b7c3a2d7bed6f7

RUN curl -fsSL --retry 8 --retry-delay 15 --retry-all-errors -o /tmp/metamod-p.tar.xz \
      "https://github.com/Bots-United/metamod-p/releases/download/v${METAMOD_P_VERSION}/metamod-p-v${METAMOD_P_VERSION}-linux_ubuntu1804.tar.xz" && \
    echo "${METAMOD_P_SHA256}  /tmp/metamod-p.tar.xz" | sha256sum -c - && \
    curl -fsSL --retry 8 --retry-delay 15 --retry-all-errors -o /tmp/match-stats.zip \
      "https://github.com/LANCommander/LANCommander.MatchStatistics.MetaMod/releases/download/v${MATCH_STATS_VERSION}/LANCommander.MatchStatistics.MetaMod-v${MATCH_STATS_VERSION}.zip" && \
    echo "${MATCH_STATS_SHA256}  /tmp/match-stats.zip" | sha256sum -c - && \
    mkdir -p /opt/lancommander-stats/addons/metamod/dlls && \
    tar --no-same-owner -xJf /tmp/metamod-p.tar.xz -C /opt/lancommander-stats addons/metamod/dlls/metamod.so && \
    unzip -q /tmp/match-stats.zip 'addons/lancommander/dlls/*.so' -d /opt/lancommander-stats && \
    rm /tmp/metamod-p.tar.xz /tmp/match-stats.zip

EXPOSE 27015/udp
EXPOSE 80/tcp

# Replaces the SteamCMD image's PostInitialization/20-InstallGame.ps1
COPY Hooks/ "${BASE_HOOKS}/"

USER lancommander

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
