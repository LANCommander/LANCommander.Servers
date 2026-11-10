#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Copy the FPC Atomic server baked into the image (ATOMIC_DIST: atomic_server, libai.so,
# libai_smart.so, data/maps/*/info.txt) into Server/. Reinstalls when ATOMIC_VERSION changes; the
# installed version is kept in Server/.atomic-version. Files in Server/ are overwritten on a
# reinstall, so put your own changes (extra maps, ai_smart.ini) in Overlay/.

Invoke-Hook "PreInstallAtomicBomberman"

$exe    = Join-Path $Env:SERVER_DIR 'atomic_server'
$marker = Join-Path $Env:SERVER_DIR '.atomic-version'
$installed = if (Test-Path -Path $marker) { (Get-Content -Path $marker -Raw).Trim() }

if ((Test-Path -Path $exe) -and $installed -eq $Env:ATOMIC_VERSION) {
    Write-Log "FPC Atomic server $installed found in $Env:SERVER_DIR"
} else {
    if (-not (Test-Path -Path (Join-Path $Env:ATOMIC_DIST 'atomic_server'))) {
        throw "atomic_server not found in $Env:ATOMIC_DIST"
    }

    if ($installed) {
        Write-Log "Updating FPC Atomic server $installed -> $Env:ATOMIC_VERSION"
    } else {
        Write-Log "Installing FPC Atomic server $Env:ATOMIC_VERSION into $Env:SERVER_DIR"
    }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    cp -a "$Env:ATOMIC_DIST/." "$Env:SERVER_DIR/"
    if ($LASTEXITCODE -ne 0) { throw "Could not copy the server into $Env:SERVER_DIR" }

    chmod +x $exe
    Set-Content -Path $marker -Value $Env:ATOMIC_VERSION
    chown -R "$($Env:UID):$($Env:GID)" $Env:SERVER_DIR

    # The overlay was mounted before Server/ was populated, and overlayfs doesn't reliably show
    # lower-dir changes made while mounted.
    mountpoint -q $Env:SERVER_ROOT
    if ($LASTEXITCODE -eq 0) {
        umount $Env:SERVER_ROOT
        Remove-Item -Path "$Env:WORK_DIR/*" -Recurse -Force -ErrorAction SilentlyContinue
        Mount-Overlay -MountPoint $Env:SERVER_ROOT -LowerDir $Env:SERVER_DIR -UpperDir $Env:OVERLAY_DIR -WorkDir $Env:WORK_DIR -RequireEmptyWorkDir -OverlayOption "xino=on"
        Write-Log "OverlayFS remounted"
    }

    Write-Log "FPC Atomic server $Env:ATOMIC_VERSION installed"
}

Invoke-Hook "PostInstallAtomicBomberman"

Set-Location $Env:SERVER_ROOT
