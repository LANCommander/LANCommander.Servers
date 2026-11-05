#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Kiss: Psycho Circus - The Nightmare Child is retail software with no public download. Use an
# existing (1.13 patched) install in /config/Server, or set KPC_ARCHIVE_URL to a zip of the game
# folder (Dedicated.exe at the zip root, or in a single top-level folder), e.g. a LANCommander
# archive.

Invoke-Hook "PreInstallKissPsychoCircus"

$exe = Join-Path $Env:SERVER_DIR 'Dedicated.exe'

if (Test-Path -Path $exe) {
    Write-Log "Kiss: Psycho Circus found in $Env:SERVER_DIR"
} elseif ($Env:KPC_ARCHIVE_URL) {
    Write-Log "Downloading Kiss: Psycho Circus from $Env:KPC_ARCHIVE_URL"

    $zip     = '/tmp/kisspsychocircus.zip'
    $extract = '/tmp/kisspsychocircus'

    curl -fL --retry 3 --output $zip "$Env:KPC_ARCHIVE_URL"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:KPC_ARCHIVE_URL" }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue
    # The server doesn't need the cutscenes or the soundtrack
    unzip -q -o $zip -d $extract -x 'Movies/*' 'Music/*'
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $zip" }

    # Accept the game at the zip root or inside one top-level folder
    $game = Get-ChildItem -Path $extract -Filter 'Dedicated.exe' -Recurse -File -Depth 1 |
        Select-Object -First 1 -ExpandProperty Directory
    if (-not $game) { throw "Dedicated.exe not found in $Env:KPC_ARCHIVE_URL" }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    Move-Item -Force -Path (Join-Path $game.FullName '*') -Destination $Env:SERVER_DIR
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

    Write-Log "Kiss: Psycho Circus installed"
} else {
    Write-Log -Level Error "Dedicated.exe not found in $Env:SERVER_DIR. Copy a Kiss: Psycho Circus 1.13 install there or set KPC_ARCHIVE_URL."
}

if ((Test-Path -Path $exe) -and -not (Get-ChildItem -Path $Env:SERVER_DIR -File | Where-Object Name -ieq 'psycho.rez')) {
    Write-Log -Level Error "PSYCHO.REZ not found in $Env:SERVER_DIR; Dedicated.exe needs a full install"
}

Invoke-Hook "PostInstallKissPsychoCircus"

Set-Location $Env:SERVER_ROOT
