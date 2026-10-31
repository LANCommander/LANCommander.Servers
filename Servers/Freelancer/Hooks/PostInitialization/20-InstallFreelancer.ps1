#Requires -Modules Logging
#Requires -Modules Hooks

# Freelancer is retail software with no public download. Use an existing install in /config/Server,
# or set FL_ARCHIVE_URL to a zip of the game folder (EXE/ and DATA/ at the zip root, or in a single
# top-level folder), e.g. a LANCommander archive.

Invoke-Hook "PreInstallFreelancer"

$exe = Join-Path $Env:SERVER_DIR 'EXE/FLServer.exe'

if (Test-Path -Path $exe) {
    Write-Log "Freelancer found in $Env:SERVER_DIR"
} elseif ($Env:FL_ARCHIVE_URL) {
    Write-Log "Downloading Freelancer from $Env:FL_ARCHIVE_URL"

    $zip     = '/tmp/freelancer.zip'
    $extract = '/tmp/freelancer'

    curl -fL --retry 3 --output $zip "$Env:FL_ARCHIVE_URL"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:FL_ARCHIVE_URL" }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue
    unzip -q -o $zip -d $extract
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $zip" }

    # Accept the game at the zip root or inside one top-level folder
    $root = Get-ChildItem -Path $extract -Filter 'FLServer.exe' -Recurse -File -Depth 2 |
        Where-Object { $_.Directory.Name -ieq 'EXE' } |
        Select-Object -First 1 |
        ForEach-Object { $_.Directory.Parent.FullName }
    if (-not $root) { throw "EXE/FLServer.exe not found in $Env:FL_ARCHIVE_URL" }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    Move-Item -Force -Path (Join-Path $root '*') -Destination $Env:SERVER_DIR
    chown -R "$($Env:UID):$($Env:GID)" $Env:SERVER_DIR

    Remove-Item -Recurse -Force -Path $zip, $extract

    Write-Log "Freelancer installed"
} else {
    Write-Log -Level Error "EXE/FLServer.exe not found in $Env:SERVER_DIR. Copy a Freelancer 1.1 install there or set FL_ARCHIVE_URL."
}

Invoke-Hook "PostInstallFreelancer"

Set-Location $Env:SERVER_ROOT
