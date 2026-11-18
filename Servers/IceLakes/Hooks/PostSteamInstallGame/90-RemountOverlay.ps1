#Requires -Modules Logging
#Requires -Modules OverlayFS

# The overlay is mounted before SteamCMD populates Server/, and overlayfs doesn't reliably
# show lower-dir changes made while it is mounted. On a first install the server would
# start from an empty Merged/ (START_EXE not found). Hand the files to the server user and
# remount so Merged/ shows the installed game.

if ((id -u) -ne "0") {
    return
}

chown -R "${Env:USER}:${Env:GROUP}" $Env:SERVER_DIR
if ($LASTEXITCODE -ne 0) { throw "Failed to set ownership of $Env:SERVER_DIR" }

mountpoint -q $Env:SERVER_ROOT
if ($LASTEXITCODE -ne 0) {
    return
}

umount $Env:SERVER_ROOT
if ($LASTEXITCODE -ne 0) { throw "Failed to unmount $Env:SERVER_ROOT" }

Remove-Item -Path "$Env:WORK_DIR/*" -Recurse -Force -ErrorAction SilentlyContinue

try {
    Mount-Overlay -MountPoint $Env:SERVER_ROOT -LowerDir $Env:SERVER_DIR -UpperDir $Env:OVERLAY_DIR -WorkDir $Env:WORK_DIR -RequireEmptyWorkDir -OverlayOption "xino=on"
    Write-Log "OverlayFS remounted"
} catch {
    Write-Log -Level Error "Failed to remount OverlayFS: $($_.Exception.Message)"
}
