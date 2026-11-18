#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Commandos: Behind Enemy Lines is retail software with no public download. The server is a
# single file from the game folder, mpserver.exe. Use one in /config/Server, or set
# COMMANDOS_ARCHIVE_URL to a zip of the game (e.g. a LANCommander archive); only mpserver.exe
# is extracted from it.

Invoke-Hook "PreInstallCommandos"

$exe = Join-Path $Env:SERVER_DIR 'mpserver.exe'

if (Test-Path -Path $exe) {
    Write-Log "mpserver.exe found in $Env:SERVER_DIR"
} elseif ($Env:COMMANDOS_ARCHIVE_URL) {
    Write-Log "Downloading Commandos: Behind Enemy Lines from $Env:COMMANDOS_ARCHIVE_URL"

    $zip     = '/tmp/commandos.zip'
    $extract = '/tmp/commandos'

    curl -fL --retry 3 --output $zip "$Env:COMMANDOS_ARCHIVE_URL"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:COMMANDOS_ARCHIVE_URL" }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue

    # mpserver.exe at the zip root or in one top-level folder, in any letter case. unzip's * also
    # matches /
    unzip -q -o -C $zip '*mpserver.exe' -d $extract
    if ($LASTEXITCODE -ne 0) { throw "mpserver.exe not found in $Env:COMMANDOS_ARCHIVE_URL" }

    $found = Get-ChildItem -Path $extract -Recurse -File -Depth 1 |
        Where-Object { $_.Name -ieq 'mpserver.exe' } |
        Sort-Object { $_.FullName.Length } |
        Select-Object -First 1
    if (-not $found) { throw "mpserver.exe not found in $Env:COMMANDOS_ARCHIVE_URL" }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    Move-Item -Force -Path $found.FullName -Destination $exe
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

    Write-Log "mpserver.exe installed"
} else {
    Write-Log -Level Error "mpserver.exe not found in $Env:SERVER_DIR. Copy it from the game folder or set COMMANDOS_ARCHIVE_URL."
}

Invoke-Hook "PostInstallCommandos"

Set-Location $Env:SERVER_ROOT
