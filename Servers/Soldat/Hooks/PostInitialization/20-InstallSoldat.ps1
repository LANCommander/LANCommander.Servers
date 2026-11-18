#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Install the dedicated server from SOLDAT_SERVER_URL (a zip with soldatserver at its root or in
# one subfolder) into Server/. Reinstalls when SOLDAT_SERVER_URL changes; the URL of the installed
# package is kept in Server/.soldat-server-url. Files already in Server/ are overwritten by the
# package, so put your own soldat.ini, mapslist.txt, maps and scripts in Overlay/.

Invoke-Hook "PreInstallSoldat"

$exe    = Join-Path $Env:SERVER_DIR 'soldatserver'
$marker = Join-Path $Env:SERVER_DIR '.soldat-server-url'
$installed = if (Test-Path -Path $marker) { (Get-Content -Path $marker -Raw).Trim() }

if ((Test-Path -Path $exe) -and (-not $Env:SOLDAT_SERVER_URL -or $installed -eq $Env:SOLDAT_SERVER_URL -or -not $installed)) {
    Write-Log "Soldat server found in $Env:SERVER_DIR"
} elseif (-not $Env:SOLDAT_SERVER_URL) {
    Write-Log -Level Error "soldatserver not found in $Env:SERVER_DIR and SOLDAT_SERVER_URL is empty"
} else {
    Write-Log "Downloading Soldat server from $Env:SOLDAT_SERVER_URL"

    $file    = '/tmp/soldat-server.zip'
    $extract = '/tmp/soldat-server'

    curl -fsSL --retry 3 --output $file "$Env:SOLDAT_SERVER_URL"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:SOLDAT_SERVER_URL" }

    if ($Env:SOLDAT_SERVER_SHA256) {
        $hash = (Get-FileHash -Path $file -Algorithm SHA256).Hash
        if ($hash -ne $Env:SOLDAT_SERVER_SHA256) {
            Remove-Item -Force -Path $file
            throw "SHA256 mismatch for $Env:SOLDAT_SERVER_URL`: got $hash, expected $Env:SOLDAT_SERVER_SHA256"
        }
    }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue
    unzip -q -o $file -d $extract
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $file" }

    $root = Get-ChildItem -Path $extract -Filter 'soldatserver' -Recurse -File -Depth 2 |
        Select-Object -First 1 -ExpandProperty Directory
    if (-not $root) { throw "soldatserver not found in $Env:SOLDAT_SERVER_URL" }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    cp -a "$($root.FullName)/." "$Env:SERVER_DIR/"
    if ($LASTEXITCODE -ne 0) { throw "Could not copy the server into $Env:SERVER_DIR" }

    Remove-Item -Recurse -Force -Path $file, $extract

    chmod +x $exe
    Set-Content -Path $marker -Value $Env:SOLDAT_SERVER_URL
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

    Write-Log "Soldat server installed"
}

Invoke-Hook "PostInstallSoldat"

Set-Location $Env:SERVER_ROOT
