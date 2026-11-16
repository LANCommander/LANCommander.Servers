#Requires -Modules Logging

# Point MHServerEmu and its web files at the address clients reach this container at, and apply
# the MH_* / MHSE__* settings. Runs on every start.
#
#   - ConfigOverride.ini (read by MHServerEmu over Config.ini) is rewritten from the environment:
#     the frontend's public address and port, the web front end on 127.0.0.1 (nginx passes requests
#     on to it), the store/news URLs, the MH_* settings, then every MHSE__<Section>__<Key>
#     variable. Keep your own settings in Overlay/Config.ini or in MHSE__ variables, not in
#     ConfigOverride.ini.
#   - htdocs/SiteConfig.xml (the first file the client loads) gets AuthServerAddress and the
#     loading-tips URL set to the public address; htdocs/news/index.html its patch notes link.
#     Only those values are changed, so other edits to the files in Overlay/htdocs/ are kept.

$root = $Env:SERVER_ROOT

if (-not (Test-Path -Path (Join-Path $root 'MHServerEmu.dll'))) {
    Write-Log -Level Error "MHServerEmu.dll not found in $root; see the 20-InstallMHServerEmu errors above"
    return
}

# ---- Public address -------------------------------------------------------------------------

$address = "$Env:MH_PUBLIC_ADDRESS".Trim()
if (-not $address) {
    # The container's own IPv4 address (on the macvlan LAN network: its DHCP address)
    $address = (hostname -I).Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries) |
        Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' -and $_ -notmatch '^127\.' } |
        Select-Object -First 1
    if (-not $address) {
        $address = '127.0.0.1'
        Write-Log -Level Warning "Could not find this container's IPv4 address; using 127.0.0.1. Set MH_PUBLIC_ADDRESS"
    }
}
Write-Log "Public address: $address (clients start with -siteconfigurl=$address/SiteConfig.xml)"

function ConvertTo-IniBool([string] $Name, [string] $Value) {
    if (-not $Value) { return $null }
    switch ($Value.Trim().ToLowerInvariant()) {
        { $_ -in 'true', '1', 'yes' } { return 'true' }
        { $_ -in 'false', '0', 'no' } { return 'false' }
        default { Write-Log -Level Warning "$Name must be true or false, got '$Value'; ignored"; return $null }
    }
}

function ConvertTo-IniInt([string] $Name, [string] $Value) {
    if (-not $Value) { return $null }
    if ($Value.Trim() -match '^-?\d+$') { return $Value.Trim() }
    Write-Log -Level Warning "$Name must be a whole number, got '$Value'; ignored"
    return $null
}

# ---- ConfigOverride.ini ---------------------------------------------------------------------

$web = "http://$address"
$ini = [ordered]@{
    'Logging' = [ordered]@{
        # 0 trace, 1 debug, 2 info, 3 warning, 4 error, 5 fatal
        'ConsoleMinLevel' = ConvertTo-IniInt 'MH_LOG_LEVEL' $Env:MH_LOG_LEVEL
    }
    'Frontend' = [ordered]@{
        'BindIP'        = '0.0.0.0'
        'Port'          = ConvertTo-IniInt 'MH_FRONTEND_PORT' $Env:MH_FRONTEND_PORT
        'PublicAddress' = $address
    }
    'WebFrontend' = [ordered]@{
        # Only nginx talks to it
        'Address' = '127.0.0.1'
        'Port'    = ConvertTo-IniInt 'MH_WEB_PORT' $Env:MH_WEB_PORT
    }
    'PlayerManager' = [ordered]@{
        'NewsUrl'        = "$web/news/index.html"
        'ServerCapacity' = ConvertTo-IniInt 'MH_SERVER_CAPACITY' $Env:MH_SERVER_CAPACITY
        'UseWhitelist'   = ConvertTo-IniBool 'MH_USE_WHITELIST' $Env:MH_USE_WHITELIST
    }
    'GroupingManager' = [ordered]@{
        'ServerName' = $Env:MH_SERVER_NAME
        'MotdText'   = $Env:MH_MOTD
    }
    'CustomGameOptions' = [ordered]@{
        'AutosaveIntervalMinutes' = ConvertTo-IniInt 'MH_AUTOSAVE_MINUTES' $Env:MH_AUTOSAVE_MINUTES
        'AutoUnlockAvatars'       = ConvertTo-IniBool 'MH_AUTO_UNLOCK_AVATARS' $Env:MH_AUTO_UNLOCK_AVATARS
        'AutoUnlockTeamUps'       = ConvertTo-IniBool 'MH_AUTO_UNLOCK_TEAMUPS' $Env:MH_AUTO_UNLOCK_TEAMUPS
    }
    'MTXStore' = [ordered]@{
        'GazillioniteBalanceForNewAccounts' = ConvertTo-IniInt 'MH_STARTING_GAZILLIONITE' $Env:MH_STARTING_GAZILLIONITE
        'HomePageUrl'           = "$web/store/index.html"
        'HomeBannerPageUrl'     = "$web/store/images/banner.png"
        'HeroesBannerPageUrl'   = "$web/store/images/banner.png"
        'CostumesBannerPageUrl' = "$web/store/images/banner.png"
        'BoostsBannerPageUrl'   = "$web/store/images/banner.png"
        'ChestsBannerPageUrl'   = "$web/store/images/banner.png"
        'SpecialsBannerPageUrl' = "$web/store/images/banner.png"
        'RealMoneyUrl'          = "https://$address/MTXStore/AddG"
        'BundleInfoUrl'         = "$web/bundles/"
        'BundleImageUrl'        = "$web/bundles/images/"
    }
}

