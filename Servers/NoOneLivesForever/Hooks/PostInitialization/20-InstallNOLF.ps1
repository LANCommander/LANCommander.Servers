#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# No One Lives Forever is retail software with no public download. Use an existing install in
# /config/Server, or set NOLF_ARCHIVE_URL to a zip of the game folder (at the zip root or in a
# single top-level folder), e.g. a LANCommander archive. file:// URLs work too.

Invoke-Hook "PreInstallNOLF"

$exe = Join-Path $Env:SERVER_DIR 'NolfServ.exe'

if (Test-Path -Path $exe) {
    Write-Log "No One Lives Forever found in $Env:SERVER_DIR"
} elseif ($Env:NOLF_ARCHIVE_URL) {
    Write-Log "Downloading No One Lives Forever from $Env:NOLF_ARCHIVE_URL"

    $zip     = '/tmp/nolf.zip'
    $extract = '/tmp/nolf'

    curl -fL --retry 3 --output $zip "$Env:NOLF_ARCHIVE_URL"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:NOLF_ARCHIVE_URL" }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue
    unzip -q -o $zip -d $extract
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $zip" }

    # Accept the game at the zip root or inside one top-level folder
    $root = Get-ChildItem -Path $extract -Filter 'NolfServ.exe' -Recurse -File -Depth 1 |
        Select-Object -First 1 -ExpandProperty Directory
    if (-not $root) { throw "NolfServ.exe not found in $Env:NOLF_ARCHIVE_URL" }

    # The server doesn't need the intro movies or the online registration tool
    foreach ($skip in @('Movies', 'EReg')) {
        Get-ChildItem -Path $root.FullName -Directory | Where-Object { $_.Name -ieq $skip } |
            Remove-Item -Recurse -Force
    }

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

    Write-Log "No One Lives Forever installed"
} else {
    Write-Log -Level Error "NolfServ.exe not found in $Env:SERVER_DIR. Copy a No One Lives Forever install there or set NOLF_ARCHIVE_URL."
}

Invoke-Hook "PostInstallNOLF"

Set-Location $Env:SERVER_ROOT
