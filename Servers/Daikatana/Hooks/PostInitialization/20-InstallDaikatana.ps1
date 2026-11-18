#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Daikatana isn't freely downloadable. Use an existing v1.3 install in /config/Server, or set
# DAIKATANA_ARCHIVE_URL to a zip of the game folder, e.g. a LANCommander archive. The shallowest
# folder holding dk_ded.exe and data/ is used. The music, the intro movie player and debug symbols
# aren't needed by the server and are left out.

Invoke-Hook "PreInstallDaikatana"

$exe = Join-Path $Env:SERVER_DIR 'dk_ded.exe'

if (Test-Path -Path $exe) {
    Write-Log "Daikatana found in $Env:SERVER_DIR"
} elseif ($Env:DAIKATANA_ARCHIVE_URL) {
    Write-Log "Downloading Daikatana from $Env:DAIKATANA_ARCHIVE_URL"

    $zip     = '/tmp/daikatana.zip'
    $extract = '/tmp/daikatana'

    curl -fL --retry 3 --output $zip "$Env:DAIKATANA_ARCHIVE_URL"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:DAIKATANA_ARCHIVE_URL" }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue
    unzip -q -o $zip -d $extract -x '*data/music/*' '*Intro.exe' '*.pdb'
    # unzip exits 11 when an -x pattern matches nothing
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 11) { throw "Could not extract $zip" }

    $root = Get-ChildItem -Path $extract -Filter 'dk_ded.exe' -Recurse -File -Depth 3 |
        Where-Object { Test-Path (Join-Path $_.DirectoryName 'data') } |
        Sort-Object { $_.FullName.Length } |
        Select-Object -First 1 -ExpandProperty Directory
    if (-not $root) { throw "dk_ded.exe not found in $Env:DAIKATANA_ARCHIVE_URL" }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    Get-ChildItem -Path $root.FullName -Force | Move-Item -Force -Destination $Env:SERVER_DIR

    # Zips made on Windows can carry unusable Unix modes, which leave the paks unreadable
    chmod -R 'u+rwX,go+rX' $Env:SERVER_DIR
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

    Write-Log "Daikatana installed"
} else {
    Write-Log -Level Error "dk_ded.exe not found in $Env:SERVER_DIR. Copy a Daikatana v1.3 install there or set DAIKATANA_ARCHIVE_URL."
}

Invoke-Hook "PostInstallDaikatana"

Set-Location $Env:SERVER_ROOT
