#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Rune is retail software with no public download. Use an existing install in
# /config/Server, or set RUNE_ARCHIVE_URL to a zip of the game folder, e.g. a LANCommander
# archive. The folder holding System/RuneI.u and System/UCC.exe is used, so the game may sit in a
# subfolder of the zip.

Invoke-Hook "PreInstallRune"

$ucc = Join-Path $Env:SERVER_DIR 'System/UCC.exe'

if (Test-Path -Path $ucc) {
    Write-Log "Rune found in $Env:SERVER_DIR"
} elseif ($Env:RUNE_ARCHIVE_URL) {
    Write-Log "Downloading Rune from $Env:RUNE_ARCHIVE_URL"

    $zip     = '/tmp/rune.zip'
    $extract = '/tmp/rune'

    curl -fL --retry 3 --output $zip "$Env:RUNE_ARCHIVE_URL"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:RUNE_ARCHIVE_URL" }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue
    unzip -q -o $zip -d $extract
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $zip" }

    $root = Get-ChildItem -Path $extract -Filter 'RuneI.u' -Recurse -File -Depth 3 |
        Where-Object { $_.Directory.Name -eq 'System' -and (Test-Path (Join-Path $_.DirectoryName 'UCC.exe')) } |
        Select-Object -First 1 -ExpandProperty Directory
    if (-not $root) { throw "System/RuneI.u and System/UCC.exe not found in $Env:RUNE_ARCHIVE_URL" }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    Move-Item -Force -Path (Join-Path $root.Parent.FullName '*') -Destination $Env:SERVER_DIR
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

    Write-Log "Rune installed"
} else {
    Write-Log -Level Error "System/UCC.exe not found in $Env:SERVER_DIR. Copy a Rune install there or set RUNE_ARCHIVE_URL."
}

Invoke-Hook "PostInstallRune"

Set-Location $Env:SERVER_ROOT
