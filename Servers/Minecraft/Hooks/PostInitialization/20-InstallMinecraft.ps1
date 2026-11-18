#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Install the server jar (Server/server.jar) and the MINECRAFT_PLUGINS jars (Server/plugins/).
#
#   - The jar is picked by MINECRAFT_SERVER_TYPE (paper, vanilla or custom) and reinstalled when
#     the resolved download URL changes; the installed URL is kept in Server/.minecraft-server-url
#   - Plugins are reinstalled when their URL list changes; the list is kept in
#     Server/plugins/.lancommander-plugins. Jars this hook installed earlier that are no longer in
#     the list are removed. Jars you put in Overlay/plugins/ are left alone
#   - Everything the server writes (worlds, configs, Paper's cache and libraries, plugin data)
#     lands in Overlay/

Invoke-Hook "PreInstallMinecraft"

$changed = $false

function Get-Download([string] $Url, [string] $Path) {
    $tmp = "$Path.download"
    curl -fsSL --retry 3 --output $tmp $Url
    if ($LASTEXITCODE -ne 0) {
        Remove-Item -Force -Path $tmp -ErrorAction SilentlyContinue
        throw "Download failed: $Url"
    }
    return $tmp
}

function Test-Hash([string] $Path, [string] $Algorithm, [string] $Expected, [string] $Url) {
    if (-not $Expected) { return }
    $hash = (Get-FileHash -Path $Path -Algorithm $Algorithm).Hash
    if ($hash -ne $Expected.ToUpperInvariant()) {
        Remove-Item -Force -Path $Path
        throw "$Algorithm mismatch for $Url`: got $hash, expected $Expected"
    }
}

# ---- Resolve the server jar ----------------------------------------------------------------
$type = "$Env:MINECRAFT_SERVER_TYPE".ToLowerInvariant()
if (-not $type) { $type = 'paper' }
$version = $Env:MINECRAFT_VERSION
$url = $null; $algorithm = $null; $expected = $null

$jar = Join-Path $Env:SERVER_DIR 'server.jar'
$marker = Join-Path $Env:SERVER_DIR '.minecraft-server-url'
$installed = if (Test-Path -Path $marker) { (Get-Content -Path $marker -Raw).Trim() }

