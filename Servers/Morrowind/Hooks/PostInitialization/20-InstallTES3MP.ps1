#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Install the TES3MP server from TES3MP_SERVER_URL (a .tar.gz or .zip with tes3mp-server.x86_64 and
# server/scripts/serverCore.lua, at its root or in one subfolder) into Server/. Reinstalls when
# TES3MP_SERVER_URL changes; the URL of the installed package is kept in Server/.tes3mp-server-url.
# The source tarball and the CoreScripts' .git folder are left out. Files already in Server/ are
# overwritten by the package; the world and player data the server writes live in Overlay/ and
# are kept.

Invoke-Hook "PreInstallTES3MP"

$exe    = Join-Path $Env:SERVER_DIR 'tes3mp-server.x86_64'
$core   = Join-Path $Env:SERVER_DIR 'server/scripts/serverCore.lua'
$marker = Join-Path $Env:SERVER_DIR '.tes3mp-server-url'
$installed = if (Test-Path -Path $marker) { (Get-Content -Path $marker -Raw).Trim() }

if ((Test-Path -Path $exe) -and (Test-Path -Path $core) -and (-not $Env:TES3MP_SERVER_URL -or $installed -eq $Env:TES3MP_SERVER_URL -or -not $installed)) {
    Write-Log "TES3MP found in $Env:SERVER_DIR"
} elseif (-not $Env:TES3MP_SERVER_URL) {
    Write-Log -Level Error "tes3mp-server.x86_64 or server/scripts/serverCore.lua not found in $Env:SERVER_DIR and TES3MP_SERVER_URL is empty"
} else {
    Write-Log "Downloading TES3MP from $Env:TES3MP_SERVER_URL"

    $isZip   = $Env:TES3MP_SERVER_URL -match '\.zip($|\?)'
    $file    = if ($isZip) { '/tmp/tes3mp.zip' } else { '/tmp/tes3mp.tar.gz' }
    $extract = '/tmp/tes3mp'

    curl -fsSL --retry 3 --output $file "$Env:TES3MP_SERVER_URL"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:TES3MP_SERVER_URL" }

    if ($Env:TES3MP_SERVER_SHA256) {
        $hash = (Get-FileHash -Path $file -Algorithm SHA256).Hash
        if ($hash -ne $Env:TES3MP_SERVER_SHA256) {
            Remove-Item -Force -Path $file
            throw "SHA256 mismatch for $Env:TES3MP_SERVER_URL`: got $hash, expected $Env:TES3MP_SERVER_SHA256 (clear TES3MP_SERVER_SHA256 when installing from another package)"
        }
    }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $extract -Force | Out-Null
    if ($isZip) {
        unzip -q -o $file -d $extract -x '*source.tar.gz' '*/.git/*'
        if ($LASTEXITCODE -gt 1) { throw "Could not extract $file" }
    } else {
        # The 0.8.1 tarball ends with a lone zero block, which GNU tar warns about but extracts fine
        tar -xzf $file -C $extract --exclude='*/source.tar.gz' --exclude='*/.git' 2>&1 |
            Where-Object { $_ -notmatch 'lone zero block' } | ForEach-Object { Write-Log -Level Warning "$_" }
        if ($LASTEXITCODE -gt 1) { throw "Could not extract $file" }
    }

    $root = Get-ChildItem -Path $extract -Filter 'tes3mp-server.x86_64' -Recurse -File -Depth 2 |
        Select-Object -First 1 -ExpandProperty Directory
    if (-not $root) { throw "tes3mp-server.x86_64 not found in $Env:TES3MP_SERVER_URL" }
    if (-not (Test-Path -Path (Join-Path $root.FullName 'server/scripts/serverCore.lua'))) { throw "server/scripts/serverCore.lua not found next to tes3mp-server.x86_64 in $Env:TES3MP_SERVER_URL" }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    cp -a "$($root.FullName)/." "$Env:SERVER_DIR/"
    if ($LASTEXITCODE -ne 0) { throw "Could not copy TES3MP into $Env:SERVER_DIR" }

    Remove-Item -Recurse -Force -Path $file, $extract

    chmod -R u+rwX,go+rX $Env:SERVER_DIR
    chmod +x $exe
    Set-Content -Path $marker -Value $Env:TES3MP_SERVER_URL
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

    Write-Log "TES3MP installed into $Env:SERVER_DIR"
}

Invoke-Hook "PostInstallTES3MP"

Set-Location $Env:SERVER_ROOT
