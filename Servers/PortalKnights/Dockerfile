# syntax=docker/dockerfile:1.7

FROM lancommander/wine:latest-amd64

LABEL org.opencontainers.image.title="Portal Knights Server" \
      org.opencontainers.image.description="A Docker container to host a Portal Knights game server"

# Server settings
ENV START_EXE="wine64"
ENV START_ARGS="pk_dedicated_server.exe"

# ----------------------------
# Dependencies
# ----------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    bzip2 \
    tar \
    unzip \
    xz-utils \
    p7zip-full \
    gosu \
  && rm -rf /var/lib/apt/lists/*

EXPOSE 16365/udp

# COPY Modules/ "${BASE_MODULES}/"
# COPY Hooks/ "${BASE_HOOKS}/"

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]