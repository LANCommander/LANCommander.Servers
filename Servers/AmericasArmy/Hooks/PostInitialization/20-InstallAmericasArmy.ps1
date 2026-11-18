#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# America's Army 2.x is no longer distributed. Use an existing install in /config/Server, or set
# AA_ARCHIVE_URL to a zip of the game folder, e.g. a LANCommander archive. The shallowest folder
# holding System/Server.exe is used (some installs carry a stray nested "America's Army/" copy).

Invoke-Hook "PreInstallAmericasArmy"

$server = Join-Path $Env:SERVER_DIR 'System/Server.exe'

if (Test-Path -Path $server) {
    Write-Log "America's Army found in $Env:SERVER_DIR"
} elseif ($Env:AA_ARCHIVE_URL) {
    Write-Log "Downloading America's Army from $Env:AA_ARCHIVE_URL"

    $zip     = '/tmp/americasarmy.zip'
    $extract = '/tmp/americasarmy'

    curl -fL --retry 3 --output $zip "$Env:AA_ARCHIVE_URL"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:AA_ARCHIVE_URL" }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue
    unzip -q -o $zip -d $extract
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $zip" }

    $root = Get-ChildItem -Path $extract -Filter 'Server.exe' -Recurse -File -Depth 3 |
        Where-Object { $_.Directory.Name -eq 'System' -and (Test-Path (Join-Path $_.DirectoryName 'AGP.u')) } |
        Sort-Object { $_.FullName.Length } |
        Select-Object -First 1 -ExpandProperty Directory
    if (-not $root) { throw "System/Server.exe not found in $Env:AA_ARCHIVE_URL" }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    Get-ChildItem -Path $root.Parent.FullName |
        Where-Object { $_.Name -notin @("America's Army", 'BACKUP') } |
        Move-Item -Force -Destination $Env:SERVER_DIR
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

    Write-Log "America's Army installed"
} else {
    Write-Log -Level Error "System/Server.exe not found in $Env:SERVER_DIR. Copy an America's Army install there or set AA_ARCHIVE_URL."
}

Invoke-Hook "PostInstallAmericasArmy"

Set-Location $Env:SERVER_ROOT
