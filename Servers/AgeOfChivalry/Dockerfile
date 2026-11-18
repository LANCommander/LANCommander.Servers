# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/steamcmd:local
ARG BASE_IMAGE=lancommander/steamcmd:latest
FROM ${BASE_IMAGE}

# SteamCMD settings
ENV STEAM_APP_ID="17515"
ENV START_EXE="srcds_run"
ENV START_ARGS="-game ageofchivalry -console -norestart -insecure +maxplayers 16 +map aoc_battleground"
ENV HTTP_FILESERVER_ENABLED="true"
ENV HTTP_FILESERVER_WEB_ROOT="/config/Merged/ageofchivalry"
ENV HTTP_FILESERVER_FILE_PATTERN="^/(maps|materials|models|sound)/.*\.(bz2|ztmp|bsp|nav|res|mdl|vvd|vtx|phy|ani|vmt|vtf|wav|mp3)$"

# Game traffic and server queries
EXPOSE 27015/udp
# RCON
EXPOSE 27015/tcp
# SourceTV
EXPOSE 27020/udp
# HTTP file server (FastDL)
EXPOSE 80/tcp

COPY Hooks/ "${BASE_HOOKS}/"

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
