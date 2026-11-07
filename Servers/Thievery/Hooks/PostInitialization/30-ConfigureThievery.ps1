#Requires -Modules Logging

# Create the server ini (THIEVERY_INI, default System/Server.ini) from the mod's ThAux.ini on first
# start, then write the server settings into it. Thievery's own classes keep their settings in
# System/ThieveryMod.ini (config(ThieveryMod)), whatever ini= says, so the gameplay settings and
# the map rotation go there. Both are written through the merged view, so they land in Overlay/
# and can be edited there; keys without a THIEVERY_* setting are never touched.

$system   = Join-Path $Env:SERVER_ROOT 'System'
$template = Join-Path $system 'ThAux.ini'
$ini      = Join-Path $system $Env:THIEVERY_INI
$modIni   = Join-Path $system 'ThieveryMod.ini'

if (-not (Test-Path -Path $ini)) {
    if (-not (Test-Path -Path $template)) {
        Write-Log -Level Error "$template not found; skipping server configuration"
        return
    }

    Copy-Item -Path $template -Destination $ini
    Write-Log "Created $ini from ThAux.ini"
}

# The functions below work on $lines, the file loaded by Read-Ini
$script:lines   = $null
$script:newline = "`r`n"

function Read-Ini([string] $Path) {
    $text = [System.IO.File]::ReadAllText($Path)
    $script:newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $script:lines   = [System.Collections.Generic.List[string]]::new([string[]]($text -split "\r?\n"))
}

function Save-Ini([string] $Path) {
    [System.IO.File]::WriteAllText($Path, ($script:lines -join $script:newline))
    chown "$($Env:UID):$($Env:GID)" $Path
}

