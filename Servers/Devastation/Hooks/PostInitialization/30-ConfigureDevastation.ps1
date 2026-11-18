#Requires -Modules Logging

# Create the server ini (DEVASTATION_INI, default System/Server.ini) from the game's Default.ini on
# first start, then write the DEVASTATION_* settings and the map rotation into it. It's created
# through the merged view, so it lands in Overlay/ and can be edited there; keys without a
# DEVASTATION_* setting are never touched.

$system   = Join-Path $Env:SERVER_ROOT 'System'
$template = Join-Path $system 'Default.ini'
$ini      = Join-Path $system $Env:DEVASTATION_INI

if (-not (Test-Path -Path $ini)) {
    if (-not (Test-Path -Path $template)) {
        Write-Log -Level Error "$template not found; skipping server configuration"
        return
    }

    Copy-Item -Path $template -Destination $ini
    Write-Log "Created $ini from Default.ini"
}

$text    = [System.IO.File]::ReadAllText($ini)
$newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
$lines   = [System.Collections.Generic.List[string]]::new([string[]]($text -split "\r?\n"))

function Get-SectionRange([string] $Section) {
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -ieq "[$Section]") { $start = $i; break }
    }
    if ($start -lt 0) { return $null }

    $end = $start + 1
    while ($end -lt $lines.Count -and -not $lines[$end].StartsWith('[')) { $end++ }
    return @($start, $end)
}

# Insert a line after the section's last non-blank line, creating the section if needed
function Add-IniLine([string] $Section, [string] $Line) {
    $range = Get-SectionRange $Section
    if (-not $range) {
        if ($lines.Count -and $lines[$lines.Count - 1] -ne '') { $lines.Add('') }
        $lines.Add("[$Section]")
        $lines.Add($Line)
        return
    }

    $start, $end = $range
    $at = $end
    while ($at -gt $start + 1 -and [string]::IsNullOrWhiteSpace($lines[$at - 1])) { $at-- }
    $lines.Insert($at, $Line)
}

# Set Key=Value in [Section], replacing the first existing Key= line or appending to the section.
# StartsWith, not -like: keys such as Maps[0] contain wildcard characters.
function Set-IniValue([string] $Section, [string] $Key, [string] $Value) {
    $range = Get-SectionRange $Section
    if ($range) {
        for ($i = $range[0] + 1; $i -lt $range[1]; $i++) {
            if ($lines[$i].StartsWith("$Key=", [System.StringComparison]::OrdinalIgnoreCase)) {
                $lines[$i] = "$Key=$Value"
                return
            }
        }
    }
    Add-IniLine $Section "$Key=$Value"
}

function Get-IniValue([string] $Section, [string] $Key) {
    $range = Get-SectionRange $Section
    if (-not $range) { return $null }

    for ($i = $range[0] + 1; $i -lt $range[1]; $i++) {
        if ($lines[$i].StartsWith("$Key=", [System.StringComparison]::OrdinalIgnoreCase)) { return $lines[$i].Substring($Key.Length + 1) }
    }
    return $null
}

function Test-True([string] $Value) { return $Value -in @('true', '1', 'yes') }

# Game types: short names (same table as the devastation-server launcher), map prefixes and the
# engine's defaults for the per-mode rules
$gameTypes = [ordered]@{
    'DTerritories.DTerrGameInfo'   = @{ Prefix = 'DTT'; Names = @('territories', 'dtt') }
    'DTerritories.DCTFGameInfo'    = @{ Prefix = 'CTF'; Names = @('ctf') }
    'DGamePlay.DStreetWarGameInfo' = @{ Prefix = 'DDM'; Names = @('streetwar', 'dm', 'ddm') }
    'DGamePlay.DTeamStreetWarGI'   = @{ Prefix = 'DDM'; Names = @('teamstreetwar', 'tdm') }
}
$prefixDefaults = @{ 'DTT' = 'DTerritories.DTerrGameInfo'; 'CTF' = 'DTerritories.DCTFGameInfo'; 'DDM' = 'DGamePlay.DStreetWarGameInfo' }
$territories = 'DTerritories.DTerrGameInfo'

function Resolve-GameType([string] $Name) {
    foreach ($class in $gameTypes.Keys) {
        if ($Name -ieq $class -or $gameTypes[$class].Names -contains $Name.ToLowerInvariant()) { return $class }
    }
    return $Name
}

