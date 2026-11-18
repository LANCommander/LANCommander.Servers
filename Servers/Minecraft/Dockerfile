# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/base:local
ARG BASE_IMAGE=lancommander/base:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Minecraft Game Server" \
      org.opencontainers.image.description="Dedicated server for Minecraft: Java Edition (Paper or vanilla) with offline-mode LAN play" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="Minecraft: Java Edition" \
      app.lancommander.server.external-id.hq="061ef6ec-b417-47fd-ab28-d92669579b31" \
      app.lancommander.server.external-id.igdb="121"

# Log files LANCommander shows as consoles under the server's Monitor
LABEL app.lancommander.server.log.server-log="/config/Overlay/logs/latest.log"

# ----------------------------
# Java runtime
#   Eclipse Temurin 25 JRE, which Minecraft 26.x needs (1.20.5 to 1.21.x run on it too)
# ----------------------------
ARG JAVA_URL="https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.5%2B8/OpenJDK25U-jre_x64_linux_hotspot_25.0.5_8.tar.gz"
ARG JAVA_SHA256="6fac98f0c8202efc3135a9e9e42aa61963ec42d1c5cbb40caf231e7b14a24ef6"

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl && \
    rm -rf /var/lib/apt/lists/* && \
    curl -fsSL --retry 3 -o /tmp/jre.tar.gz "${JAVA_URL}" && \
    echo "${JAVA_SHA256}  /tmp/jre.tar.gz" | sha256sum -c - && \
    mkdir -p /opt/java && \
    tar -xzf /tmp/jre.tar.gz -C /opt/java --strip-components=1 && \
    rm /tmp/jre.tar.gz && \
    /opt/java/bin/java -version

# ----------------------------
# Server settings
#   - MINECRAFT_SERVER_TYPE picks the server jar installed into /config/Server on start:
#       paper   - Paper MINECRAFT_VERSION build PAPER_BUILD ("latest" = newest stable build)
#       vanilla - Mojang's server jar for MINECRAFT_VERSION
#       custom  - MINECRAFT_SERVER_URL (checked against MINECRAFT_SERVER_SHA256 when set)
#     The jar is reinstalled when the resolved download changes
#   - MINECRAFT_PLUGINS: whitespace-separated plugin jar URLs (Paper), installed into
#     Server/plugins/. Plugin configs and data are written to plugins/<name>/ in Overlay/
#   - The MINECRAFT_* settings are written into server.properties on every start; empty ones are
#     left as they are. MINECRAFT_PROPERTIES adds any other "key=value" lines (newline or ;
#     separated). Edit the rest of server.properties in Overlay/
#   - MINECRAFT_ONLINE_MODE=false lets offline (LAN) clients in under any name; MINECRAFT_OPS
#     makes those names operators
#   - MINECRAFT_EULA must be "true" to accept the Minecraft EULA (https://aka.ms/MinecraftEULA)
#   - MINECRAFT_LAN_ANNOUNCE lists the server under "LAN Worlds" in clients' multiplayer screen
# ----------------------------
ENV JAVA_HOME=/opt/java \
    PATH="/opt/java/bin:$PATH" \
    MINECRAFT_EULA="false" \
    MINECRAFT_VERSION="26.2" \
    MINECRAFT_SERVER_TYPE="paper" \
    PAPER_BUILD="135" \
    MINECRAFT_SERVER_URL="" \
    MINECRAFT_SERVER_SHA256="" \
    MINECRAFT_PLUGINS="" \
    MINECRAFT_MEMORY="2G" \
    MINECRAFT_JVM_ARGS="" \
    MINECRAFT_PORT="25565" \
    MINECRAFT_ONLINE_MODE="false" \
    MINECRAFT_ENFORCE_SECURE_PROFILE="false" \
    MINECRAFT_MOTD="A LANCommander Minecraft Server" \
    MINECRAFT_MAX_PLAYERS="20" \
    MINECRAFT_LEVEL_NAME="" \
    MINECRAFT_LEVEL_TYPE="" \
    MINECRAFT_GAMEMODE="" \
    MINECRAFT_DIFFICULTY="" \
    MINECRAFT_PVP="" \
    MINECRAFT_SPAWN_PROTECTION="" \
    MINECRAFT_VIEW_DISTANCE="" \
    MINECRAFT_ALLOW_NETHER="" \
    MINECRAFT_PROPERTIES="" \
    MINECRAFT_OPS="" \
    MINECRAFT_RCON_PASSWORD="" \
    MINECRAFT_RCON_PORT="25575" \
    MINECRAFT_LAN_ANNOUNCE="true" \
    START_EXE="/usr/local/bin/minecraft-server" \
    START_ARGS=""

COPY Scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/minecraft-server /usr/local/bin/minecraft-command /usr/local/bin/minecraft-lan-announce

COPY Hooks/ "${BASE_HOOKS}/"

# 25565/tcp: game (MINECRAFT_PORT)
# 25565/udp: server list query, when enable-query=true in server.properties
# 25575/tcp: RCON, when MINECRAFT_RCON_PASSWORD is set (MINECRAFT_RCON_PORT)
EXPOSE 25565/tcp
EXPOSE 25565/udp
EXPOSE 25575/tcp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
