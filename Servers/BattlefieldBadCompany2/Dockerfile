# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest

# Both downloads come from the battlefieldbadcompany2mase project on SourceForge, which sends
# every request to a random mirror. Some mirrors fail TLS or stall, so curl gives up on a mirror
# after 60 s without data and resumes; the sha256 pins each file.
ARG SOURCEFORGE_URL=https://downloads.sourceforge.net/project/battlefieldbadcompany2mase

# ----------------------------
# MASE:BC2 master server emulator (Plasma/Theater login and server browser), built from source
# with the hardening patch from https://codeberg.org/jkuettner/bfbc2-server. The game client only
# speaks SSLv3, so it is built against Alpine 3.8's OpenSSL 1.0.2, and linked statically so the
# musl binary runs on the Debian base image.
# ----------------------------
FROM debian:bookworm AS mase-source

ARG SOURCEFORGE_URL
ARG MASE_SOURCE_SHA256=a3e180526ac71af639e73c5ee33ea98c55ddae48d0e81aea2621070b0272031c

RUN sed -i 's/^Components: main$/& contrib non-free non-free-firmware/' /etc/apt/sources.list.d/debian.sources \
 && apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unrar cbp2make patch \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /mase
COPY MasterServer/patches/ /mase/patches/
RUN set -eux; \
    for try in 1 2 3 4 5 6 7 8; do \
        curl -fL -C - --speed-time 60 --speed-limit 1000 -o /tmp/src_v09.rar "${SOURCEFORGE_URL}/Source%20V0.9/src_v09.rar" && break; \
        sleep 5; \
    done; \
    echo "${MASE_SOURCE_SHA256}  /tmp/src_v09.rar" | sha256sum -c -; \
    unrar x -inul /tmp/src_v09.rar; \
    patch -d ./src -p1 --binary < /mase/patches/hardening.patch; \
    cd src; \
    sed -i -e 's@$(BOOST_1_54_DIR)@/usr/include/boost/@g' -e 's@$(OPEN_SSL_DIR)@/usr/include/openssl/@g' mase_bc2.vcxproj mase_bc2.cbp; \
    for lib in libboost_system libboost_filesystem libboost_random libssl libcrypto; do \
        sed -i -e "s@${lib}.a@/usr/lib/${lib}.a@g" mase_bc2.cbp; \
    done; \
    cbp2make -in mase_bc2.cbp -out Makefile; \
    sed -i -e '/^LIB = / s@$@ -lz@' -e '/^LDFLAGS_RELEASE = / s@$@ -static@' Makefile; \
    grep -q '^LDFLAGS_RELEASE = .*-static' Makefile

FROM alpine:3.8 AS mase-build

RUN apk add --no-cache bash make gcc g++ boost-dev openssl-dev zlib-dev

COPY --from=mase-source /mase /mase
WORKDIR /mase/src
RUN CXXFLAGS="-std=gnu++11" make release \
 && ! readelf -l bin/Release/mase_bc2 | grep -q 'program interpreter'

# ----------------------------
# Bc2emu V0.9: the Battlefield: Bad Company 2 R34 dedicated server, with the emulator's
# dinput8.dll hook (reads bfbc2.ini and redirects the server to the master server). The docs,
# the client crack, the Windows master server, the batch files and old logs are left out.
# ----------------------------
FROM debian:bookworm AS bc2emu

ARG SOURCEFORGE_URL
ARG BC2EMU_SHA256=d1b25860f23af15cbab6549d41840836056ab38a49357eb3064a7d00f6d9f04b

RUN sed -i 's/^Components: main$/& contrib non-free non-free-firmware/' /etc/apt/sources.list.d/debian.sources \
 && apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unrar \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    for try in 1 2 3 4 5 6 7 8 9 10 11 12; do \
        curl -fL -C - --speed-time 60 --speed-limit 1000 -o /tmp/Bc2emu_V09.rar "${SOURCEFORGE_URL}/Bc2emu_V09.rar" && break; \
        sleep 5; \
    done; \
    echo "${BC2EMU_SHA256}  /tmp/Bc2emu_V09.rar" | sha256sum -c -; \
    unrar x -inul \
        -x'Bc2emu/!DOCS' \
        -x'Bc2emu/Crack - Copy to client root' \
        -x'Bc2emu/MasterServerEmu' \
        -x'Bc2emu/Source and Stuff' \
        -x'*.bat' -x'*.log' -x'*.txt' -x'*.xml' \
        /tmp/Bc2emu_V09.rar /tmp/; \
    mkdir -p /opt/bfbc2; \
    mv /tmp/Bc2emu /opt/bfbc2/server; \
    # One instance directory is enough: the launcher writes its maplist and options from BFBC2_*
    cd /opt/bfbc2/server; \
    find . -maxdepth 1 -iname 'instance?*' -exec rm -rf {} +; \
    rm -f 'Instance/!for_vietnam_ServerOptions.ini'; \
    test -f Frost.Game.Main_Win32_Final.exe; \
    test -f ProviderID.dat; \
    test -f dinput8.dll

