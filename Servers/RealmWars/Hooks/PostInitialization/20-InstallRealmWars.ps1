#Requires -Modules Logging
#Requires -Modules Hooks

# Realm Wars has no maintained download. Use an existing install in /config/Server, or set
# REALMWARS_ARCHIVE_URL to a zip of the game folder (RealmWars.exe at the zip root, or in a single
# top-level folder), e.g. a LANCommander archive.

Invoke-Hook "PreInstallRealmWars"

$exe = Join-Path $Env:SERVER_DIR 'RealmWars.exe'

if (Test-Path -Path $exe) {
    Write-Log "Realm Wars found in $Env:SERVER_DIR"
} elseif ($Env:REALMWARS_ARCHIVE_URL) {
    Write-Log "Downloading Realm Wars from $Env:REALMWARS_ARCHIVE_URL"

    $zip     = '/tmp/realmwars.zip'
    $extract = '/tmp/realmwars'

    curl -fL --retry 3 --output $zip "$Env:REALMWARS_ARCHIVE_URL"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:REALMWARS_ARCHIVE_URL" }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue
    unzip -q -o $zip -d $extract
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $zip" }

    # Accept the game at the zip root or inside one top-level folder
    $root = Get-ChildItem -Path $extract -Filter 'RealmWars.exe' -Recurse -File -Depth 1 |
        Select-Object -First 1 -ExpandProperty DirectoryName
    if (-not $root) { throw "RealmWars.exe not found in $Env:REALMWARS_ARCHIVE_URL" }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    Move-Item -Force -Path (Join-Path $root '*') -Destination $Env:SERVER_DIR
    chown -R "$($Env:UID):$($Env:GID)" $Env:SERVER_DIR

    Remove-Item -Recurse -Force -Path $zip, $extract

    Write-Log "Realm Wars installed"
} else {
    Write-Log -Level Error "RealmWars.exe not found in $Env:SERVER_DIR. Copy a Realm Wars install there or set REALMWARS_ARCHIVE_URL."
}

Invoke-Hook "PostInstallRealmWars"

Set-Location $Env:SERVER_ROOT
