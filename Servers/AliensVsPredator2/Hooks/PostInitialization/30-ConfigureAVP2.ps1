#Requires -Modules Logging

# Write the AVP2_* settings into ServerData\<AVP2_CONFIG>.txt, the profile AVP2Serv.exe loads with
# -config. It is an INI file: [Settings] (name, port, game type, passwords), one section per game
# type (map rotation as Map00..MapNN, limits) and [Preferences]. The file is created from the
# stock ServerData\unnamed.txt and edited through the merged view, so the edited copy lands in
# Overlay/ and can be changed there; keys without a non-empty AVP2_* setting keep their value.

$name = if ($Env:AVP2_CONFIG) { $Env:AVP2_CONFIG } else { 'lancommander' }
$dir  = Join-Path $Env:SERVER_ROOT 'ServerData'
$file = Join-Path $dir "$name.txt"

if (-not (Test-Path -Path (Join-Path $Env:SERVER_ROOT 'AVP2Serv.exe'))) {
    Write-Log -Level Error "AVP2Serv.exe not found in $Env:SERVER_ROOT; skipping server configuration"
    return
}

if (-not (Test-Path -Path $file)) {
    $template = Join-Path $dir 'unnamed.txt'

    if (-not (Test-Path -Path $template)) {
        Write-Log -Level Error "Neither ServerData/$name.txt nor ServerData/unnamed.txt exists; skipping server configuration"
        return
    }

    Copy-Item -Path $template -Destination $file
    Write-Log "Created ServerData/$name.txt from unnamed.txt"
}

# Section names by game type number (GameType in [Settings]). 7 and 8 come from the Master Server
# Patch; CTF and Domination also need a ctfworlds\ / domworlds\ file for every map.
$gameTypes = [ordered]@{
    'deathmatch'     = @{ Id = 1; Section = 'Deathmatch' }
    'teamdeathmatch' = @{ Id = 2; Section = 'TeamDeathmatch' }
    'hunt'           = @{ Id = 3; Section = 'Hunt' }
    'survivor'       = @{ Id = 4; Section = 'Survivor' }
    'overrun'        = @{ Id = 5; Section = 'Overrun' }
    'evac'           = @{ Id = 6; Section = 'Evac' }
    'ctf'            = @{ Id = 7; Section = 'CaptureTheFlag' }
    'domination'     = @{ Id = 8; Section = 'Domination' }
}

# Retail maps every 1.0.9.6 client has (MULTI.REZ and AVP2P.REZ). The Master Server Patch adds
# more in AVP2P5.REZ, but clients only load that rez with the patch's command line.
$dmMaps = 'dm_alesserfate,dm_alley,dm_auriga,dm_bunker,dm_colony,dm_compound,dm_depot,dm_fury151,dm_hanger,dm_leadworks,dm_outpost4,dm_quarantine,dm_reservoir,dm_stronghold,dm_verloc'
$defaultMaps = @{
    'Deathmatch'     = $dmMaps
    'TeamDeathmatch' = $dmMaps
    'Hunt'           = $dmMaps
    'Survivor'       = $dmMaps
    'Overrun'        = 'over_alley,over_compound,over_leadworks,over_quarantine,over_stronghold'
    'Evac'           = 'evac_alley,evac_auriga,evac_colony,evac_fury151,evac_gauntlet,evac_hanger,evac_verloc'
    'CaptureTheFlag' = 'dm_alley,dm_auriga,dm_colony,dm_fury151,dm_hanger,dm_leadworks,dm_quarantine,dm_verloc'
    'Domination'     = 'dm_alesserfate,dm_alley,dm_auriga,dm_colony,dm_compound,dm_fury151,dm_hanger,dm_leadworks,dm_quarantine,dm_verloc'
}

# Parse into ordered sections of ordered `Key = Value` pairs, keeping values verbatim
$ini = [ordered]@{}
$section = $null

foreach ($line in [System.IO.File]::ReadAllLines($file)) {
    if ($line -match '^\s*\[([^\]]+)\]') {
        $section = $Matches[1]
        if (-not $ini.Contains($section)) { $ini[$section] = [ordered]@{} }
    } elseif ($section -and $line -match '^\s*([^=]+?)\s*=\s*(.*?)\s*$') {
        $ini[$section][$Matches[1]] = $Matches[2]
    }
}

function Set-Value([string] $Section, [string] $Key, [string] $Value) {
    if (-not $ini.Contains($Section)) { $ini[$Section] = [ordered]@{} }
    $ini[$Section][$Key] = $Value
}

