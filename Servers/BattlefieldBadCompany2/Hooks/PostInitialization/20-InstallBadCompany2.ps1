#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# The Bc2emu V0.9 server files (Battlefield: Bad Company 2 R34 dedicated server with the
# emulator's dinput8.dll hook) are built into the image, in /opt/bfbc2/server. Copy them into
# /config/Server on first start, and again when the image brings a different Bc2emu release.
# A server folder that this hook didn't install (no marker file) is left alone, so you can bring
# your own server files.

Invoke-Hook "PreInstallBadCompany2"

$source  = '/opt/bfbc2/server'
$release = 'Bc2emu V0.9'
$exe     = Join-Path $Env:SERVER_DIR 'Frost.Game.Main_Win32_Final.exe'
$marker  = Join-Path $Env:SERVER_DIR '.lancommander-bc2emu'

$installed = if (Test-Path -LiteralPath $marker) { (Get-Content -LiteralPath $marker -Raw).Trim() }

if ((Test-Path -LiteralPath $exe) -and -not $installed) {
    Write-Log "Using the server files in $Env:SERVER_DIR (not installed by this image)"
} elseif ($installed -eq $release) {
    Write-Log "$release found in $Env:SERVER_DIR"
} else {
    Write-Log "Installing $release into $Env:SERVER_DIR"

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    cp -a "$source/." "$Env:SERVER_DIR/"
    if ($LASTEXITCODE -ne 0) { throw "Could not copy $source to $Env:SERVER_DIR" }

    Set-Content -LiteralPath $marker -Value $release
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

    Write-Log "$release installed"
}

Invoke-Hook "PostInstallBadCompany2"

Set-Location $Env:SERVER_ROOT
