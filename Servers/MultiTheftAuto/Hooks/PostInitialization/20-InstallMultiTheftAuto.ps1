#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Install the Multi Theft Auto server into Server/:
#   - MTA_SERVER_URL     Linux x64 server .tar.gz (mta-server64, x64/*.so)
#   - MTA_BASECONFIG_URL mtaserver.conf, acl.xml, vehiclecolors.conf -> mods/deathmatch/
#   - MTA_RESOURCES_URL  the resource pack .zip -> mods/deathmatch/resources/ (empty = none)
# Reinstalls when one of the URLs changes; the installed URLs are kept in Server/.mta-install.
# Server/ is replaced as a whole (resources included), so put your own configs and resources
# in Overlay/.

Invoke-Hook "PreInstallMultiTheftAuto"

$exe       = Join-Path $Env:SERVER_DIR 'mta-server64'
$dm        = Join-Path $Env:SERVER_DIR 'mods/deathmatch'
$marker    = Join-Path $Env:SERVER_DIR '.mta-install'
$wanted    = @($Env:MTA_SERVER_URL, $Env:MTA_BASECONFIG_URL, $Env:MTA_RESOURCES_URL) -join "`n"
$installed = if (Test-Path -Path $marker) { (Get-Content -Path $marker -Raw).Trim() }

function Get-Download([string] $Url, [string] $Sha256, [string] $File) {
    Write-Log "Downloading $Url"
    curl -fsSL --retry 3 --output $File "$Url"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Url" }
    if ($Sha256) {
        $hash = (Get-FileHash -Path $File -Algorithm SHA256).Hash
        if ($hash -ne $Sha256) {
            Remove-Item -Force -Path $File
            throw "SHA256 mismatch for $Url`: got $hash, expected $Sha256 (clear the matching *_SHA256 variable when installing another build)"
        }
    }
}

if ((Test-Path -Path $exe) -and ($installed -eq $wanted.Trim() -or -not $Env:MTA_SERVER_URL)) {
    Write-Log "Multi Theft Auto server found in $Env:SERVER_DIR"
} elseif (-not $Env:MTA_SERVER_URL) {
    Write-Log -Level Error "mta-server64 not found in $Env:SERVER_DIR and MTA_SERVER_URL is empty"
} else {
    $tmp = '/tmp/mta-install'
    Remove-Item -Recurse -Force -Path $tmp -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path "$tmp/server", "$tmp/config", "$tmp/resources" -Force | Out-Null

    Get-Download $Env:MTA_SERVER_URL $Env:MTA_SERVER_SHA256 "$tmp/server.tar.gz"
    tar -xzf "$tmp/server.tar.gz" -C "$tmp/server"
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $Env:MTA_SERVER_URL" }
    $root = Get-ChildItem -Path "$tmp/server" -Filter 'mta-server64' -Recurse -File -Depth 2 |
        Select-Object -First 1 -ExpandProperty Directory
    if (-not $root) { throw "mta-server64 not found in $Env:MTA_SERVER_URL" }

    if ($Env:MTA_BASECONFIG_URL) {
        Get-Download $Env:MTA_BASECONFIG_URL $Env:MTA_BASECONFIG_SHA256 "$tmp/baseconfig.tar.gz"
        tar -xzf "$tmp/baseconfig.tar.gz" -C "$tmp/config"
        if ($LASTEXITCODE -ne 0) { throw "Could not extract $Env:MTA_BASECONFIG_URL" }
    }

    if ($Env:MTA_RESOURCES_URL) {
        Get-Download $Env:MTA_RESOURCES_URL $Env:MTA_RESOURCES_SHA256 "$tmp/resources.zip"
        unzip -q -o "$tmp/resources.zip" -d "$tmp/resources" -x '.gitattributes' 'LICENSE' 'README.md'
        if ($LASTEXITCODE -gt 1) { throw "Could not extract $Env:MTA_RESOURCES_URL" }
    }

    # Replace the old install, keeping nothing: the resource pack drops and renames resources
    if (Test-Path -Path $Env:SERVER_DIR) {
        Get-ChildItem -Path $Env:SERVER_DIR -Force | Remove-Item -Recurse -Force
    }
    New-Item -ItemType Directory -Path $dm -Force | Out-Null
    cp -a "$($root.FullName)/." "$Env:SERVER_DIR/"
    if ($LASTEXITCODE -ne 0) { throw "Could not copy the server into $Env:SERVER_DIR" }

    $config = Get-ChildItem -Path "$tmp/config" -Filter 'mtaserver.conf' -Recurse -File -Depth 2 |
        Select-Object -First 1 -ExpandProperty Directory
    if ($config) {
        cp -a "$($config.FullName)/." "$dm/"
    } elseif (-not (Test-Path -Path (Join-Path $dm 'mtaserver.conf'))) {
        Write-Log -Level Warning "No mtaserver.conf installed; put one in Overlay/mods/deathmatch/"
    }

    if ($Env:MTA_RESOURCES_URL) {
        New-Item -ItemType Directory -Path "$dm/resources" -Force | Out-Null
        cp -a "$tmp/resources/." "$dm/resources/"
    }

    Remove-Item -Recurse -Force -Path $tmp

    chmod -R u+rwX,go+rX $Env:SERVER_DIR
    chmod +x $exe
    Set-Content -Path $marker -Value $wanted
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

    Write-Log "Multi Theft Auto server installed into $Env:SERVER_DIR"
}

Invoke-Hook "PostInstallMultiTheftAuto"

Set-Location $Env:SERVER_ROOT
