# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/base:local
ARG BASE_IMAGE=lancommander/base:latest
FROM ${BASE_IMAGE}

ARG WINETRICKS_VERSION=20260125

ENV DEBIAN_FRONTEND=noninteractive

# ----------------------------
# Wine runtime defaults
#   - WINEPREFIX lives in /config so it persists and is chowned to the run user by the entrypoint
#   - mscoree/mshtml are disabled so Wine never stalls headless on the Mono/Gecko install prompts
#   - WINE_XVFB: auto (use Xvfb when no DISPLAY is set), true, or false; see Scripts/wine-run
#   - WINE_WORKDIR: directory wine-run starts the program from (empty = $SERVER_ROOT)
# ----------------------------
ENV WINEPREFIX=/config/wineprefix \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES="mscoree,mshtml=" \
    WINE_XVFB=auto \
    WINE_XVFB_SCREEN=1024x768x24 \
    WINE_WORKDIR="" \
    XDG_RUNTIME_DIR=/tmp

# ----------------------------
# Dependencies + WineHQ
# ----------------------------
RUN set -eux; \
    dpkg --add-architecture i386; \
    \
    apt-get update; \
    apt-get install --no-install-recommends -y \
        ca-certificates \
        curl \
        gnupg; \
    \
    # Add WineHQ signing key (keyring style, no apt-key)
    install -m 0755 -d /etc/apt/keyrings; \
    curl -fsSL https://dl.winehq.org/wine-builds/winehq.key \
      | gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key; \
    chmod 0644 /etc/apt/keyrings/winehq-archive.key; \
    \
    # Add WineHQ Debian Bookworm repository
    echo "deb [signed-by=/etc/apt/keyrings/winehq-archive.key] https://dl.winehq.org/wine-builds/debian bookworm main" \
      > /etc/apt/sources.list.d/winehq.list; \
    \
    # Stub out hard Wine deps a headless server never loads (Wine dlopen()s them and copes when absent):
    #   libasound2-plugins -> ffmpeg/x265/Intel media stack, libsane1 -> SNMP + Perl
    for pkg in libasound2-plugins libsane1; do \
      for arch in amd64 i386; do \
        d="/tmp/stub/$pkg-$arch"; mkdir -p "$d/DEBIAN"; \
        printf 'Package: %s\nVersion: 99:0-stub\nArchitecture: %s\nMulti-Arch: same\nMaintainer: LANCommander\nDescription: empty stub for headless Wine\n' \
          "$pkg" "$arch" > "$d/DEBIAN/control"; \
        dpkg-deb -b "$d" "/tmp/stub/$pkg-$arch.deb" >/dev/null; \
      done; \
    done; \
    dpkg -i /tmp/stub/*.deb; \
    apt-mark hold libasound2-plugins:amd64 libasound2-plugins:i386 libsane1:amd64 libsane1:i386; \
    \
    apt-get update; \
    # No Recommends: they drag in VA/VDPAU/Intel media drivers, ffmpeg/x265 codecs, SANE, i386 LLVM, ...
    # Keep only the Recommends a headless server can plausibly use, for both architectures.
    keep="libfreetype6 libfontconfig1 libgnutls30 libkrb5-3 libgssapi-krb5-2 libdbus-1-3 \
          libpng16-16 libjpeg62-turbo libxslt1.1 libxcomposite1 libxcursor1 libxfixes3 libxi6 \
          libxinerama1 libxrandr2 libxrender1 libxxf86vm1 libgl1 libgl1-mesa-dri"; \
    apt-get install --no-install-recommends -y \
        winehq-stable \
        $keep $(for p in $keep; do printf '%s:i386 ' "$p"; done); \
    \
    # WineHQ builds ship every PE module with full DWARF debug info (~430MB); strip it
    apt-get install --no-install-recommends -y binutils-mingw-w64-x86-64 binutils-mingw-w64-i686 binutils; \
    find /opt/wine-stable/lib/wine/x86_64-windows -type f -exec x86_64-w64-mingw32-strip --strip-debug {} +; \
    find /opt/wine-stable/lib/wine/i386-windows -type f -exec i686-w64-mingw32-strip --strip-debug {} +; \
    find /opt/wine-stable/lib/wine/*-unix -type f -name '*.so' -exec strip --strip-debug {} +; \
    apt-get purge -y --auto-remove binutils-mingw-w64-x86-64 binutils-mingw-w64-i686 binutils; \
    \
    # Headless display: many Windows dedicated servers are GUI-subsystem programs (e.g. srcds -console
    # allocates a console window) and exit immediately without an X server
    apt-get install --no-install-recommends -y \
        xvfb \
        xauth; \
    \
    # Winetricks dependencies
    apt-get install --no-install-recommends -y \
        cabextract \
        unzip; \
    \
    # Cleanup
    apt-get purge -y --auto-remove gnupg; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* /usr/share/man/* /usr/share/info/*

# ----------------------------
# Winetricks (pinned release)
# ----------------------------
RUN set -eux; \
    curl -fsSL "https://raw.githubusercontent.com/Winetricks/winetricks/${WINETRICKS_VERSION}/src/winetricks" \
      -o /usr/bin/winetricks; \
    chmod +x /usr/bin/winetricks

# ----------------------------
# Launcher + LANCommander hooks
# ----------------------------
COPY Scripts/wine-run /usr/local/bin/wine-run
RUN chmod +x /usr/local/bin/wine-run

COPY Hooks/ "${BASE_HOOKS}/"

VOLUME ["/config"]

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