# MHSE__<Section>__<Key>=<value> sets any Config.ini setting, e.g. MHSE__GameData__LoadAllPrototypes=true
Get-ChildItem -Path Env: | Where-Object { $_.Name -match '^MHSE__([A-Za-z0-9]+)__([A-Za-z0-9]+)$' } | Sort-Object Name | ForEach-Object {
    $null = $_.Name -match '^MHSE__([A-Za-z0-9]+)__([A-Za-z0-9]+)$'
    $section = $Matches[1]; $key = $Matches[2]
    if (-not $ini.Contains($section)) { $ini[$section] = [ordered]@{} }
    $ini[$section][$key] = $_.Value
}

$lines = @('; Written by the 30-ConfigureMHServerEmu hook on every start from MH_* and MHSE__<Section>__<Key>',
           '; environment variables. Edits here are lost; put your settings in Config.ini instead.')
foreach ($section in $ini.Keys) {
    $entries = @($ini[$section].GetEnumerator() | Where-Object { $null -ne $_.Value -and "$($_.Value)" -ne '' })
    if (-not $entries) { continue }
    $lines += ''
    $lines += "[$section]"
    foreach ($entry in $entries) {
        $lines += "$($entry.Key)=$("$($entry.Value)" -replace '[\r\n]+', ' ')"
    }
}
$overrideFile = Join-Path $root 'ConfigOverride.ini'
[System.IO.File]::WriteAllText($overrideFile, ($lines -join "`n") + "`n")
chown "$($Env:UID):$($Env:GID)" $overrideFile
Write-Log "Wrote ConfigOverride.ini"

# ---- Web files ------------------------------------------------------------------------------

function Edit-WebFile([string] $Relative, [hashtable[]] $Replacements) {
    $file = Join-Path $root $Relative
    if (-not (Test-Path -Path $file)) {
        Write-Log -Level Warning "$Relative not found in $root"
        return
    }
    $text = Get-Content -Path $file -Raw
    $new  = $text
    foreach ($r in $Replacements) {
        $value = $r.Value
        # A MatchEvaluator keeps $ in the value literal
        $new = ([regex]$r.Pattern).Replace($new, { param($m) $m.Groups[1].Value + $value + $m.Groups[2].Value })
    }
    if ($new -ne $text) {
        [System.IO.File]::WriteAllText($file, $new)
        chown "$($Env:UID):$($Env:GID)" $file
        Write-Log "Pointed $Relative at $address"
    }
}

Edit-WebFile 'htdocs/SiteConfig.xml' @(
    @{ Pattern = '(<str\s+name="AuthServerAddress"\s+value=")[^"]*(")'; Value = $address }
    # The release asks for liveloadingtips.xml; the file is LiveLoadingTips.xml (nginx is case-sensitive)
    @{ Pattern = '(<str\s+name="LoadScreenTipsURL"\s+value=")[^"]*(")'; Value = "$web/LiveLoadingTips.xml" }
)
Edit-WebFile 'htdocs/news/index.html' @(
    @{ Pattern = '(["''])https?://[^/"'']+/news/patch-notes\.html(["''])'; Value = "$web/news/patch-notes.html" }
)
