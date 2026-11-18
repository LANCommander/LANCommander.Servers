# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

# Native DirectPlay comes from the DirectX February 2010 redist. Wine's builtin dpnet cannot host
# (IDirectPlay8Server::Host is a stub), so the redist is cached in the image and installed into the
# prefix with `winetricks directplay` on first start. Microsoft's own URL is gone; this is the mirror
# winetricks pins, checked against the same sha256.
ARG DIRECTX_REDIST_URL="https://files.holarse-linuxgaming.de/mirrors/microsoft/directx_feb2010_redist.exe"
ARG DIRECTX_REDIST_SHA256="f6d191e89a963d7cca34f169d30f49eab99c1ed3bb92da73ec43617caaa1e93f"

# FLServer.exe is an MFC app and imports MFC42.DLL, which Wine doesn't ship. winetricks' mfc42 verb
# takes it from the VC6 redist. vcredist.exe is pre-extracted here because winetricks would otherwise
# unpack it by running the self-extractor under Wine, which fails headless (status 43).
ARG VC6_REDIST_URL="https://download.microsoft.com/download/vc60pro/Update/2/W9XNT4/EN-US/VC6RedistSetup_deu.exe"
ARG VC6_REDIST_SHA256="c2eb91d9c4448d50e46a32fecbcc3b418706d002beab9b5f4981de552098cee7"

# ----------------------------
# Server settings
#   - The game files are not downloadable; put a Freelancer 1.1 install in /config/Server, or set
#     FL_ARCHIVE_URL to a zip of one
#   - FL_* settings are written to FLServer.cfg (the server's setup dialog) on every start
# ----------------------------
ENV W_CACHE=/opt/winetricks-cache \
    FL_ARCHIVE_URL="" \
    FL_SERVER_NAME="Freelancer Server" \
    FL_DESCRIPTION="" \
    FL_PASSWORD="" \
    FL_MAX_PLAYERS="16" \
    FL_ALLOW_NEW_PLAYERS="true" \
    FL_PVP="false" \
    FL_INTERNET="false" \
    FL_PORT="2302" \
    FL_EXTRA_ARGS="" \
    START_EXE="/usr/local/bin/fl-server" \
    START_ARGS=""

RUN set -eux; \
    mkdir -p "${W_CACHE}/directx9" "${W_CACHE}/vcrun6"; \
    curl -fsSL --retry 3 "${DIRECTX_REDIST_URL}" -o "${W_CACHE}/directx9/directx_feb2010_redist.exe"; \
    echo "${DIRECTX_REDIST_SHA256}  ${W_CACHE}/directx9/directx_feb2010_redist.exe" | sha256sum -c -; \
    curl -fsSL --retry 3 "${VC6_REDIST_URL}" -o "${W_CACHE}/vcrun6/VC6RedistSetup_deu.exe"; \
    echo "${VC6_REDIST_SHA256}  ${W_CACHE}/vcrun6/VC6RedistSetup_deu.exe" | sha256sum -c -; \
    cabextract -q -d "${W_CACHE}/vcrun6" -F vcredist.exe "${W_CACHE}/vcrun6/VC6RedistSetup_deu.exe"; \
    test -f "${W_CACHE}/vcrun6/vcredist.exe"

COPY Scripts/fl-server /usr/local/bin/fl-server
RUN chmod +x /usr/local/bin/fl-server

COPY Hooks/ "${BASE_HOOKS}/"

# 2302/udp: game (DirectPlay host, FL_PORT). 6073/udp: DirectPlay session enumeration (dpnsvr).
EXPOSE 2302/udp 6073/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
