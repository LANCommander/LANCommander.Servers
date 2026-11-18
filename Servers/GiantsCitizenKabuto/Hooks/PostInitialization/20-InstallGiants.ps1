#Requires -Modules Logging
#Requires -Modules Hooks

# Giants: Citizen Kabuto is retail software with no public download. Use an existing install with the
# 1.5 community patch (it adds GiantsDedicated.exe) in /config/Server, or set GIANTS_ARCHIVE_URL to a
# zip of the game folder (GiantsDedicated.exe at the zip root, or in a single top-level folder), e.g.
# a LANCommander archive.

Invoke-Hook "PreInstallGiants"

$exe = Join-Path $Env:SERVER_DIR 'GiantsDedicated.exe'

if (Test-Path -Path $exe) {
    Write-Log "Giants found in $Env:SERVER_DIR"
} elseif ($Env:GIANTS_ARCHIVE_URL) {
    Write-Log "Downloading Giants from $Env:GIANTS_ARCHIVE_URL"

    $zip     = '/tmp/giants.zip'
    $extract = '/tmp/giants'

    curl -fL --retry 3 --output $zip "$Env:GIANTS_ARCHIVE_URL"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:GIANTS_ARCHIVE_URL" }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue
    unzip -q -o $zip -d $extract
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $zip" }

    # Accept the game at the zip root or inside one top-level folder
    $root = Get-ChildItem -Path $extract -Filter 'GiantsDedicated.exe' -Recurse -File -Depth 1 |
        Select-Object -First 1 -ExpandProperty DirectoryName
    if (-not $root) { throw "GiantsDedicated.exe not found in $Env:GIANTS_ARCHIVE_URL" }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    Move-Item -Force -Path (Join-Path $root '*') -Destination $Env:SERVER_DIR
    chown -R "$($Env:UID):$($Env:GID)" $Env:SERVER_DIR

    Remove-Item -Recurse -Force -Path $zip, $extract

    Write-Log "Giants installed"
} else {
    Write-Log -Level Error "GiantsDedicated.exe not found in $Env:SERVER_DIR. Copy a Giants: Citizen Kabuto 1.5 install there or set GIANTS_ARCHIVE_URL."
}

Invoke-Hook "PostInstallGiants"

Set-Location $Env:SERVER_ROOT
