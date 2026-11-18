#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Install MHServerEmu into Server/ and bring in the game data it needs from the client.
#
# The image carries one MHServerEmu release in /opt/mhserveremu (the server plus the web files,
# htdocs/). It's copied into Server/ on first start and whenever the image brings a different
# version; the installed version is kept in Server/.mhserveremu-version. A Server/ with
# MHServerEmu.dll but no version marker (a build you copied in yourself) is left alone.
#
# When a different version replaces the installed one, Server/ is emptied first, and the copies of
# the old version's Config.ini, htdocs/SiteConfig.xml and htdocs/news/index.html in Overlay/ are
# renamed to <name>.bak-<old version>, so the new version's files show through. Accounts
# (Data/Account.db and its backups), the client data files and everything else in Overlay/ are kept.
#
# MHServerEmu loads the game's prototypes from the client's Data/Game/Calligraphy.sip and
# mu_cdata.sip (Marvel Heroes Omega 1.52.0.1700). They aren't in the image: put them, or a whole
# client install, in MH_CLIENT_DATA_DIR (/config/ClientData by default). They're copied into
# Data/Game/ (so into Overlay/Data/Game/) when missing or when the ones in MH_CLIENT_DATA_DIR
# differ in size or date. You can also put them in Overlay/Data/Game/ yourself.

Invoke-Hook "PreInstallMHServerEmu"

$source       = '/opt/mhserveremu'
$imageVersion = (Get-Content -Path (Join-Path $source '.mhserveremu-version') -Raw).Trim()
$dll          = Join-Path $Env:SERVER_DIR 'MHServerEmu.dll'
$verMarker    = Join-Path $Env:SERVER_DIR '.mhserveremu-version'
$installed    = if (Test-Path -Path $verMarker) { (Get-Content -Path $verMarker -Raw).Trim() }

if ((Test-Path -Path $dll) -and -not $installed) {
    Write-Log "MHServerEmu found in $Env:SERVER_DIR without a version marker; leaving it alone"
} elseif ((Test-Path -Path $dll) -and $installed -eq $imageVersion) {
    Write-Log "MHServerEmu $installed found in $Env:SERVER_DIR"
} else {
    Write-Log "Installing MHServerEmu $imageVersion into $Env:SERVER_DIR"

    # Change Server/ and Overlay/ with the overlay unmounted; overlayfs doesn't reliably show
    # changes to its layers made while mounted
    mountpoint -q $Env:SERVER_ROOT
    $wasMounted = $LASTEXITCODE -eq 0
    if ($wasMounted) { umount $Env:SERVER_ROOT }

    if ($installed) {
        $suffix = ".bak-$installed"
        foreach ($relative in 'Config.ini', 'htdocs/SiteConfig.xml', 'htdocs/news/index.html') {
            $copy = Join-Path $Env:OVERLAY_DIR $relative
            if (Test-Path -Path $copy -PathType Leaf) {
                Move-Item -Force -Path $copy -Destination "$copy$suffix"
                Write-Log -Level Warning "Overlay/$relative belonged to MHServerEmu $installed; renamed to $relative$suffix"
            }
        }
        Get-ChildItem -Path $Env:SERVER_DIR -Force | Remove-Item -Recurse -Force
    }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    cp -a "$source/." "$Env:SERVER_DIR/"
    if ($LASTEXITCODE -ne 0) { throw "Could not copy MHServerEmu into $Env:SERVER_DIR" }
    chown -R "$($Env:UID):$($Env:GID)" $Env:SERVER_DIR

    if ($wasMounted) {
        Remove-Item -Path "$Env:WORK_DIR/*" -Recurse -Force -ErrorAction SilentlyContinue
        Mount-Overlay -MountPoint $Env:SERVER_ROOT -LowerDir $Env:SERVER_DIR -UpperDir $Env:OVERLAY_DIR -WorkDir $Env:WORK_DIR -RequireEmptyWorkDir -OverlayOption "xino=on"
        Write-Log "OverlayFS remounted"
    }

    Write-Log "MHServerEmu $imageVersion installed into $Env:SERVER_DIR"
}

# ---- Client game data -----------------------------------------------------------------------

$gameDir = Join-Path $Env:SERVER_ROOT 'Data/Game'
New-Item -ItemType Directory -Path $gameDir -Force | Out-Null
$clientDir = $Env:MH_CLIENT_DATA_DIR

foreach ($name in 'Calligraphy.sip', 'mu_cdata.sip') {
    $target = Join-Path $gameDir $name
    $found  = $null
    if ($clientDir -and (Test-Path -Path $clientDir -PathType Container)) {
        # The file itself, a client's Data/Game/, or a whole client install
        $found = Get-ChildItem -Path $clientDir -Filter $name -Recurse -File -Depth 4 -ErrorAction SilentlyContinue |
            Sort-Object { $_.FullName.Length } | Select-Object -First 1
    }

    if ($found) {
        $current = Get-Item -Path $target -ErrorAction SilentlyContinue
        if (-not $current -or $current.Length -ne $found.Length -or $current.LastWriteTimeUtc -ne $found.LastWriteTimeUtc) {
            cp -p $found.FullName $target
            if ($LASTEXITCODE -ne 0) { throw "Could not copy $($found.FullName) to $target" }
            chown "$($Env:UID):$($Env:GID)" $target
            Write-Log "Copied $($found.FullName) to Data/Game/$name"
        }
    }

    if (-not (Test-Path -Path $target)) {
        Write-Log -Level Error "Data/Game/$name not found. Copy it from a Marvel Heroes Omega 1.52.0.1700 client's Data/Game/ into $clientDir (or Overlay/Data/Game/)"
    }
}

Invoke-Hook "PostInstallMHServerEmu"

Set-Location $Env:SERVER_ROOT
