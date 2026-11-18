#Requires -Modules Logging
#Requires -Modules Hooks
#Requires -Modules OverlayFS

# Install the TES3MP server into Server/.
#
# What gets installed:
#   - TES3MP_SERVER_URL, when set: any .tar.gz or .zip with tes3mp-server.x86_64 and the CoreScripts
#     (<home>/scripts/serverCore.lua), at its root or in one subfolder. Checked against
#     TES3MP_SERVER_SHA256 when that's set.
#   - Otherwise the official Linux server package of TES3MP_VERSION from the TES3MP GitHub
#     releases. "latest" (the default) is the newest release that has a Linux x86_64 server package,
#     looked up on every start. Known versions install from the table below without the GitHub API
#     and are always checked against their SHA-256. Versions before 0.8.0 are refused.
#
# Reinstalls when the resolved URL changes; the installed URL and version are kept in
# Server/.tes3mp-server-url and Server/.tes3mp-version. Files in Server/ that no marker covers (a
# server you copied in yourself) are left alone.
#
# When the installed version changes, Server/ is emptied first, and the copies of the old
# version's tes3mp-server-default.cfg and CoreScripts scripts in Overlay/ are renamed to
# <name>.bak-<old version>, so the new version's files show through. The world (<home>/data/) is
# kept.

Invoke-Hook "PreInstallTES3MP"

# Official Linux x86_64 server packages. GitHub publishes no digests for these assets, so the
# hashes are pinned here. Releases before 0.8.0 aren't supported: their server links libGL (Mesa,
# ~150 MB) and they can't talk to 0.8 clients.
$knownReleases = [ordered]@{
    '0.8.1' = @{
        Url    = 'https://github.com/TES3MP/TES3MP/releases/download/tes3mp-0.8.1/tes3mp-server-GNU%2BLinux-x86_64-release-0.8.1-68954091c5-6da3fdea59.tar.gz'
        Sha256 = '106a56e32a00ff7a92b574fae0e25671e90a199f509b16d483a8d7da6fc3bcf0'
    }
    '0.8.0' = @{
        Url    = 'https://github.com/TES3MP/TES3MP/releases/download/tes3mp-0.8.0/tes3mp-server-GNU%2BLinux-x86_64-release-0.8.0-6b1c83f629-14d7382e1e.tar.gz'
        Sha256 = '8ee81ce3b6e093bf8b5f92a5bb6216300b917b45513ef41728a2896de2a15498'
    }
}
$serverAssetPattern = '^tes3mp-server-GNU\+Linux-x86_64-release-.+\.tar\.gz$'

$exe        = Join-Path $Env:SERVER_DIR 'tes3mp-server.x86_64'
$urlMarker  = Join-Path $Env:SERVER_DIR '.tes3mp-server-url'
$verMarker  = Join-Path $Env:SERVER_DIR '.tes3mp-version'
$installedUrl     = if (Test-Path -Path $urlMarker) { (Get-Content -Path $urlMarker -Raw).Trim() }
$installedVersion = if (Test-Path -Path $verMarker) { (Get-Content -Path $verMarker -Raw).Trim() }

function Get-CoreScriptsDir([string] $Root) {
    # tes3mp-server-default.cfg's [Plugins] home: ./server since 0.8.0, ./CoreScripts before
    $cfg = Join-Path $Root 'tes3mp-server-default.cfg'
    if (Test-Path -Path $cfg) {
        $homeLine = Get-Content -Path $cfg | Where-Object { $_ -match '^\s*home\s*=' } | Select-Object -First 1
        if ($homeLine) {
            $dir = ($homeLine -replace '^\s*home\s*=\s*', '').Trim().TrimStart('.').Trim('/')
            if ($dir) { return $dir }
        }
    }
    foreach ($dir in 'server', 'CoreScripts') {
        if (Test-Path -Path (Join-Path $Root "$dir/scripts/serverCore.lua")) { return $dir }
    }
    return 'server'
}

function ConvertTo-Version([string] $Tag) {
    # Release tags are "tes3mp-0.8.1" or "0.7.0-alpha"
    $Tag -replace '^(tes3mp-|v)', ''
}

