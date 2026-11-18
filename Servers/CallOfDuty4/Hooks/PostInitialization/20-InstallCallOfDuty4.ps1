#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Install the Linux dedicated server from COD4_SERVER_URL (a .tar.xz/.tar.gz/.tar.bz2/.zip with
# cod4_lnxded at its root) into Server/, next to the retail game data. Reinstalls when
# COD4_SERVER_URL changes; the URL of the installed package is kept in Server/.cod4-server-url.

Invoke-Hook "PreInstallCallOfDuty4"

$exe    = Join-Path $Env:SERVER_DIR 'cod4_lnxded'
$marker = Join-Path $Env:SERVER_DIR '.cod4-server-url'
$installed = if (Test-Path -Path $marker) { (Get-Content -Path $marker -Raw).Trim() }

if ((Test-Path -Path $exe) -and (-not $Env:COD4_SERVER_URL -or $installed -eq $Env:COD4_SERVER_URL -or -not $installed)) {
    Write-Log "Call of Duty 4 server found in $Env:SERVER_DIR"
} elseif (-not $Env:COD4_SERVER_URL) {
    Write-Log -Level Error "cod4_lnxded not found in $Env:SERVER_DIR and COD4_SERVER_URL is empty"
} else {
    Write-Log "Downloading Call of Duty 4 server from $Env:COD4_SERVER_URL"

    $file = '/tmp/cod4-server' + [System.IO.Path]::GetExtension(([uri] $Env:COD4_SERVER_URL).AbsolutePath)

    curl -fsSL --retry 3 --output $file "$Env:COD4_SERVER_URL"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Env:COD4_SERVER_URL" }

    if ($Env:COD4_SERVER_SHA256) {
        $hash = (Get-FileHash -Path $file -Algorithm SHA256).Hash
        if ($hash -ne $Env:COD4_SERVER_SHA256) {
            Remove-Item -Force -Path $file
            throw "SHA256 mismatch for $Env:COD4_SERVER_URL`: got $hash, expected $Env:COD4_SERVER_SHA256"
        }
    }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null

    if ($file.EndsWith('.zip')) {
        unzip -q -o $file -d $Env:SERVER_DIR
    } else {
        tar -xf $file -C $Env:SERVER_DIR --no-same-owner
    }
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $file" }

    Remove-Item -Force -Path $file

    if (-not (Test-Path -Path $exe)) { throw "cod4_lnxded not found in $Env:COD4_SERVER_URL" }

    chmod +x $exe
    Set-Content -Path $marker -Value $Env:COD4_SERVER_URL
    # Only the files the package added: a recursive chown of Server/ would touch the whole game
    chown "$($Env:UID):$($Env:GID)" $exe $marker

    # The overlay was mounted before Server/ was populated, and overlayfs doesn't reliably show
    # lower-dir changes made while mounted.
    mountpoint -q $Env:SERVER_ROOT
    if ($LASTEXITCODE -eq 0) {
        umount $Env:SERVER_ROOT
        Remove-Item -Path "$Env:WORK_DIR/*" -Recurse -Force -ErrorAction SilentlyContinue
        Mount-Overlay -MountPoint $Env:SERVER_ROOT -LowerDir $Env:SERVER_DIR -UpperDir $Env:OVERLAY_DIR -WorkDir $Env:WORK_DIR -RequireEmptyWorkDir -OverlayOption "xino=on"
        Write-Log "OverlayFS remounted"
    }

    Write-Log "Call of Duty 4 server installed"
}

Invoke-Hook "PostInstallCallOfDuty4"

Set-Location $Env:SERVER_ROOT
