#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Red Faction is retail software with no public download. Use an existing install in
# /config/Server, or set RF_ARCHIVE_URL to a zip of the game folder (at the zip root, or in a
# single top-level folder), e.g. a LANCommander archive. Alpine Faction comes with the image and
# is copied into the game folder (through the merged view, so it lands in Overlay/).

Invoke-Hook "PreInstallRedFaction"

$hasGame = { (Test-Path (Join-Path $Env:SERVER_DIR 'RF.exe')) -or (Test-Path (Join-Path $Env:SERVER_DIR 'RF_120na.exe')) }

if (& $hasGame) {
    Write-Log "Red Faction found in $Env:SERVER_DIR"
} elseif ($Env:RF_ARCHIVE_URL) {
    Write-Log "Downloading Red Faction from $Env:RF_ARCHIVE_URL"

    $zip     = '/tmp/redfaction.zip'
    $extract = '/tmp/redfaction'

    curl -fL --retry 3 --output $zip "$Env:RF_ARCHIVE_URL"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:RF_ARCHIVE_URL" }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue
    Expand-Archive -Path $zip -DestinationPath $extract -Force

    # Accept the game at the zip root or inside one top-level folder
    $root = Get-ChildItem -Path $extract -Filter 'RF.exe' -Recurse -File -Depth 1 |
        Select-Object -First 1 -ExpandProperty Directory
    if (-not $root) { throw "RF.exe not found in $Env:RF_ARCHIVE_URL" }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    Move-Item -Force -Path (Join-Path $root.FullName '*') -Destination $Env:SERVER_DIR
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

    Write-Log "Red Faction installed"
} else {
    Write-Log -Level Error "RF.exe not found in $Env:SERVER_DIR. Copy a Red Faction 1.20 NA install there or set RF_ARCHIVE_URL."
}

# Copy the image's Alpine Faction files over any that differ
if ($Env:AF_INSTALL -eq 'true') {
    $copied = 0
    foreach ($src in Get-ChildItem -Path '/opt/alpinefaction' -File) {
        $dst = Join-Path $Env:SERVER_ROOT $src.Name
        if ((Test-Path $dst) -and (Get-FileHash $dst).Hash -eq (Get-FileHash $src.FullName).Hash) { continue }
        Copy-Item -Force -Path $src.FullName -Destination $dst
        chown "$($Env:UID):$($Env:GID)" $dst
        $copied++
    }
    Write-Log "Alpine Faction $Env:AF_VERSION in place ($copied files updated)"
}

Invoke-Hook "PostInstallRedFaction"

Set-Location $Env:SERVER_ROOT
