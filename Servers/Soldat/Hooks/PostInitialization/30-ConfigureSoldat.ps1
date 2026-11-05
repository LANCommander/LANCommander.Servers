#Requires -Modules Logging

# Write the SOLDAT_* settings into soldat.ini and the map rotation into mapslist.txt. Both are
# edited through the merged view, so they land in Overlay/ and can be edited there; keys without a
# SOLDAT_* setting are never touched.

$ini = Join-Path $Env:SERVER_ROOT 'soldat.ini'
if (-not (Test-Path -Path $ini)) {
    Write-Log -Level Error "$ini not found; skipping server configuration"
    return
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

# Set Key=Value in [Section], replacing the existing Key= line or appending to the section
function Set-IniValue([string] $Section, [string] $Key, [string] $Value) {
    $range = Get-SectionRange $Section
    if (-not $range) {
        if ($lines.Count -and $lines[$lines.Count - 1] -ne '') { $lines.Add('') }
        $lines.Add("[$Section]")
        $lines.Add("$Key=$Value")
        return
    }

    $start, $end = $range
    for ($i = $start + 1; $i -lt $end; $i++) {
        if ($lines[$i].StartsWith("$Key=", [System.StringComparison]::OrdinalIgnoreCase)) {
            $lines[$i] = "$Key=$Value"
            return
        }
    }

    $at = $end
    while ($at -gt $start + 1 -and [string]::IsNullOrWhiteSpace($lines[$at - 1])) { $at-- }
    $lines.Insert($at, "$Key=$Value")
}

function ConvertTo-Bit([string] $Value) {
    if (-not $Value) { return '' }
    if ($Value -in 'true', '1', 'yes') { '1' } else { '0' }
}

# GameStyle numbers, short names, score limit keys and map name prefixes
$styles = @(
    @{ Style = 0; Names = @('dm', 'deathmatch');              Limit = 'Deathmatch_Limit';   Prefix = '';     Teams = $false },
    @{ Style = 1; Names = @('pm', 'pointmatch');              Limit = 'Pointmatch_Limit';   Prefix = '';     Teams = $false },
    @{ Style = 2; Names = @('tm', 'teammatch');               Limit = 'Teammatch_Limit';    Prefix = '';     Teams = $true },
    @{ Style = 3; Names = @('ctf', 'capturetheflag');         Limit = 'Capture_Limit';      Prefix = 'ctf_'; Teams = $true },
    @{ Style = 4; Names = @('rm', 'rambomatch');              Limit = 'Rambomatch_Limit';   Prefix = '';     Teams = $false },
    @{ Style = 5; Names = @('inf', 'infiltration');           Limit = 'Infiltration_Limit'; Prefix = 'inf_'; Teams = $true },
    @{ Style = 6; Names = @('htf', 'holdtheflag');            Limit = 'Hold_Limit';         Prefix = 'htf_'; Teams = $true }
)

$typeName = if ($Env:SOLDAT_GAME_TYPE) { $Env:SOLDAT_GAME_TYPE.ToLowerInvariant() } else { 'ctf' }
$style = $styles | Where-Object { $_.Names -contains $typeName -or "$($_.Style)" -eq $typeName } | Select-Object -First 1
if (-not $style) {
    Write-Log -Level Warning "Unknown SOLDAT_GAME_TYPE '$Env:SOLDAT_GAME_TYPE'; using ctf"
    $style = $styles[3]
}

$settings = @(
    @('NETWORK', 'Port',              $Env:SOLDAT_PORT),
    @('NETWORK', 'Server_Name',       $Env:SOLDAT_SERVER_NAME),
    @('NETWORK', 'Greeting_Message',  $Env:SOLDAT_GREETING),
    @('NETWORK', 'Server_Info',       $Env:SOLDAT_SERVER_INFO),
    @('NETWORK', 'Max_Players',       $Env:SOLDAT_MAX_PLAYERS),
    @('NETWORK', 'Max_Spectators',    $Env:SOLDAT_MAX_SPECTATORS),
    @('NETWORK', 'Game_Password',     $Env:SOLDAT_GAME_PASSWORD),
    @('NETWORK', 'Admin_Password',    $Env:SOLDAT_ADMIN_PASSWORD),
    @('NETWORK', 'Balance_Teams',     (ConvertTo-Bit $Env:SOLDAT_BALANCE_TEAMS)),
    @('GAME',    'GameStyle',         "$($style.Style)"),
    @('GAME',    $style.Limit,        $Env:SOLDAT_SCORE_LIMIT),
    @('GAME',    'Time_Limit',        $Env:SOLDAT_TIME_LIMIT),
    @('GAME',    'Respawn_Time',      $Env:SOLDAT_RESPAWN_TIME),
    @('GAME',    'Friendly_Fire',     (ConvertTo-Bit $Env:SOLDAT_FRIENDLY_FIRE)),
    @('GAME',    'Realistic_Mode',    (ConvertTo-Bit $Env:SOLDAT_REALISTIC)),
    @('GAME',    'Survival_Mode',     (ConvertTo-Bit $Env:SOLDAT_SURVIVAL)),
    @('BOTS',    'Difficulty',        $Env:SOLDAT_BOT_DIFFICULTY)
)

# A LAN server doesn't register with the soldat.pl lobby or All-Seeing Eye
if ($Env:SOLDAT_LAN) {
    $register = if ((ConvertTo-Bit $Env:SOLDAT_LAN) -eq '1') { '0' } else { '1' }
    $settings += , @('NETWORK', 'Lobby_Register', $register)
    $settings += , @('NETWORK', 'ASE_Register',   $register)
}

# Bots: Random_Bots in free-for-all styles, split over Alpha and Bravo (Random_Bots_1/_2) in team styles
if ($Env:SOLDAT_BOTS) {
    $bots = [int] $Env:SOLDAT_BOTS
    if ($style.Teams) {
        $settings += , @('GAME', 'Random_Bots',   '0')
        $settings += , @('GAME', 'Random_Bots_1', "$([Math]::Ceiling($bots / 2))")
        $settings += , @('GAME', 'Random_Bots_2', "$([Math]::Floor($bots / 2))")
    } else {
        $settings += , @('GAME', 'Random_Bots',   "$bots")
        $settings += , @('GAME', 'Random_Bots_1', '0')
        $settings += , @('GAME', 'Random_Bots_2', '0')
    }
}

foreach ($s in $settings) {
    if ($s[2]) { Set-IniValue $s[0] $s[1] $s[2] }
}

[System.IO.File]::WriteAllText($ini, ($lines -join $newline))
chown "$($Env:UID):$($Env:GID)" $ini
Write-Log "Applied SOLDAT_* settings to $ini (GameStyle $($style.Style), $($style.Names[0]))"

# Map rotation. SOLDAT_MAPS=keep leaves mapslist.txt alone; empty = every installed map for the
# game type (ctf_*, inf_*, htf_* or the unprefixed deathmatch maps)
$mapsList = Join-Path $Env:SERVER_ROOT 'mapslist.txt'
if ($Env:SOLDAT_MAPS -ieq 'keep') {
    Write-Log "SOLDAT_MAPS=keep; mapslist.txt left as it is"
    return
}

$available = [ordered]@{}
Get-ChildItem -Path (Join-Path $Env:SERVER_ROOT 'maps') -Filter '*.pms' -File -ErrorAction SilentlyContinue |
    Sort-Object Name | ForEach-Object { $available[$_.BaseName.ToLowerInvariant()] = $_.BaseName }

if ($Env:SOLDAT_MAPS) {
    $maps = @()
    foreach ($map in @($Env:SOLDAT_MAPS -split '[,;\s]+' | Where-Object { $_ })) {
        $map = $map -replace '\.pms$', ''
        if ($available.Count -and -not $available.Contains($map.ToLowerInvariant())) {
            Write-Log -Level Warning "Map $map is not installed; left out of the rotation"
            continue
        }
        $maps += $(if ($available.Count) { $available[$map.ToLowerInvariant()] } else { $map })
    }
} elseif ($style.Prefix) {
    $maps = @($available.Values | Where-Object { $_.StartsWith($style.Prefix, [System.StringComparison]::OrdinalIgnoreCase) })
} else {
    $maps = @($available.Values | Where-Object { $_ -notmatch '^(ctf|inf|htf)_' })
}

if (-not $maps) {
    Write-Log -Level Warning "No maps for the rotation; mapslist.txt left as it is"
    return
}

[System.IO.File]::WriteAllText($mapsList, ($maps -join "`r`n") + "`r`n")
chown "$($Env:UID):$($Env:GID)" $mapsList
Write-Log "Map rotation: $($maps -join ', ')"