function Get-SectionRange([string] $Section) {
    $lines = $script:lines
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
    $lines = $script:lines
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
    $lines = $script:lines
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

# ---------------------------------------------------------------------------------------------
# Server ini: port, server info, players, passwords, master server uplink
# ---------------------------------------------------------------------------------------------
Read-Ini $ini

$settings = @(
    @('URL',                         'Port',          $Env:THIEVERY_PORT),
    @('Engine.GameReplicationInfo',  'ServerName',    $Env:THIEVERY_SERVER_NAME),
    @('Engine.GameReplicationInfo',  'ShortName',     $Env:THIEVERY_SHORT_NAME),
    @('Engine.GameReplicationInfo',  'AdminName',     $Env:THIEVERY_ADMIN_NAME),
    @('Engine.GameReplicationInfo',  'AdminEmail',    $Env:THIEVERY_ADMIN_EMAIL),
    @('Engine.GameReplicationInfo',  'MOTDLine1',     $Env:THIEVERY_MOTD),
    @('Engine.GameInfo',             'MaxPlayers',    $Env:THIEVERY_MAX_PLAYERS),
    @('Engine.GameInfo',             'MaxSpectators', $Env:THIEVERY_MAX_SPECTATORS),
    @('Engine.GameInfo',             'GamePassword',  $Env:THIEVERY_GAME_PASSWORD),
    @('Engine.GameInfo',             'AdminPassword', $Env:THIEVERY_ADMIN_PASSWORD),
    @('ThieveryMod.ThieveryDeathMatchPlus', 'FriendlyFireScale', $Env:THIEVERY_FRIENDLY_FIRE_SCALE)
)

foreach ($s in $settings) {
    if ($s[2]) { Set-IniValue $s[0] $s[1] $s[2] }
}

# ThAux.ini sends heartbeats to four master servers, two of which no longer resolve. LAN only by
# default; THIEVERY_MASTER_SERVER_UPLINK=true keeps a single uplink to 333networks, which still
# lists Unreal Engine 1 games.
$uplink  = 'ServerActors=IpServer.UdpServerUplink'
$removed = $script:lines.RemoveAll({ param($l) $l.StartsWith($uplink, [System.StringComparison]::OrdinalIgnoreCase) })
if (Test-True $Env:THIEVERY_MASTER_SERVER_UPLINK) {
    Add-IniLine 'Engine.GameEngine' "$uplink MasterServerAddress=master.333networks.com MasterServerPort=27900"
    Set-IniValue 'IpServer.UdpServerUplink' 'DoUplink' 'True'
    Write-Log "Master server uplink: master.333networks.com"
} else {
    Set-IniValue 'IpServer.UdpServerUplink' 'DoUplink' 'False'
    if ($removed) { Write-Log "Removed the master server uplinks from $Env:THIEVERY_INI" }
}

Save-Ini $ini
Write-Log "Applied THIEVERY_* server settings to $ini"

# ---------------------------------------------------------------------------------------------
# ThieveryMod.ini: gameplay settings and the map rotation
# ---------------------------------------------------------------------------------------------
if (-not (Test-Path -Path $modIni)) {
    Write-Log -Level Warning "$modIni not found; gameplay settings and map rotation not applied"
    return
}

Read-Ini $modIni

# TimeLimit and the rest of [ThieveryMod.ThieveryGameSettings] apply to every Thievery game type
$settings = @(
    @('ThieveryMod.ThieveryGameSettings', 'TimeLimit',         $Env:THIEVERY_TIME_LIMIT),
    @('ThieveryMod.ThieveryGameSettings', 'bBalanceTeams',     (ConvertTo-IniBool $Env:THIEVERY_BALANCE_TEAMS)),
    @('ThieveryMod.ThieveryGameSettings', 'GuardStartMoney',   $Env:THIEVERY_GUARD_START_MONEY),
    @('ThieveryMod.ThieveryGameSettings', 'ThievesStartMoney', $Env:THIEVERY_THIEVES_START_MONEY),
    @('ThieveryMod.ThieveryGameSettings', 'nPregameWaitTime',  $Env:THIEVERY_PREGAME_WAIT),
    @('ThieveryMod.ThieveryGameSettings', 'AISkill',           $Env:THIEVERY_AI_SKILL)
)

foreach ($s in $settings) {
    if ($s[2]) { Set-IniValue $s[0] $s[1] $s[2] }
}

# Map rotation: Maps[0..31] of [ThieveryMod.ThieveryMapList]. Maps are looked up in
# Thievery/th-maps/ and Maps/.
if ($Env:THIEVERY_MAPS) {
    $mapList = 'ThieveryMod.ThieveryMapList'

    $available = [ordered]@{}
    foreach ($dir in @('Thievery/th-maps', 'Maps')) {
        $path = Join-Path $Env:SERVER_ROOT $dir
        if (-not (Test-Path -Path $path)) {
            # Wine is case-insensitive, Linux isn't: find the folder whatever its case
            $parent = Join-Path $Env:SERVER_ROOT (Split-Path -Parent $dir)
            $path = Get-ChildItem -Path $parent -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -ieq (Split-Path -Leaf $dir) } |
                Select-Object -First 1 -ExpandProperty FullName
        }
        if (-not $path) { continue }

        Get-ChildItem -Path $path -Filter '*.unr' -File -ErrorAction SilentlyContinue |
            Where-Object { -not $available.Contains($_.BaseName.ToLowerInvariant()) } |
            ForEach-Object { $available[$_.BaseName.ToLowerInvariant()] = $_.BaseName }
    }

    $rotation = @()
    foreach ($map in @($Env:THIEVERY_MAPS -split '[,;\s]+' | Where-Object { $_ })) {
        $map = $map -replace '\.unr$', ''
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
        Set-IniValue $mapList "Maps[$i]" $(if ($i -lt $rotation.Count) { "$($rotation[$i]).unr" } else { '' })
    }

    # The game finds the current map in the list and moves on from there; MapNum only matters when
    # the start map isn't in it, so point it at the last entry to start the rotation at the top
    Set-IniValue $mapList 'MapNum' "$([Math]::Max($rotation.Count - 1, 0))"

    Write-Log "Map rotation ($mapList): $($rotation -join ', ')"
}

Save-Ini $modIni
Write-Log "Applied THIEVERY_* gameplay settings to $modIni"
