#Requires -Modules Logging

# Create the server ini (RUNE_INI, default System/Server.ini) from the game's Default.ini on first
# start, then write the RUNE_* settings and the map rotation into it. It's created through the
# merged view, so it lands in Overlay/ and can be edited there; keys without a RUNE_* setting are
# never touched.

$system   = Join-Path $Env:SERVER_ROOT 'System'
$template = Join-Path $system 'Default.ini'
$ini      = Join-Path $system $Env:RUNE_INI

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

function Test-True([string] $Value) { return $Value -in @('true', '1', 'yes') }
function ConvertTo-IniBool([string] $Value) {
    if (-not $Value) { return '' }
    if (Test-True $Value) { return 'True' } else { return 'False' }
}

# Game types: short names (same table as the rune-server launcher), map prefixes and each class's
# map list (MapListType)
$gameTypes = [ordered]@{
    'RuneI.RuneMultiPlayer' = @{ Prefix = 'DM'; MapList = 'RuneI.DMmaplist';   Names = @('deathmatch', 'dm') }
    'RuneI.TeamGame'        = @{ Prefix = 'DM'; MapList = 'RuneI.DMmaplist';   Names = @('team', 'teamgame', 'tdm') }
    'Arena.ArenaGameInfo'   = @{ Prefix = 'AR'; MapList = 'Arena.ARMapList';   Names = @('arena', 'ar') }
    'HeadBall.HeadBallGame' = @{ Prefix = 'HB'; MapList = 'HeadBall.HBmaplist'; Names = @('headball', 'hb') }
}

function Resolve-GameType([string] $Name) {
    foreach ($class in $gameTypes.Keys) {
        if ($Name -ieq $class -or $gameTypes[$class].Names -contains $Name.ToLowerInvariant()) { return $class }
    }
    return $Name
}

$gameType = Resolve-GameType $(if ($Env:RUNE_GAME_TYPE) { $Env:RUNE_GAME_TYPE } else { 'deathmatch' })

# FragLimit, TimeLimit, bHardCoreMode and bMegaSpeed are globalconfig in RuneMultiPlayer, so every
# game type reads them from that section. bAllowLimbSever, FriendlyFireScale and GoalTeamScore are
# per class.
$settings = @(
    @('URL',                         'Port',          $Env:RUNE_PORT),
    @('Engine.GameReplicationInfo',  'ServerName',    $Env:RUNE_SERVER_NAME),
    @('Engine.GameReplicationInfo',  'ShortName',     $Env:RUNE_SHORT_NAME),
    @('Engine.GameReplicationInfo',  'AdminName',     $Env:RUNE_ADMIN_NAME),
    @('Engine.GameReplicationInfo',  'AdminEmail',    $Env:RUNE_ADMIN_EMAIL),
    @('Engine.GameReplicationInfo',  'MOTDLine1',     $Env:RUNE_MOTD),
    @('Engine.GameInfo',             'MaxPlayers',    $Env:RUNE_MAX_PLAYERS),
    @('Engine.GameInfo',             'MaxSpectators', $Env:RUNE_MAX_SPECTATORS),
    @('Engine.GameInfo',             'GamePassword',  $Env:RUNE_GAME_PASSWORD),
    @('Engine.GameInfo',             'AdminPassword', $Env:RUNE_ADMIN_PASSWORD),
    @('RuneI.RuneMultiPlayer',       'FragLimit',     $Env:RUNE_FRAG_LIMIT),
    @('RuneI.RuneMultiPlayer',       'TimeLimit',     $Env:RUNE_TIME_LIMIT),
    @('RuneI.RuneMultiPlayer',       'bHardCoreMode', (ConvertTo-IniBool $Env:RUNE_HARDCORE)),
    @('RuneI.RuneMultiPlayer',       'bMegaSpeed',    (ConvertTo-IniBool $Env:RUNE_MEGA_SPEED))
)

foreach ($class in $gameTypes.Keys) {
    $settings += , @($class, 'bAllowLimbSever', (ConvertTo-IniBool $Env:RUNE_LIMB_SEVER))
}
foreach ($class in @('RuneI.TeamGame', 'HeadBall.HeadBallGame')) {
    $settings += , @($class, 'FriendlyFireScale', $Env:RUNE_FRIENDLY_FIRE_SCALE)
    $settings += , @($class, 'GoalTeamScore',     $Env:RUNE_GOAL_TEAM_SCORE)
}