function Get-MapPrefix([string] $Map) { return ($Map -split '-', 2)[0].ToUpperInvariant() }

$gameType = Resolve-GameType $(if ($Env:DEVASTATION_GAME_TYPE) { $Env:DEVASTATION_GAME_TYPE } else { 'territories' })

$gameMode = if ($Env:DEVASTATION_SIMULATION) { if (Test-True $Env:DEVASTATION_SIMULATION) { '1' } else { '0' } }
$karma    = if ($Env:DEVASTATION_FULL_PHYSICS) { if (Test-True $Env:DEVASTATION_FULL_PHYSICS) { 'True' } else { 'False' } }

$settings = @(
    @('URL',                         'Port',         $Env:DEVASTATION_PORT),
    @('Engine.GameReplicationInfo',  'ServerName',   $Env:DEVASTATION_SERVER_NAME),
    @('Engine.GameReplicationInfo',  'ShortName',    $Env:DEVASTATION_SHORT_NAME),
    @('Engine.GameReplicationInfo',  'AdminName',    $Env:DEVASTATION_ADMIN_NAME),
    @('Engine.GameReplicationInfo',  'AdminEmail',   $Env:DEVASTATION_ADMIN_EMAIL),
    @('Engine.GameReplicationInfo',  'MOTDLine1',    $Env:DEVASTATION_MOTD),
    @('Engine.GameInfo',             'MaxPlayers',   $Env:DEVASTATION_MAX_PLAYERS),
    @('Engine.GameInfo',             'GamePassword', $Env:DEVASTATION_GAME_PASSWORD),
    @('Engine.GameInfo',             'AdminPassword', $Env:DEVASTATION_ADMIN_PASSWORD),
    @('Engine.GameInfo',             'bKarmaMP',     $karma),
    @('DCore.DGameInfo',             'InitialBots',  $Env:DEVASTATION_BOTS),
    @('DGamePlay.DSWMapList',        'GameMode',     $gameMode),
    @('DGamePlay.DSWMapList',        'bKarmaMP',     $karma)
)

# Per-mode rules live in each game class's own section. They're written to every class, because
# a rotation can mix game types.
foreach ($class in $gameTypes.Keys) {
    $settings += , @($class, 'TimeLimit', $Env:DEVASTATION_TIME_LIMIT)
    $settings += , @($class, 'FragLimit', $Env:DEVASTATION_FRAG_LIMIT)
    $settings += , @($class, 'GameMode',  $gameMode)
}
$settings += , @($territories, 'RoundLimit',         $Env:DEVASTATION_ROUND_LIMIT)
$settings += , @($territories, 'TimeLimitRound',     $Env:DEVASTATION_ROUND_TIME_LIMIT)
$settings += , @($territories, 'SuddenDeathSeconds', $Env:DEVASTATION_SUDDEN_DEATH_SECONDS)

foreach ($s in $settings) {
    if ($s[2]) { Set-IniValue $s[0] $s[1] $s[2] }
}

# A rule for a map URL: the class's own section, then its parent's (Team StreetWar inherits from
# StreetWar), then the engine default
function Get-Rule([string] $Class, [string] $Key, [string] $Default) {
    foreach ($section in @($Class, $(if ($Class -eq 'DGamePlay.DTeamStreetWarGI') { 'DGamePlay.DStreetWarGameInfo' }))) {
        if (-not $section) { continue }
        $v = Get-IniValue $section $Key
        if ($v) { return $v }
    }
    return $Default
}

# Map rotation: [DGamePlay.DSWMapList] Maps[n] with a per-map URL in MapParams[n] (the in-game
# host menu writes the same thing), so one rotation can mix game types
$mapsDir = Join-Path $Env:SERVER_ROOT 'Maps'
$available = [ordered]@{}
Get-ChildItem -Path $mapsDir -Filter '*.dvs' -File -ErrorAction SilentlyContinue | Sort-Object Name |
    ForEach-Object { $available[$_.BaseName.ToLowerInvariant()] = $_.BaseName }

$entries = @($Env:DEVASTATION_MAPS -split '[,;\s]+' | Where-Object { $_ })
if (-not $entries -and $gameTypes.Contains($gameType)) {
    # Default: every installed map for the game type
    $prefix  = $gameTypes[$gameType].Prefix
    $entries = @($available.Values | Where-Object { (Get-MapPrefix $_) -eq $prefix })
}

