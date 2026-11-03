#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Legends of Might and Magic is retail software with no public download. Use an existing install in
# /config/Server, or set LOMM_ARCHIVE_URL to a zip of the game folder (LegendServ.exe at the zip
# root or in a single top-level folder), e.g. a LANCommander archive.

Invoke-Hook "PreInstallLegends"

$exe = Join-Path $Env:SERVER_DIR 'LegendServ.exe'

if (Test-Path -Path $exe) {
    Write-Log "Legends of Might and Magic found in $Env:SERVER_DIR"
} elseif ($Env:LOMM_ARCHIVE_URL) {
    Write-Log "Downloading Legends of Might and Magic from $Env:LOMM_ARCHIVE_URL"

    $zip     = '/tmp/lomm.zip'
    $extract = '/tmp/lomm'

    curl -fL --retry 3 --output $zip "$Env:LOMM_ARCHIVE_URL"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:LOMM_ARCHIVE_URL" }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue
    unzip -q -o $zip -d $extract
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $zip" }

    # Accept the game at the zip root or inside one top-level folder
    $root = Get-ChildItem -Path $extract -Filter 'LegendServ.exe' -Recurse -File -Depth 1 |
        Select-Object -First 1 -ExpandProperty DirectoryName
    if (-not $root) { throw "LegendServ.exe not found in $Env:LOMM_ARCHIVE_URL" }

    # The server never plays the intro movies or the music (about 60 MB)
    foreach ($dir in 'Movies', 'Music') {
        Remove-Item -Recurse -Force -Path (Join-Path $root $dir) -ErrorAction SilentlyContinue
    }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    Move-Item -Force -Path (Join-Path $root '*') -Destination $Env:SERVER_DIR
    chown -R "$($Env:UID):$($Env:GID)" $Env:SERVER_DIR

    Remove-Item -Recurse -Force -Path $zip, $extract

    # The overlay was mounted before Server/ was populated, and overlayfs doesn't reliably show
    # lower-dir changes made while mounted.
    mountpoint -q $Env:SERVER_ROOT
    if ($LASTEXITCODE -eq 0) {
        umount $Env:SERVER_ROOT
        Remove-Item -Path "$Env:WORK_DIR/*" -Recurse -Force -ErrorAction SilentlyContinue
        Mount-Overlay -MountPoint $Env:SERVER_ROOT -LowerDir $Env:SERVER_DIR -UpperDir $Env:OVERLAY_DIR -WorkDir $Env:WORK_DIR -RequireEmptyWorkDir -OverlayOption "xino=on"
        Write-Log "OverlayFS remounted"
    }

    Write-Log "Legends of Might and Magic installed"
} else {
    Write-Log -Level Error "LegendServ.exe not found in $Env:SERVER_DIR. Copy a Legends of Might and Magic 1.1 install there or set LOMM_ARCHIVE_URL."
}

Invoke-Hook "PostInstallLegends"

Set-Location $Env:SERVER_ROOT
