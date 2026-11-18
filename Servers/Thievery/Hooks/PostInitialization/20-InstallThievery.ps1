#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Thievery is a mod for Unreal Tournament (1999). The server needs a UT 436 install with Thievery
# 1.7.1 extracted on top of it. Use an existing install in /config/Server, or set
# THIEVERY_UT_ARCHIVE_URL to a zip of the UT folder and THIEVERY_ARCHIVE_URL to a zip of the
# Thievery files (System/ and Thievery/), e.g. LANCommander archives; file:// URLs are read in
# place. Each part is installed only when it's missing (System/UCC.exe, System/ThieveryMod.u),
# and the folder holding its System/ is used, so it may sit in a subfolder of the zip. Help/,
# Manual/ and NetGamesUSA/ aren't needed by the server and are left out.

Invoke-Hook "PreInstallThievery"

$system   = Join-Path $Env:SERVER_DIR 'System'
$installed = $false

function Install-Archive([string] $Name, [string] $Url, [string] $Marker) {
    $extract  = "/tmp/thievery-extract"
    $download = $null

    if ($Url.StartsWith('file://')) {
        $zip = [System.Uri]::UnescapeDataString($Url.Substring(7))
        if (-not (Test-Path -Path $zip)) { throw "Archive not found: $zip" }
        Write-Log "Extracting $Name from $zip"
    } else {
        $zip = $download = '/tmp/thievery-download.zip'
        Write-Log "Downloading $Name from $Url"

        curl -fL --retry 3 --output $zip "$Url"
        if ($LASTEXITCODE -ne 0) { throw "Download failed: $Url" }
    }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue
    # unzip's * also matches /, so these cover the folders at the root and in a subfolder. It warns
    # about patterns that match nothing (exit code 1), which isn't worth logging.
    unzip -q -o $zip -d $extract -x '*Help/*' '*Manual/*' '*NetGamesUSA*' 2>&1 |
        Where-Object { "$_" -notmatch 'excluded filename not matched' } |
        ForEach-Object { Write-Log -Level Warning "unzip: $_" }
    if ($LASTEXITCODE -gt 1) { throw "Could not extract $zip" }

    $root = Get-ChildItem -Path $extract -Filter $Marker -Recurse -File -Depth 3 |
        Where-Object { $_.Directory.Name -ieq 'System' } |
        Select-Object -First 1 -ExpandProperty Directory
    if (-not $root) { throw "System/$Marker not found in $Url" }

    # Merge into Server/: the Thievery zip adds to the UT folder's System/
    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    cp -a "$($root.Parent.FullName)/." "$Env:SERVER_DIR/"
    if ($LASTEXITCODE -ne 0) { throw "Could not copy $Name into $Env:SERVER_DIR" }

    Remove-Item -Recurse -Force -Path $extract
    if ($download) { Remove-Item -Force -Path $download }

    Write-Log "$Name installed"
}

if (Test-Path -Path (Join-Path $system 'UCC.exe')) {
    Write-Log "Unreal Tournament found in $Env:SERVER_DIR"
} elseif ($Env:THIEVERY_UT_ARCHIVE_URL) {
    Install-Archive 'Unreal Tournament' $Env:THIEVERY_UT_ARCHIVE_URL 'UCC.exe'
    $installed = $true
} else {
    Write-Log -Level Error "System/UCC.exe not found in $Env:SERVER_DIR. Copy an Unreal Tournament 436 install there or set THIEVERY_UT_ARCHIVE_URL."
}

if (Test-Path -Path (Join-Path $system 'ThieveryMod.u')) {
    Write-Log "Thievery found in $Env:SERVER_DIR"
} elseif ($Env:THIEVERY_ARCHIVE_URL) {
    Install-Archive 'Thievery' $Env:THIEVERY_ARCHIVE_URL 'ThieveryMod.u'
    $installed = $true
} else {
    Write-Log -Level Error "System/ThieveryMod.u not found in $Env:SERVER_DIR. Extract Thievery 1.7.1 over the UT install or set THIEVERY_ARCHIVE_URL."
}

if ($installed) {
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
}

Invoke-Hook "PostInstallThievery"

Set-Location $Env:SERVER_ROOT