function Get-GitHubRelease([string] $Version) {
    # Returns @{ Version; Url; Sha256 } for the newest release with a Linux server package (latest)
    # or the release whose tag matches $Version
    $releases = Invoke-RestMethod -Uri 'https://api.github.com/repos/TES3MP/TES3MP/releases?per_page=100' `
        -Headers @{ 'User-Agent' = 'lancommander-tes3mp-server'; 'Accept' = 'application/vnd.github+json' } `
        -TimeoutSec 30
    foreach ($release in $releases) {
        if ($release.draft) { continue }
        $tagVersion = ConvertTo-Version $release.tag_name
        if ($Version -eq 'latest') {
            if ($release.prerelease) { continue }
        } elseif ($release.tag_name -ne $Version -and $tagVersion -ne $Version) {
            continue
        }
        $asset = $release.assets | Where-Object { $_.name -match $serverAssetPattern } | Select-Object -First 1
        if (-not $asset) {
            if ($Version -ne 'latest') { throw "TES3MP release $($release.tag_name) has no Linux x86_64 server package" }
            continue
        }
        $sha = if ($asset.digest -match '^sha256:([0-9a-f]{64})$') { $Matches[1] }
               elseif ($knownReleases.Contains($tagVersion)) { $knownReleases[$tagVersion].Sha256 }
        return @{ Version = $tagVersion; Url = $asset.browser_download_url; Sha256 = $sha }
    }
    if ($Version -eq 'latest') { throw 'No TES3MP release with a Linux x86_64 server package found' }
    throw "TES3MP release '$Version' not found (known: $($knownReleases.Keys -join ', '))"
}

# ---- Resolve what to install ----------------------------------------------------------------

$target = $null
if ($Env:TES3MP_SERVER_URL) {
    $target = @{ Version = $(if ($Env:TES3MP_VERSION -and $Env:TES3MP_VERSION -ne 'latest') { $Env:TES3MP_VERSION } else { 'custom' })
                 Url = $Env:TES3MP_SERVER_URL; Sha256 = $Env:TES3MP_SERVER_SHA256 }
} else {
    $version = if ($Env:TES3MP_VERSION) { ConvertTo-Version $Env:TES3MP_VERSION.Trim() } else { 'latest' }
    if ($version -match '^0\.[0-7](\.|-|$)') {
        throw "TES3MP_VERSION=$($Env:TES3MP_VERSION) isn't supported: this image runs TES3MP 0.8.0 and newer (older servers need libGL). Use TES3MP_SERVER_URL to install another package at your own risk"
    }
    if ($knownReleases.Contains($version)) {
        $known = $knownReleases[$version]
        $target = @{ Version = $version; Url = $known.Url; Sha256 = $(if ($Env:TES3MP_SERVER_SHA256) { $Env:TES3MP_SERVER_SHA256 } else { $known.Sha256 }) }
    } else {
        try {
            $target = Get-GitHubRelease $version
            if ($Env:TES3MP_SERVER_SHA256) { $target.Sha256 = $Env:TES3MP_SERVER_SHA256 }
            if ($version -eq 'latest') { Write-Log "Latest TES3MP release with a Linux server: $($target.Version)" }
        } catch {
            if ($version -eq 'latest' -and (Test-Path -Path $exe)) {
                Write-Log -Level Warning "Could not look up the latest TES3MP release ($($_.Exception.Message)); keeping the installed $installedVersion"
            } elseif ($version -eq 'latest') {
                $newest = @($knownReleases.Keys)[0]
                Write-Log -Level Warning "Could not look up the latest TES3MP release ($($_.Exception.Message)); installing $newest"
                $target = @{ Version = $newest; Url = $knownReleases[$newest].Url; Sha256 = $knownReleases[$newest].Sha256 }
            } else {
                throw
            }
        }
    }
}

# ---- Install --------------------------------------------------------------------------------

