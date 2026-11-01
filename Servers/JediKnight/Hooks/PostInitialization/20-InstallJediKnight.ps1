#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Jedi Knight is retail software with no public download. Use an existing OpenJKDF2 install in
# /config/Server, or set JK_ARCHIVE_URL to a zip of the game folder (at the zip root or in a single
# top-level folder), e.g. a LANCommander archive.

Invoke-Hook "PreInstallJediKnight"

$exeName = if ($Env:JK_EXE) { $Env:JK_EXE } else { 'openjkdf2-64.exe' }
$exe     = Join-Path $Env:SERVER_DIR $exeName

if (Test-Path -Path $exe) {
    Write-Log "Jedi Knight found in $Env:SERVER_DIR"
} elseif ($Env:JK_ARCHIVE_URL) {
    Write-Log "Downloading Jedi Knight from $Env:JK_ARCHIVE_URL"

    $zip     = '/tmp/jediknight.zip'
    $extract = '/tmp/jediknight'

    curl -fL --retry 3 --output $zip "$Env:JK_ARCHIVE_URL"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:JK_ARCHIVE_URL" }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue
    unzip -q -o $zip -d $extract
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $zip" }

    # Accept the game at the zip root or inside one top-level folder
    $root = Get-ChildItem -Path $extract -Filter $exeName -Recurse -File -Depth 1 |
        Select-Object -First 1 -ExpandProperty Directory
    if (-not $root) { throw "$exeName not found in $Env:JK_ARCHIVE_URL" }

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

    Write-Log "Jedi Knight installed"
} else {
    Write-Log -Level Error "$exeName not found in $Env:SERVER_DIR. Copy an OpenJKDF2 Jedi Knight install there or set JK_ARCHIVE_URL."
}

Invoke-Hook "PostInstallJediKnight"

Set-Location $Env:SERVER_ROOT