foreach ($s in $settings) {
    if ($s[2]) { Set-IniValue $s[0] $s[1] $s[2] }
}

# Map rotation: Maps[0..31] of the game type's map list. With an empty list the game cycles
# through every installed map with the game type's prefix (DM-, AR-, HB-).
if ($Env:RUNE_MAPS) {
    $mapList = if ($gameTypes.Contains($gameType)) { $gameTypes[$gameType].MapList } else { 'RuneI.DMmaplist' }

    $available = [ordered]@{}
    Get-ChildItem -Path (Join-Path $Env:SERVER_ROOT 'Maps') -Filter '*.run' -File -ErrorAction SilentlyContinue |
        ForEach-Object { $available[$_.BaseName.ToLowerInvariant()] = $_.BaseName }

    $rotation = @()
    foreach ($map in @($Env:RUNE_MAPS -split '[,;\s]+' | Where-Object { $_ })) {
        $map = $map -replace '\.run$', ''
        if ($available.Count -and -not $available.Contains($map.ToLowerInvariant())) {
            Write-Log -Level Warning "Map $map is not installed; left out of the rotation"
            continue
        }
        if ($available.Count) { $map = $available[$map.ToLowerInvariant()] }

        if ($rotation.Count -ge 32) {
            Write-Log -Level Warning "The rotation holds 32 maps; left out $map"
            continue
        }
        $rotation += $map
    }

    for ($i = 0; $i -lt 32; $i++) {
        Set-IniValue $mapList "Maps[$i]" $(if ($i -lt $rotation.Count) { "$($rotation[$i]).run" } else { '' })
    }

    # The game finds the current map in the list and moves on from there; MapNum only matters when
    # the start map isn't in it, so point it at the last entry to start the rotation at the top
    Set-IniValue $mapList 'MapNum' "$([Math]::Max($rotation.Count - 1, 0))"

    Write-Log "Map rotation ($mapList): $($rotation -join ', ')"
}

# Web admin (UWeb.WebServer is in ServerActors by default and does nothing while bEnabled=False)
if (Test-True $Env:RUNE_WEB_ADMIN) {
    Set-IniValue 'UWeb.WebServer' 'bEnabled' 'True'
    Set-IniValue 'UWeb.WebServer' 'ListenPort' $Env:RUNE_WEB_ADMIN_PORT
    if ($Env:RUNE_WEB_ADMIN_USER) { Set-IniValue 'RuneServerAdmin.RuneServerAdmin' 'AdminUsername' $Env:RUNE_WEB_ADMIN_USER }
    if ($Env:RUNE_ADMIN_PASSWORD) {
        Set-IniValue 'RuneServerAdmin.RuneServerAdmin' 'AdminPassword' $Env:RUNE_ADMIN_PASSWORD
    } else {
        Write-Log -Level Warning "RUNE_WEB_ADMIN is on without RUNE_ADMIN_PASSWORD; the web admin keeps the password from $Env:RUNE_INI (admin by default)"
    }
} else {
    Set-IniValue 'UWeb.WebServer' 'bEnabled' 'False'
}

# The stock uplink points at GameSpy's dead master server and only retries. With
# RUNE_MASTER_SERVER_UPLINK=true it points at 333networks, which still lists Unreal Engine 1 games.
$uplink = 'ServerActors=IpServer.UdpServerUplink'
$removed = $lines.RemoveAll({ param($l) $l.StartsWith($uplink, [System.StringComparison]::OrdinalIgnoreCase) })
if (Test-True $Env:RUNE_MASTER_SERVER_UPLINK) {
    Add-IniLine 'Engine.GameEngine' "$uplink MasterServerAddress=master.333networks.com MasterServerPort=27900"
    Set-IniValue 'IpServer.UdpServerUplink' 'DoUplink' 'True'
    Set-IniValue 'IpServer.UdpServerUplink' 'MasterServerAddress' 'master.333networks.com'
    Set-IniValue 'IpServer.UdpServerUplink' 'MasterServerPort' '27900'
    Write-Log "Master server uplink: master.333networks.com"
} elseif ($removed) {
    Write-Log "Removed the master server uplink from $Env:RUNE_INI"
}

[System.IO.File]::WriteAllText($ini, ($lines -join $newline))
chown "$($Env:UID):$($Env:GID)" $ini

Write-Log "Applied RUNE_* settings to $ini"