function Set-String([string] $Section, [string] $Key, [string] $Value) {
    Set-Value $Section $Key "`"$($Value.Replace('"', ''))`""
}

function ConvertTo-Flag([string] $Value) {
    if ($Value -match '^(1|true|yes|on)$') { '1' } else { '0' }
}

# Game type
$type = $gameTypes['deathmatch']
if ($Env:AVP2_GAME_TYPE) {
    $key = $Env:AVP2_GAME_TYPE.ToLowerInvariant() -replace '[^a-z0-9]', ''
    $type = $gameTypes.Values | Where-Object { $_.Id -eq ($key -as [int]) -or $_.Section -ieq $key } | Select-Object -First 1
    if (-not $type) { $type = $gameTypes[$key] }
    if (-not $type) { throw "Unknown AVP2_GAME_TYPE '$Env:AVP2_GAME_TYPE' (use $($gameTypes.Keys -join ', ') or 1-8)" }
}
$typeSection = $type.Section

Set-Value 'Settings' 'Dedicated' '1'
Set-Value 'Settings' 'GameType' "$($type.Id)"

if ($Env:AVP2_SERVER_NAME) { Set-String 'Settings' 'ServerName' $Env:AVP2_SERVER_NAME }
if ($Env:AVP2_PORT)        { Set-Value  'Settings' 'PortID' $Env:AVP2_PORT }
if ($Env:AVP2_BANDWIDTH)   { Set-Value  'Settings' 'Bandwidth' $Env:AVP2_BANDWIDTH }
if ($Env:AVP2_LAN)         { Set-Value  'Settings' 'LANConnection' (ConvertTo-Flag $Env:AVP2_LAN) }

# A join password only applies while the server is Locked
if ($Env:AVP2_PASSWORD) {
    Set-String 'Settings' 'Password' $Env:AVP2_PASSWORD
    Set-Value  'Settings' 'Locked' '1'
} else {
    Set-Value  'Settings' 'Locked' '0'
}

# Server control (admin) password, used in game with `/control <password>`
if ($Env:AVP2_CONTROL_PASSWORD) {
    Set-String 'Settings' 'SCPassword' $Env:AVP2_CONTROL_PASSWORD
} elseif ($ini['Settings']['SCPassword'] -eq '"AVP2"') {
    Write-Log -Level Warning "The server control password is the stock 'AVP2'; set AVP2_CONTROL_PASSWORD"
}

# Map rotation for the selected game type. A bare name goes in Worlds\Multi\<folder>; give a path
# with a backslash (e.g. worlds\multi\dm\mymap) for anything else.
$maps = if ($Env:AVP2_MAPS) { $Env:AVP2_MAPS } else { $defaultMaps[$typeSection] }

if ($maps -ine 'config') {
    $list = @($maps -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

    if (-not $ini.Contains($typeSection)) { $ini[$typeSection] = [ordered]@{} }
    foreach ($key in @($ini[$typeSection].Keys)) {
        if ($key -match '^Map\d+$') { $ini[$typeSection].Remove($key) }
    }

    $rotation = [ordered]@{}
    for ($i = 0; $i -lt $list.Count; $i++) {
        $map = $list[$i].Replace('/', '\')
        if (-not $map.Contains('\')) {
            $folder = switch -Regex ($map) { '^evac_' { 'evac' } '^over_' { 'overrun' } default { 'dm' } }
            $map = "worlds\multi\$folder\$map"
        }
        $rotation['Map{0:D2}' -f $i] = "`"$map`""
    }

    # Keep the map list at the top of the section, like the stock file
    foreach ($s in $ini[$typeSection].GetEnumerator()) { $rotation[$s.Key] = $s.Value }
    $ini[$typeSection] = $rotation
}

if (-not ($ini[$typeSection].Keys | Where-Object { $_ -match '^Map\d+$' -and $ini[$typeSection][$_] -ne '""' })) {
    Write-Log -Level Error "No maps in [$typeSection] of ServerData/$name.txt; AVP2Serv binds its port but never hosts"
}

# Per game type limits; a limit the game type doesn't use is ignored by the game
$limits = [ordered]@{
    'MaxTotalPlayers' = $Env:AVP2_MAX_PLAYERS
    'TimeLimit'       = $Env:AVP2_TIME_LIMIT
    'FragLimit'       = $Env:AVP2_FRAG_LIMIT
    'ScoreLimit'      = $Env:AVP2_SCORE_LIMIT
    'RoundLimit'      = $Env:AVP2_ROUND_LIMIT
    'CaptureLimit'    = $Env:AVP2_CAPTURE_LIMIT
}

foreach ($s in $limits.GetEnumerator()) {
    if ($s.Value) { Set-Value $typeSection $s.Key $s.Value }
}

# MaxPlayers0-3 cap each race (alien, marine, predator, corporate) in the game types that have
# them; the stock Deathmatch section caps each at 4
$perRace = if ($Env:AVP2_MAX_PLAYERS_PER_RACE) { $Env:AVP2_MAX_PLAYERS_PER_RACE } else { $Env:AVP2_MAX_PLAYERS }
if ($perRace) {
    foreach ($key in @($ini[$typeSection].Keys)) {
        if ($key -match '^MaxPlayers[0-3]$') { $ini[$typeSection][$key] = $perRace }
    }
}

if ($Env:AVP2_FRIENDLY_FIRE) { Set-Value 'Preferences' 'FriendlyFire' (ConvertTo-Flag $Env:AVP2_FRIENDLY_FIRE) }
if ($Env:AVP2_CLASS_WEAPONS) { Set-Value 'Preferences' 'ClassWeapons' (ConvertTo-Flag $Env:AVP2_CLASS_WEAPONS) }

$lines = foreach ($s in $ini.GetEnumerator()) {
    "[$($s.Key)]"
    foreach ($kv in $s.Value.GetEnumerator()) { "$($kv.Key) = $($kv.Value)" }
    ''
}

[System.IO.File]::WriteAllText($file, ($lines -join "`r`n"))
chown "$($Env:UID):$($Env:GID)" $file

Write-Log "Applied AVP2_* settings to ServerData/$name.txt ($typeSection)"