$rotation = @()
foreach ($entry in $entries) {
    $map, $type = $entry -split ':', 2
    $map = $map -replace '\.dvs$', ''

    if ($available.Count -and -not $available.Contains($map.ToLowerInvariant())) {
        Write-Log -Level Warning "Map $map is not installed; left out of the rotation"
        continue
    }
    if ($available.Count) { $map = $available[$map.ToLowerInvariant()] }

    if ($type) {
        $class = Resolve-GameType $type
    } elseif ($gameTypes.Contains($gameType) -and $gameTypes[$gameType].Prefix -eq (Get-MapPrefix $map)) {
        $class = $gameType
    } elseif ($prefixDefaults.ContainsKey((Get-MapPrefix $map))) {
        $class = $prefixDefaults[(Get-MapPrefix $map)]
    } else {
        $class = $gameType
    }

    $timeLimit = Get-Rule $class 'TimeLimit' '20'
    if ($class -eq $territories) {
        $params = "?game=${class}?timelimit=${timeLimit}" +
            "?roundtimelimit=$(Get-Rule $class 'TimeLimitRound' '600')" +
            "?RoundLimit=$(Get-Rule $class 'RoundLimit' '6')" +
            "?SuddenDeathSec=$(Get-Rule $class 'SuddenDeathSeconds' '120')"
    } else {
        $params = "?game=${class}?timelimit=${timeLimit}?fraglimit=$(Get-Rule $class 'FragLimit' '15')"
    }

    if ($rotation.Count -ge 32) {
        Write-Log -Level Warning "The rotation holds 32 maps; left out $map"
        continue
    }
    $rotation += , @($map, $params)
}

if ($rotation.Count) {
    for ($i = 0; $i -lt 32; $i++) {
        $m = if ($i -lt $rotation.Count) { "$($rotation[$i][0]).dvs" } else { '' }
        $p = if ($i -lt $rotation.Count) { $rotation[$i][1] } else { '' }
        Set-IniValue 'DGamePlay.DSWMapList' "Maps[$i]" $m
        Set-IniValue 'DGamePlay.DSWMapList' "MapParams[$i]" $p
    }

    # Continue after the start map; if it isn't in the rotation, start at the top
    $startMap = ($Env:DEVASTATION_MAP -replace '\.dvs$', '')
    $mapNum = $rotation.Count - 1
    for ($i = 0; $i -lt $rotation.Count; $i++) {
        if ($rotation[$i][0] -ieq $startMap) { $mapNum = $i; break }
    }
    Set-IniValue 'DGamePlay.DSWMapList' 'MapNum' "$mapNum"

    Write-Log "Map rotation: $(($rotation | ForEach-Object { $_[0] }) -join ', ')"
} else {
    Write-Log -Level Warning "No map rotation was set; [DGamePlay.DSWMapList] in $Env:DEVASTATION_INI is left as it is"
}

# The stock MasterServerUplink points at a dead master server and only retries. The GameSpy
# uplink points at OpenSpy, a replacement master server; it's dropped by default for LAN servers.
$removed = $lines.RemoveAll({ param($l) $l.StartsWith('ServerActors=IpDrv.MasterServerUplink', [System.StringComparison]::OrdinalIgnoreCase) })
if ($removed) { Write-Log "Removed the dead MasterServerUplink from $Env:DEVASTATION_INI" }

$gamespyUplink = 'ServerActors=IpDrv.UdpGamespyUplink'
if (Test-True $Env:DEVASTATION_MASTER_SERVER_UPLINK) {
    if (-not ($lines | Where-Object { $_.StartsWith($gamespyUplink, [System.StringComparison]::OrdinalIgnoreCase) })) {
        Add-IniLine 'Engine.GameEngine' "$gamespyUplink MasterServerAddress=master.openspy.com MasterServerPort=27900"
        Write-Log "Added the OpenSpy master server uplink to $Env:DEVASTATION_INI"
    }
} else {
    $removed = $lines.RemoveAll({ param($l) $l.StartsWith($gamespyUplink, [System.StringComparison]::OrdinalIgnoreCase) })
    if ($removed) { Write-Log "Removed the master server uplink from $Env:DEVASTATION_INI" }
}

[System.IO.File]::WriteAllText($ini, ($lines -join $newline))
chown "$($Env:UID):$($Env:GID)" $ini

Write-Log "Applied DEVASTATION_* settings to $ini"