try {
    switch ($type) {
        'paper' {
            if (-not $version) { throw 'MINECRAFT_VERSION is empty' }
            $builds = Invoke-RestMethod -Uri "https://fill.papermc.io/v3/projects/paper/versions/$version/builds" `
                -Headers @{ 'User-Agent' = 'LANCommander.Servers.Minecraft' }
            $build = if (-not $Env:PAPER_BUILD -or $Env:PAPER_BUILD -eq 'latest') {
                $builds | Where-Object { $_.channel -eq 'STABLE' } | Sort-Object -Property id -Descending | Select-Object -First 1
            } else {
                $builds | Where-Object { "$($_.id)" -eq "$Env:PAPER_BUILD" } | Select-Object -First 1
            }
            if (-not $build) { throw "Paper $version has no build '$Env:PAPER_BUILD'" }
            $download = $build.downloads.'server:default'
            $url = $download.url
            $algorithm = 'SHA256'; $expected = $download.checksums.sha256
            Write-Log "Paper $version build $($build.id)"
        }
        'vanilla' {
            if (-not $version) { throw 'MINECRAFT_VERSION is empty' }
            $manifest = Invoke-RestMethod -Uri 'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json'
            $entry = $manifest.versions | Where-Object { $_.id -eq $version } | Select-Object -First 1
            if (-not $entry) { throw "Minecraft version '$version' isn't in Mojang's version manifest" }
            $profile = Invoke-RestMethod -Uri $entry.url
            $url = $profile.downloads.server.url
            $algorithm = 'SHA1'; $expected = $profile.downloads.server.sha1
            Write-Log "Vanilla Minecraft $version"
        }
        'custom' {
            if (-not $Env:MINECRAFT_SERVER_URL) { throw 'MINECRAFT_SERVER_TYPE=custom needs MINECRAFT_SERVER_URL' }
            $url = $Env:MINECRAFT_SERVER_URL
            if ($Env:MINECRAFT_SERVER_SHA256) { $algorithm = 'SHA256'; $expected = $Env:MINECRAFT_SERVER_SHA256 }
        }
        default { throw "Unknown MINECRAFT_SERVER_TYPE '$type' (use paper, vanilla or custom)" }
    }
} catch {
    # Offline start: keep what's installed
    if (Test-Path -Path $jar) {
        Write-Log -Level Warning "Could not resolve the server jar ($($_.Exception.Message)); keeping the installed $installed"
        $url = $null
    } else {
        throw
    }
}

if ($url -and ($url -ne $installed -or -not (Test-Path -Path $jar))) {
    Write-Log "Downloading the server jar from $url"
    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    $tmp = Get-Download $url $jar
    if ($algorithm) { Test-Hash $tmp $algorithm $expected $url }
    Move-Item -Force -Path $tmp -Destination $jar
    Set-Content -Path $marker -Value $url
    chown "$($Env:UID):$($Env:GID)" $jar $marker
    $changed = $true
    Write-Log "Installed $jar"
} elseif ($url) {
    Write-Log "Server jar is up to date ($url)"
}

# ---- Plugins --------------------------------------------------------------------------------
$pluginDir = Join-Path $Env:SERVER_DIR 'plugins'
$pluginMarker = Join-Path $pluginDir '.lancommander-plugins'
$wanted = @("$Env:MINECRAFT_PLUGINS" -split '\s+' | Where-Object { $_ })
$previous = @(if (Test-Path -Path $pluginMarker) { Get-Content -Path $pluginMarker | Where-Object { $_ } })

if ((Compare-Object -ReferenceObject @($previous) -DifferenceObject @($wanted | ForEach-Object { $_ }) -SyncWindow 0) -or
    ($wanted | Where-Object { -not (Test-Path -Path (Join-Path $pluginDir ([IO.Path]::GetFileName(([Uri]$_).AbsolutePath)))) })) {
    New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null

    # Remove the jars of plugins this hook installed that are no longer wanted
    foreach ($old in $previous) {
        if ($wanted -notcontains $old) {
            $file = Join-Path $pluginDir ([IO.Path]::GetFileName(([Uri]$old).AbsolutePath))
            if (Test-Path -Path $file) { Remove-Item -Force -Path $file; Write-Log "Removed plugin $file" }
        }
    }

    foreach ($pluginUrl in $wanted) {
        $name = [IO.Path]::GetFileName(([Uri]$pluginUrl).AbsolutePath)
        if (-not $name.EndsWith('.jar')) { throw "Plugin URL doesn't end in a .jar file name: $pluginUrl" }
        $file = Join-Path $pluginDir $name
        if (($previous -contains $pluginUrl) -and (Test-Path -Path $file)) { continue }
        Write-Log "Downloading plugin $name"
        $tmp = Get-Download $pluginUrl $file
        Move-Item -Force -Path $tmp -Destination $file
    }

    Set-Content -Path $pluginMarker -Value $wanted
    chown -R "$($Env:UID):$($Env:GID)" $pluginDir
    $changed = $true
    Write-Log "Plugins: $(if ($wanted) { ($wanted | ForEach-Object { [IO.Path]::GetFileName(([Uri]$_).AbsolutePath) }) -join ', ' } else { 'none' })"
}

# The overlay was mounted before Server/ changed, and overlayfs doesn't reliably show lower-dir
# changes made while mounted
if ($changed) {
    mountpoint -q $Env:SERVER_ROOT
    if ($LASTEXITCODE -eq 0) {
        umount $Env:SERVER_ROOT
        Remove-Item -Path "$Env:WORK_DIR/*" -Recurse -Force -ErrorAction SilentlyContinue
        Mount-Overlay -MountPoint $Env:SERVER_ROOT -LowerDir $Env:SERVER_DIR -UpperDir $Env:OVERLAY_DIR -WorkDir $Env:WORK_DIR -RequireEmptyWorkDir -OverlayOption "xino=on"
        Write-Log "OverlayFS remounted"
    }
}

Invoke-Hook "PostInstallMinecraft"

Set-Location $Env:SERVER_ROOT
