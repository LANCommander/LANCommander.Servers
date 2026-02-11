# syntax=docker/dockerfile:1.7

FROM lancommander/wine:latest-gui

# Server settings
ENV START_EXE="wine"
ENV START_ARGS="Program/Bin/Beta_Dedicated_Server.exe MP-REV-CanyonCrusade?game=GameClasses.ModeCTF?maxplayers=32"
ENV HTTP_FILESERVER_ENABLED="true"
ENV HTTP_FILESERVER_WEB_ROOT="/config/Merged"
ENV HTTP_FILESERVER_FILE_PATTERN="^/.*\.(uz2)$"

# ----------------------------
# Dependencies
# ----------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gosu \
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