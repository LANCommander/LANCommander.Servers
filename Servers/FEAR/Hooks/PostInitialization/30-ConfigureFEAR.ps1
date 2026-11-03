#Requires -Modules Logging

# Write the FEAR_* settings into <FEAR_USER_DIR>/ServerOptions/<FEAR_CONFIG>.txt, the options file
# FEARServer.exe loads with -optionsfile. It is an INI file: [ServerSettings] (game type, port,
# passwords, LAN, downloads, voting), one section per game type (SessionName = server name,
# limits, MissionN = map rotation) and [SEC2] when the SEC2 patch is installed. The file is
# created with the stock defaults when missing and edited through the merged view, so the edited
# copy lands in Overlay/ and can be changed there; keys without a non-empty FEAR_* setting keep
# their value. The stock files are UTF-16, so the file is written as UTF-16 LE with a BOM.

$name    = if ($Env:FEAR_CONFIG) { $Env:FEAR_CONFIG } else { 'lancommander' }
$userDir = Join-Path $Env:SERVER_ROOT $(if ($Env:FEAR_USER_DIR) { $Env:FEAR_USER_DIR } else { 'Monolith Productions/FEARCombat' })
$dir     = Join-Path $userDir 'ServerOptions'
$file    = Join-Path $dir "$name.txt"

if (-not (Test-Path -Path (Join-Path $Env:SERVER_ROOT 'FEARServer.exe'))) {
    Write-Log -Level Error "FEARServer.exe not found in $Env:SERVER_ROOT; skipping server configuration"
    return
}

