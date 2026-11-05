#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Global Operations is retail software with no public download. Use an existing install in
# /config/Server, or set GO_ARCHIVE_URL to a zip of the game folder (goserver.exe at the zip
# root or in a single top-level folder), e.g. a LANCommander archive.

Invoke-Hook "PreInstallGlobalOps"

$exe = Join-Path $Env:SERVER_DIR 'goserver.exe'

if (Test-Path -Path $exe) {
    Write-Log "Global Operations found in $Env:SERVER_DIR"
} elseif ($Env:GO_ARCHIVE_URL) {
    Write-Log "Downloading Global Operations from $Env:GO_ARCHIVE_URL"

    $zip     = '/tmp/globalops.zip'
    $extract = '/tmp/globalops'

    curl -fL --retry 3 --output $zip "$Env:GO_ARCHIVE_URL"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:GO_ARCHIVE_URL" }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue
    unzip -q -o $zip -d $extract
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $zip" }

    # Accept the game at the zip root or inside one top-level folder
    $root = Get-ChildItem -Path $extract -Filter 'goserver.exe' -Recurse -File -Depth 1 |
        Select-Object -First 1 -ExpandProperty DirectoryName
    if (-not $root) { throw "goserver.exe not found in $Env:GO_ARCHIVE_URL" }

    # The server never plays the intro movie, and Support/ is the retail installer's tools
    Remove-Item -Force -Path (Join-Path $root 'GO.bik') -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force -Path (Join-Path $root 'Support') -ErrorAction SilentlyContinue

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

    Write-Log "Global Operations installed"
} else {
    Write-Log -Level Error "goserver.exe not found in $Env:SERVER_DIR. Copy a Global Operations 4.0a install there or set GO_ARCHIVE_URL."
}

Invoke-Hook "PostInstallGlobalOps"

Set-Location $Env:SERVER_ROOT