# ----------------------------
# Game server image
# ----------------------------
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Battlefield: Bad Company 2 Game Server" \
      org.opencontainers.image.description="Dedicated server for Battlefield: Bad Company 2 and Vietnam (Bc2emu R34 under Wine) with a built-in MASE master server" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="Battlefield: Bad Company 2" \
      app.lancommander.server.external-id.hq="09be67df-a70e-444b-9511-b81b27e65a24" \
      app.lancommander.server.external-id.igdb="352" \
      app.lancommander.server.external-id.steam="24960"

# ----------------------------
# Game server settings
#   - BFBC2_MODE: rush, conquest, sqdm, sqrush, vietrush, vietconquest, vietsqdm or vietsqrush.
#     Picks the maplist (maplists/<mode>.txt in the server folder) and the BC2/VIETNAM mod
#   - Instance/ServerOptions.ini, Instance/AdminScripts/Startup.txt, Instance/maplist.txt and
#     bfbc2.ini are written from these settings on every start
#   - BFBC2_ADMIN_PASSWORD empty: a random password is generated and printed on every start
# ----------------------------
ENV BFBC2_MODE="rush" \
    BFBC2_SERVER_NAME="Bad Company 2 Server" \
    BFBC2_PORT="19567" \
    BFBC2_ADMIN_PORT="48888" \
    BFBC2_ADMIN_PASSWORD="" \
    BFBC2_MAX_PLAYERS="32" \
    BFBC2_RANKED="true" \
    BFBC2_HARDCORE="false" \
    BFBC2_FRIENDLY_FIRE="false" \
    BFBC2_TEAM_BALANCE="true" \
    BFBC2_KILL_CAM="true" \
    BFBC2_MINIMAP="true" \
    BFBC2_CROSSHAIR="true" \
    BFBC2_3D_SPOTTING="true" \
    BFBC2_MINIMAP_SPOTTING="true" \
    BFBC2_STARTUP_COMMANDS="" \
    BFBC2_REGION="OC" \
    BFBC2_EXTRA_ARGS="" \
    START_EXE="/usr/local/bin/bfbc2-server" \
    START_ARGS=""

# ----------------------------
# Master server (MASE:BC2)
#   - BFBC2_MASTER_SERVER_ENABLED: run the master server in this container. Players' bfbc2.ini
#     host= and other game servers' BFBC2_MASTER_SERVER then point at this container's IP
#   - BFBC2_MASTER_SERVER: the master server this game server registers with. Empty = this
#     container's own IP (not 127.0.0.1: the master lists a server at the address it connected
#     from)
#   - Its config.ini is written from these settings on every start; accounts, personas and stats
#     are kept in /config/Master/database
# ----------------------------
ENV BFBC2_MASTER_SERVER_ENABLED="true" \
    BFBC2_MASTER_SERVER="" \
    BFBC2_MASTER_ALL_STATS_UNLOCKED="true" \
    BFBC2_MASTER_ALL_VETERAN="true" \
    BFBC2_MASTER_PREMIUM_FOR_ALL="true" \
    BFBC2_MASTER_SPECACT_FOR_ALL="false" \
    BFBC2_MASTER_VIETNAM_FOR_ALL="true" \
    BFBC2_MASTER_LOG_LEVEL="1" \
    BFBC2_MASTER_DIR="/config/Master"

# Visual C++ 2005/2008/2010 runtimes and native dinput8 for the server, installed into the prefix
# on first start (PostInitializeWinePrefix). The installers are cached in the image: winetricks
# runs once here in a throwaway prefix to download them.
ENV W_CACHE=/opt/winetricks-cache

ARG WINETRICKS_VERBS="dinput8 vcrun2005 vcrun2008 vcrun2010"
RUN set -eux; \
    mkdir -p "${W_CACHE}"; \
    export WINEPREFIX=/tmp/cache-prefix HOME=/tmp/cache-home; \
    mkdir -p "$HOME"; \
    xvfb-run -a winetricks -q ${WINETRICKS_VERBS}; \
    wineserver -w; \
    # dinput8 comes from the DirectX redist, cached as directx9/
    for dir in directx9 vcrun2005 vcrun2008 vcrun2010; do test -n "$(ls -A "${W_CACHE}/${dir}")" || { echo "winetricks did not cache ${dir}"; exit 1; }; done; \
    rm -rf /tmp/cache-prefix /tmp/cache-home /tmp/.X* /tmp/xvfb-run.*; \
    chmod -R a+rX "${W_CACHE}"

COPY --from=mase-build /mase/src/bin/Release/mase_bc2 /opt/mase/mase_bc2
COPY MasterServer/templates/ /opt/mase/templates/
COPY --from=bc2emu /opt/bfbc2/server/ /opt/bfbc2/server/
COPY Maplists/ /opt/bfbc2/maplists/

COPY Scripts/bfbc2-server /usr/local/bin/bfbc2-server
RUN chmod +x /usr/local/bin/bfbc2-server

COPY Hooks/ "${BASE_HOOKS}/"

# 19567/udp: game (BFBC2_PORT). 48888/tcp: remote admin / RCON (BFBC2_ADMIN_PORT).
# Master server: 18390/tcp client login (Plasma), 18395/tcp+udp client server browser (Theater),
# 19021/tcp + 19026/tcp game server registration (Plasma/Theater), 9946/tcp misc requests.
EXPOSE 19567/udp 48888/tcp 18390/tcp 18395/tcp 18395/udp 19021/tcp 19026/tcp 9946/tcp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