if (-not (Test-Path -Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    chown -R "$($Env:UID):$($Env:GID)" $userDir
}

# Section names (the GameType value) by normalized name. Conquer All and Control are what the game
# calls CaptureAll and CaptureHold.
$gameTypes = [ordered]@{
    'deathmatch'           = 'DeathMatch'
    'teamdeathmatch'       = 'TeamDeathMatch'
    'elimination'          = 'Elimination'
    'teamelimination'      = 'TeamElimination'
    'slowmodeathmatch'     = 'SlowMoDeathmatch'
    'teamslowmodeathmatch' = 'TeamSlowMoDeathmatch'
    'ctf'                  = 'CTF'
    'slowmoctf'            = 'Slowmo CTF'
    'conquerall'           = 'CaptureAll'
    'captureall'           = 'CaptureAll'
    'control'              = 'CaptureHold'
    'capturehold'          = 'CaptureHold'
}

# Stock [ServerSettings] for a new file (from the game's own options files)
$defaults = [ordered]@{
    'GameType' = 'DeathMatch'; 'ServerMessage' = ''; 'UsePassword' = '0'; 'Password' = ''
    'AllowScmdCommands' = '0'; 'ScmdPassword' = ''; 'Port' = '27888'; 'BindToAddr' = ''
    'BandwidthServer' = '3'; 'BandwidthServerCustom' = '1500'; 'LANOnly' = '1'; 'Dedicated' = '1'
    'AllowContentDownload' = '1'; 'MaxDownloadRatePerClient' = '40960'; 'MaxDownloadRateAllClients' = '655360'
    'MaxSimultaneousDownloads' = '16'; 'MaxDownloadSize' = '-1'; 'RedirectURLs' = ''; 'ContentDownloadMessage' = ''
    'EnableScoringLog' = '0'; 'MaxScoringLogFileAge' = '0'
    'AllowVoteKick' = '1'; 'AllowVoteTeamKick' = '1'; 'AllowVoteBan' = '1'; 'AllowVoteNextRound' = '1'
    'AllowVoteNextMap' = '1'; 'AllowVoteSelectMap' = '1'; 'MinPlayersForVote' = '5'; 'MinPlayersForTeamVote' = '3'
    'VoteLifetime' = '30'; 'VoteBanDuration' = '60'; 'VoteDelay' = '0'; 'UsePunkBuster' = '0'
}

# Parse into ordered sections of ordered Key=Value pairs, keeping values verbatim. ReadAllLines
# detects the BOM, so both the stock UTF-16 files and ANSI files work.
$ini = [ordered]@{}

if (Test-Path -Path $file) {
    $section = $null
    foreach ($line in [System.IO.File]::ReadAllLines($file)) {
        if ($line -match '^\s*\[([^\]]+)\]') {
            $section = $Matches[1]
            if (-not $ini.Contains($section)) { $ini[$section] = [ordered]@{} }
        } elseif ($section -and $line -match '^\s*([^;=][^=]*?)\s*=(.*)$') {
            $ini[$section][$Matches[1]] = $Matches[2]
        }
    }
} else {
    $ini['ServerSettings'] = $defaults
    Write-Log "Creating ServerOptions/$name.txt"
}

function Set-Value([string] $Section, [string] $Key, [string] $Value) {
    if (-not $ini.Contains($Section)) { $ini[$Section] = [ordered]@{} }
    # The file format has no quoting; \n is a line break and \\ a backslash in messages
    $ini[$Section][$Key] = $Value -replace "`r?`n", ' '
}

function ConvertTo-Flag([string] $Value) {
    if ($Value -match '^(1|true|yes|on)$') { '1' } else { '0' }
}

foreach ($kv in $defaults.GetEnumerator()) {
    if (-not $ini['ServerSettings'].Contains($kv.Key)) { Set-Value 'ServerSettings' $kv.Key $kv.Value }
}

# Game type
$typeSection = $ini['ServerSettings']['GameType']
if ($Env:FEAR_GAME_TYPE) {
    $key = $Env:FEAR_GAME_TYPE.ToLowerInvariant() -replace '[^a-z0-9]', ''
    $typeSection = $gameTypes[$key]
    if (-not $typeSection) {
        throw "Unknown FEAR_GAME_TYPE '$Env:FEAR_GAME_TYPE' (use $(($gameTypes.Keys | Where-Object { $_ -notin 'captureall', 'capturehold' }) -join ', '))"
    }
}

Set-Value 'ServerSettings' 'GameType' $typeSection
Set-Value 'ServerSettings' 'Dedicated' '1'

if ($Env:FEAR_PORT)             { Set-Value 'ServerSettings' 'Port' $Env:FEAR_PORT }
if ($Env:FEAR_SERVER_MESSAGE)   { Set-Value 'ServerSettings' 'ServerMessage' $Env:FEAR_SERVER_MESSAGE }
if ($Env:FEAR_LAN_ONLY)         { Set-Value 'ServerSettings' 'LANOnly' (ConvertTo-Flag $Env:FEAR_LAN_ONLY) }
if ($Env:FEAR_CONTENT_DOWNLOAD) { Set-Value 'ServerSettings' 'AllowContentDownload' (ConvertTo-Flag $Env:FEAR_CONTENT_DOWNLOAD) }

if ($Env:FEAR_PASSWORD) {
    Set-Value 'ServerSettings' 'UsePassword' '1'
    Set-Value 'ServerSettings' 'Password' $Env:FEAR_PASSWORD
} else {
    Set-Value 'ServerSettings' 'UsePassword' '0'
}

# SCMD remote administration: in game, `scmd login <password>` in chat
if ($Env:FEAR_SCMD_PASSWORD) {
    Set-Value 'ServerSettings' 'AllowScmdCommands' '1'
    Set-Value 'ServerSettings' 'ScmdPassword' $Env:FEAR_SCMD_PASSWORD
} else {
    Set-Value 'ServerSettings' 'AllowScmdCommands' '0'
}

# Game type section. Keys the server doesn't find here use the game's defaults.
if (-not $ini.Contains($typeSection)) { $ini[$typeSection] = [ordered]@{} }

$settings = [ordered]@{
    'SessionName'  = $Env:FEAR_SERVER_NAME
    'MaxPlayers'   = $Env:FEAR_MAX_PLAYERS
    'ScoreLimit'   = $Env:FEAR_SCORE_LIMIT
    'TimeLimit'    = $Env:FEAR_TIME_LIMIT
    'NumRounds'    = $Env:FEAR_ROUNDS
    'FriendlyFire' = if ($Env:FEAR_FRIENDLY_FIRE) { ConvertTo-Flag $Env:FEAR_FRIENDLY_FIRE }
}

foreach ($s in $settings.GetEnumerator()) {
    if ($s.Value) { Set-Value $typeSection $s.Key $s.Value }
}

# Map rotation. A bare name goes in Worlds\ReleaseMultiplayer; give a path with a backslash for
# anything else. With no MissionN keys the server plays every map made for the game type.
$maps = "$Env:FEAR_MAPS".Trim()

if ($maps -ine 'config') {
    foreach ($key in @($ini[$typeSection].Keys)) {
        if ($key -match '^Mission\d+$') { $ini[$typeSection].Remove($key) }
    }

    # Stock F.E.A.R. Combat 1.08 maps. Every game type uses the same names (no CTF_ prefixes).
    $known = 'Asylum', 'Cafeteria', 'Campus', 'Construction', 'DeadWood', 'Depot', 'Docks', 'Evac',
        'Facility', 'Factory', 'Heliport', 'HighTech', 'Labs', 'Office', 'Refinery', 'SpillKill',
        'Stockpile', 'Streets', 'WaterWorks'

    $list = @($maps -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    for ($i = 0; $i -lt $list.Count; $i++) {
        $map = $list[$i].Replace('/', '\')
        if (-not $map.Contains('\')) {
            if ($map -notin $known) {
                Write-Log -Level Warning "'$map' is not a stock map; FEARServer skips maps it can't load (stock maps: $($known -join ', '))"
            }
            $map = "Worlds\ReleaseMultiplayer\$map"
        }
        Set-Value $typeSection "Mission$i" $map
    }
}

$lines = foreach ($s in $ini.GetEnumerator()) {
    "[$($s.Key)]"
    foreach ($kv in $s.Value.GetEnumerator()) { "$($kv.Key)=$($kv.Value)" }
}

[System.IO.File]::WriteAllText($file, (($lines -join "`r`n") + "`r`n"), [System.Text.UnicodeEncoding]::new($false, $true))
chown "$($Env:UID):$($Env:GID)" $file

$rotation = @($ini[$typeSection].Keys | Where-Object { $_ -match '^Mission\d+$' }).Count
Write-Log "Applied FEAR_* settings to ServerOptions/$name.txt ($typeSection, $(if ($rotation) { "$rotation maps" } else { 'all maps' }))"