if (-not $target) {
    # Lookup failed, the installed server is kept
} elseif ((Test-Path -Path $exe) -and ($installedUrl -eq $target.Url -or -not $installedUrl)) {
    $what = if ($installedVersion) { "TES3MP $installedVersion" } else { 'TES3MP' }
    Write-Log "$what found in $Env:SERVER_DIR"
} else {
    Write-Log "Downloading TES3MP $($target.Version) from $($target.Url)"

    $isZip   = $target.Url -match '\.zip($|\?)'
    $file    = if ($isZip) { '/tmp/tes3mp.zip' } else { '/tmp/tes3mp.tar.gz' }
    $extract = '/tmp/tes3mp'

    curl -fsSL --retry 3 --output $file "$($target.Url)"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $($target.Url)" }

    if ($target.Sha256) {
        $hash = (Get-FileHash -Path $file -Algorithm SHA256).Hash
        if ($hash -ne $target.Sha256) {
            Remove-Item -Force -Path $file
            throw "SHA256 mismatch for $($target.Url)`: got $hash, expected $($target.Sha256) (set or clear TES3MP_SERVER_SHA256 when installing from another package)"
        }
    } else {
        Write-Log -Level Warning "No SHA-256 known for $($target.Url); installing it unchecked"
    }

    Remove-Item -Recurse -Force -Path $extract -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $extract -Force | Out-Null
    if ($isZip) {
        unzip -q -o $file -d $extract -x '*source.tar.gz' '*/.git/*'
        if ($LASTEXITCODE -gt 1) { throw "Could not extract $file" }
    } else {
        # The 0.8.x tarballs end with a lone zero block, which GNU tar warns about but extracts fine
        tar -xzf $file -C $extract --exclude='*/source.tar.gz' --exclude='*/.git' 2>&1 |
            Where-Object { $_ -notmatch 'lone zero block' } | ForEach-Object { Write-Log -Level Warning "$_" }
        if ($LASTEXITCODE -gt 1) { throw "Could not extract $file" }
    }

    $root = Get-ChildItem -Path $extract -Filter 'tes3mp-server.x86_64' -Recurse -File -Depth 2 |
        Select-Object -First 1 -ExpandProperty Directory
    if (-not $root) { throw "tes3mp-server.x86_64 not found in $($target.Url)" }
    $newCore = Get-CoreScriptsDir $root.FullName
    if (-not (Test-Path -Path (Join-Path $root.FullName "$newCore/scripts/serverCore.lua"))) { throw "$newCore/scripts/serverCore.lua not found next to tes3mp-server.x86_64 in $($target.Url)" }

    # Change Server/ and Overlay/ with the overlay unmounted; overlayfs doesn't reliably show
    # changes to its layers made while mounted
    mountpoint -q $Env:SERVER_ROOT
    $wasMounted = $LASTEXITCODE -eq 0
    if ($wasMounted) { umount $Env:SERVER_ROOT }

    if ($installedUrl -and (Test-Path -Path $exe)) {
        # Replacing a package this hook installed: back up the overlay copies of the old version's
        # config and scripts (the 30-ConfigureTES3MP hook edits them through Merged/, which copies
        # them up), then empty Server/ so no files of the old version are left behind
        $oldCore = Get-CoreScriptsDir $Env:SERVER_DIR
        $suffix  = ".bak-$(if ($installedVersion) { $installedVersion } else { 'old' })"
        $packageFiles = @('tes3mp-server-default.cfg') + @(
            Get-ChildItem -Path (Join-Path $Env:SERVER_DIR "$oldCore/scripts") -Recurse -File -ErrorAction SilentlyContinue |
                ForEach-Object { [System.IO.Path]::GetRelativePath($Env:SERVER_DIR, $_.FullName) })
        foreach ($relative in $packageFiles) {
            $copy = Join-Path $Env:OVERLAY_DIR $relative
            if (Test-Path -Path $copy -PathType Leaf) {
                Move-Item -Force -Path $copy -Destination "$copy$suffix"
                Write-Log -Level Warning "Overlay/$relative belonged to TES3MP $installedVersion; renamed to $relative$suffix (reapply your changes to the new version's file)"
            }
        }
        if ($oldCore -ne $newCore -and (Test-Path -Path (Join-Path $Env:OVERLAY_DIR "$oldCore/data"))) {
            Write-Log -Level Warning "The world data of TES3MP $installedVersion is in Overlay/$oldCore/data, but this version keeps it in $newCore/data; move it over if you want to keep it"
        }
        Get-ChildItem -Path $Env:SERVER_DIR -Force | Remove-Item -Recurse -Force
    }

    New-Item -ItemType Directory -Path $Env:SERVER_DIR -Force | Out-Null
    cp -a "$($root.FullName)/." "$Env:SERVER_DIR/"
    if ($LASTEXITCODE -ne 0) { throw "Could not copy TES3MP into $Env:SERVER_DIR" }

    Remove-Item -Recurse -Force -Path $file, $extract

    chmod -R u+rwX,go+rX $Env:SERVER_DIR
    chmod +x $exe
    Set-Content -Path $urlMarker -Value $target.Url
    Set-Content -Path $verMarker -Value $target.Version
    chown -R "$($Env:UID):$($Env:GID)" $Env:SERVER_DIR

    if ($wasMounted) {
        Remove-Item -Path "$Env:WORK_DIR/*" -Recurse -Force -ErrorAction SilentlyContinue
        Mount-Overlay -MountPoint $Env:SERVER_ROOT -LowerDir $Env:SERVER_DIR -UpperDir $Env:OVERLAY_DIR -WorkDir $Env:WORK_DIR -RequireEmptyWorkDir -OverlayOption "xino=on"
        Write-Log "OverlayFS remounted"
    }

    Write-Log "TES3MP $($target.Version) installed into $Env:SERVER_DIR"
}

Invoke-Hook "PostInstallTES3MP"

Set-Location $Env:SERVER_ROOT
