#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Wolfenstein (2009) has no stand-alone server download: the dedicated server is Wolf2MPLite.exe in
# the game's MP folder. Use an installed MP folder in /config/Server, or extract it from a zip of
# the game (WOLF_ARCHIVE, a .zip in /config, or WOLF_ARCHIVE_URL). The zip can hold the whole game
# (MP/ is taken from it, SP/ is skipped) or just the MP folder's contents.

Invoke-Hook "PreInstallWolfenstein"

$exe = Join-Path $Env:SERVER_DIR 'Wolf2MPLite.exe'

# The path of Wolf2MPLite.exe inside a zip, or $null
function Get-ServerPath([string] $Zip) {
    $entry = unzip -Z1 $Zip 2>$null | Where-Object { $_ -match '(^|/)Wolf2MPLite\.exe$' } | Select-Object -First 1
    $entry
}

function Find-Archive {
    if ($Env:WOLF_ARCHIVE) {
        if (-not (Test-Path -Path $Env:WOLF_ARCHIVE)) { throw "WOLF_ARCHIVE not found: $Env:WOLF_ARCHIVE" }
        return $Env:WOLF_ARCHIVE
    }

    if ($Env:WOLF_ARCHIVE_URL) {
        $file = '/tmp/wolfenstein.zip'
        Write-Log "Downloading the game files from $Env:WOLF_ARCHIVE_URL"
        curl -fL --retry 3 --output $file "$Env:WOLF_ARCHIVE_URL"
        if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:WOLF_ARCHIVE_URL" }
        return $file
    }

    Get-ChildItem -Path '/config' -Filter '*.zip' -File -ErrorAction SilentlyContinue |
        Where-Object { Get-ServerPath $_.FullName } |
        Select-Object -First 1 -ExpandProperty FullName
}

if (Test-Path -Path $exe) {
    Write-Log "Wolfenstein dedicated server found in $Env:SERVER_DIR"
} else {
    $archive = Find-Archive

    if (-not $archive) {
        Write-Log -Level Error "Wolf2MPLite.exe not found in $Env:SERVER_DIR. Put the game's MP folder in /config/Server, a zip of the game in /config, or set WOLF_ARCHIVE / WOLF_ARCHIVE_URL."
    } else {
        $entry = Get-ServerPath $archive
        if (-not $entry) { throw "Wolf2MPLite.exe not found in $archive; is it a zip of Wolfenstein (2009)?" }

        # Everything next to Wolf2MPLite.exe (MP/ in an installed game)
        $prefix = $entry.Substring(0, $entry.Length - 'Wolf2MPLite.exe'.Length)

        $work = '/tmp/wolfenstein'
        Remove-Item -Recurse -Force -Path $work -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $work -Force | Out-Null

        Write-Log "Extracting $($prefix ? $prefix : 'the server files') from $archive"
        # The menu videos (base/ui/textures/*.bik) are client-only
        unzip -q -o $archive "$prefix*" -x "$($prefix)base/ui/*.bik" -d $work
        if ($LASTEXITCODE -gt 1) { throw "Could not extract $archive" }

        $source = Join-Path $work $prefix
        if (-not (Test-Path -Path (Join-Path $source 'base/pak0.pk4'))) {
            throw "base/pak0.pk4 not found next to Wolf2MPLite.exe in $archive"
        }

        New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
        Get-ChildItem -Path $source -Force | Move-Item -Force -Destination $Env:SERVER_DIR
        chown -R "$($Env:UID):$($Env:GID)" $Env:SERVER_DIR

        Remove-Item -Recurse -Force -Path $work
        if ($Env:WOLF_ARCHIVE_URL -and -not $Env:WOLF_ARCHIVE) {
            Remove-Item -Force -Path $archive -ErrorAction SilentlyContinue
        }

        # The overlay was mounted before Server/ was populated, and overlayfs doesn't reliably show
        # lower-dir changes made while mounted.
        mountpoint -q $Env:SERVER_ROOT
        if ($LASTEXITCODE -eq 0) {
            umount $Env:SERVER_ROOT
            Remove-Item -Path "$Env:WORK_DIR/*" -Recurse -Force -ErrorAction SilentlyContinue
            Mount-Overlay -MountPoint $Env:SERVER_ROOT -LowerDir $Env:SERVER_DIR -UpperDir $Env:OVERLAY_DIR -WorkDir $Env:WORK_DIR -RequireEmptyWorkDir -OverlayOption "xino=on"
            Write-Log "OverlayFS remounted"
        }

        Write-Log "Wolfenstein dedicated server installed"
    }
}

Invoke-Hook "PostInstallWolfenstein"

Set-Location $Env:SERVER_ROOT
