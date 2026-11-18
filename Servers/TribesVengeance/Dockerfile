# syntax=docker/dockerfile:1.7

FROM lancommander/wine:latest-gui

LABEL org.opencontainers.image.title="Tribes: Vengeance Server" \
      org.opencontainers.image.description="A Docker container to host a Tribes: Vengeance game server"

# Server settings
ENV START_EXE="xvfb-run wine Beta_Dedicated_Server.exe"
ENV START_ARGS="MP-Fort?game=GameClasses.ModeCTF?maxplayers=32"
ENV SERVER_DOWNLOAD_URL="https://github.com/LANCommander/LANCommander.Servers.TribesVengeance/releases/download/server/Tribes.Vengeance.Dedicated.Server.zip"
ENV HTTP_FILESERVER_ENABLED="true"
ENV HTTP_FILESERVER_WEB_ROOT="/config/Merged"
ENV HTTP_FILESERVER_FILE_PATTERN="^/.*\.(uz2)$"

# ----------------------------
# Dependencies
# ----------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libvulkan1 \
    dbus \
    dbus-user-session \
  && rm -rf /var/lib/apt/lists/*

EXPOSE 7777/udp
EXPOSE 7778/udp

# COPY Modules/ "${BASE_MODULES}/"
COPY Hooks/ "${BASE_HOOKS}/"

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]