# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/base:local
ARG BASE_IMAGE=lancommander/base:latest
# MHServerEmu release baked into the image (https://github.com/Crypto137/MHServerEmu/releases)
ARG MHSE_VERSION=1.0.3
ARG MHSE_SHA256=dc41a01dcad4a6ced057b6fe1a05baa79b739cf0c574bf4dca2c0d2d4bbadc97

# ----------------------------
# MHServerEmu release: the server (MHServerEmu/) and the web files its bundled Apache serves
# (Apache24/htdocs: SiteConfig.xml, store, news, loading tips). Apache itself and the Windows-only
# parts are left out; nginx takes Apache's place.
# ----------------------------
FROM debian:12-slim AS mhserveremu

ARG MHSE_VERSION
ARG MHSE_SHA256

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSL --retry 3 -o /tmp/mhse.zip \
        "https://github.com/Crypto137/MHServerEmu/releases/download/${MHSE_VERSION}/MHServerEmu-${MHSE_VERSION}.zip" && \
    echo "${MHSE_SHA256}  /tmp/mhse.zip" | sha256sum -c - && \
    unzip -q /tmp/mhse.zip -d /tmp/mhse && \
    mkdir -p /opt/mhserveremu && \
    cp -a /tmp/mhse/MHServerEmu/. /opt/mhserveremu/ && \
    cp -a /tmp/mhse/Apache24/htdocs /opt/mhserveremu/htdocs && \
    cp /tmp/mhse/README.txt /tmp/mhse/CHANGELOG.txt /tmp/mhse/LICENSE.txt /opt/mhserveremu/ && \
    rm -rf /opt/mhserveremu/MHServerEmu.exe \
           /opt/mhserveremu/runtimes/win-x64 /opt/mhserveremu/runtimes/win-x86 /opt/mhserveremu/runtimes/osx-x64 && \
    echo "${MHSE_VERSION}" > /opt/mhserveremu/.mhserveremu-version && \
    chmod -R u+rwX,go+rX /opt/mhserveremu

FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Marvel Heroes Game Server" \
      org.opencontainers.image.description="MHServerEmu server for Marvel Heroes (Omega 1.52.0.1700), with the web front end it needs" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="Marvel Heroes" \
      app.lancommander.server.external-id.hq="4b790aed-b9c1-4785-ab7b-66d7c828f105" \
      app.lancommander.server.external-id.igdb="50867" \
      app.lancommander.server.external-id.steam="226320"

ARG MHSE_VERSION

# ----------------------------
# Server settings
#   - MHServerEmu (MHSE_VERSION, baked into the image) is copied into /config/Server on first start
#     and whenever the image brings a different version. It needs two files from the game client,
#     Data/Game/Calligraphy.sip and mu_cdata.sip; they're copied in from MH_CLIENT_DATA_DIR
#   - MH_PUBLIC_ADDRESS is the address clients reach the server at (frontend, auth, web pages).
#     Empty: the container's own IPv4 address, looked up on every start
#   - The MH_* settings and any MHSE__<Section>__<Key> variable are written into ConfigOverride.ini,
#     which the server reads over Config.ini, on every start
#   - nginx serves SiteConfig.xml and the store/news pages on port 80 and passes /AuthServer,
#     /Dashboard etc. to the server's web front end, on 80 and over HTTPS on 443
# ----------------------------
ENV MHSE_VERSION="${MHSE_VERSION}" \
    MH_PUBLIC_ADDRESS="" \
    MH_CLIENT_DATA_DIR="/config/ClientData" \
    MH_FRONTEND_PORT="4306" \
    MH_WEB_PORT="8080" \
    MH_SERVER_NAME="MHServerEmu" \
    MH_MOTD="" \
    MH_SERVER_CAPACITY="" \
    MH_AUTOSAVE_MINUTES="5" \
    MH_AUTO_UNLOCK_AVATARS="" \
    MH_AUTO_UNLOCK_TEAMUPS="" \
    MH_STARTING_GAZILLIONITE="" \
    MH_USE_WHITELIST="" \
    MH_LOG_LEVEL="2" \
    MH_TLS_CERT="/etc/mhserveremu/ssl/server.crt" \
    MH_TLS_KEY="/etc/mhserveremu/ssl/server.key" \
    DOTNET_CLI_TELEMETRY_OPTOUT="1" \
    DOTNET_NOLOGO="1" \
    START_EXE="/usr/local/bin/mhserveremu-server" \
    START_ARGS=""

# .NET 10 runtime from Microsoft's Debian 12 feed; openssl for the self-signed HTTPS certificate
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl openssl && \
    curl -fsSL -o /tmp/packages-microsoft-prod.deb https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb && \
    dpkg -i /tmp/packages-microsoft-prod.deb && rm /tmp/packages-microsoft-prod.deb && \
    apt-get update && apt-get install -y --no-install-recommends dotnet-runtime-10.0 && \
    rm -rf /var/lib/apt/lists/*

# The client doesn't check the auth server's certificate (MHServerEmu ships an expired one for
# localhost), so any self-signed certificate does
RUN mkdir -p /etc/mhserveremu/ssl && \
    openssl req -x509 -nodes -newkey rsa:2048 -days 36500 \
        -subj "/CN=mhserveremu" \
        -keyout /etc/mhserveremu/ssl/server.key -out /etc/mhserveremu/ssl/server.crt && \
    chmod 600 /etc/mhserveremu/ssl/server.key

COPY --from=mhserveremu /opt/mhserveremu /opt/mhserveremu

COPY Config/nginx.conf /usr/local/share/mhserveremu-nginx.conf.template
COPY Scripts/mhserveremu-server Scripts/mhserveremu-command /usr/local/bin/
RUN chmod +x /usr/local/bin/mhserveremu-server /usr/local/bin/mhserveremu-command

COPY Hooks/ "${BASE_HOOKS}/"

# 4306/tcp: game frontend (MH_FRONTEND_PORT)
# 80/tcp:   SiteConfig.xml, store/news pages, loading tips, account dashboard
# 443/tcp:  HTTPS auth server (login), passed on to the web front end
EXPOSE 4306/tcp 80/tcp 443/tcp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
