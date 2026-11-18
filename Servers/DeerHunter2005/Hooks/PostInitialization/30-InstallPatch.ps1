#Requires -Modules Logging

# Deer Hunter 2005 modern patch (https://github.com/LANCommander/LANCommander.Patches.DeerHunter2005).
# It raises the player cap, sets the animal population and respawns, and reports the hunts to
# LANCommander's match statistics.
#
# The release's dinput8.dll and dh2005patch.ini are built into the image, in /opt/dh2005patch. When
# DH2005_PATCH_ENABLED is on, this writes into Merged/, so into Overlay/:
#
#   dinput8.dll       The patch. dh2005-server loads it with WINEDLLOVERRIDES=dinput8=n,b
#   dh2005patch.ini   The release's ini with the DH2005_* and MATCH_STATS_* settings filled in.
#                     One that this hook didn't write is left alone
#   dh2005patch.log   The patch's log. .interposer/ keeps the match reports not delivered yet
#
# Turned off, dinput8.dll is removed again. The ini is kept.

$header = '; Generated from the DH2005_* and MATCH_STATS_* environment variables on every start'
$source = '/opt/dh2005patch'

function ConvertTo-Bool([string] $Value) {
    switch ($Value.Trim().ToLowerInvariant()) {
        { $_ -in 'true', '1', 'yes', 'on' }   { return '1' }
        { $_ -in 'false', '0', 'no', 'off' } { return '0' }
        default                              { return $null }
    }
}

function Get-Hash([string] $Path) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
}

$dll = Join-Path $Env:SERVER_ROOT 'dinput8.dll'
$ini = Join-Path $Env:SERVER_ROOT 'dh2005patch.ini'

if ((ConvertTo-Bool "$Env:DH2005_PATCH_ENABLED") -eq '0') {
    if (Test-Path -LiteralPath $dll -PathType Leaf) {
        Remove-Item -Force -LiteralPath $dll
        Write-Log "The patch is off; removed dinput8.dll"
    }
    return
}

if (-not (Test-Path -LiteralPath "$source/dinput8.dll" -PathType Leaf)) {
    Write-Log -Level Error "The patch is missing from $source"
    return
}

$owned = @()

if ((Get-Hash $dll) -ne (Get-Hash "$source/dinput8.dll")) {
    Copy-Item -Force -LiteralPath "$source/dinput8.dll" -Destination $dll
    $owned += $dll
}

$stats = switch (ConvertTo-Bool "$Env:MATCH_STATS_ENABLED") {
    '1'     { $true }
    '0'     { $false }
    default { [bool]($Env:MATCH_STATS_SERVER_URL -and $Env:MATCH_STATS_TOKEN) }
}

# The patch caps a match at MaxPlayers (16 to 64); -Max_Players then sets how many
$maxPlayers = 16
if ("$Env:DH2005_MAX_PLAYERS" -match '^\d+$') { $maxPlayers = [Math]::Min(64, [Math]::Max(16, [int]$Env:DH2005_MAX_PLAYERS)) }

# Section -> key -> value. Values left $null keep the release's default
$values = [ordered]@{
    'Saves'    = [ordered]@{ 'RedirectSaves' = '0' }   # keep the server's files in Game/, like the unpatched game
    'Gamepad'  = [ordered]@{ 'Gamepad' = '0' }
    'Presence' = [ordered]@{ 'RichPresence' = '0' }
    'Server'   = [ordered]@{ 'MaxPlayers' = "$maxPlayers" }
    'Animals'  = [ordered]@{
        'Population'               = $Env:DH2005_POPULATION
        'PopulationBySpecies'      = $Env:DH2005_POPULATION_BY_SPECIES
        'NearbyAnimals'            = $Env:DH2005_NEARBY_ANIMALS
        'NearbySameSpecies'        = $Env:DH2005_NEARBY_SAME_SPECIES
        'NearbyBySpecies'          = $Env:DH2005_NEARBY_BY_SPECIES
        'AllowRespawnBySpecies'    = $Env:DH2005_ALLOW_RESPAWN_BY_SPECIES
        'RespawnDistance'          = $Env:DH2005_RESPAWN_DISTANCE
        'RespawnDistanceBySpecies' = $Env:DH2005_RESPAWN_DISTANCE_BY_SPECIES
    }
    'Stats'    = [ordered]@{
        'MatchStatistics' = $(if ($stats) { '1' } else { '0' })
        'RecordChat'      = $(if ($Env:MATCH_STATS_RECORD_CHAT) { ConvertTo-Bool $Env:MATCH_STATS_RECORD_CHAT })
        'ServerUrl'       = $(if ($Env:MATCH_STATS_SERVER_URL) { $Env:MATCH_STATS_SERVER_URL.TrimEnd('/') })
        'Token'           = $(if ($Env:MATCH_STATS_TOKEN) { '%MATCH_STATS_TOKEN%' })
        'GameId'          = $Env:MATCH_STATS_GAME_ID
        'ServerId'        = $Env:MATCH_STATS_SERVER_ID
        'ReporterName'    = $Env:MATCH_STATS_REPORTER_NAME
    }
}

if ((Test-Path -LiteralPath $ini) -and -not "$(Get-Content -LiteralPath $ini -TotalCount 1)".StartsWith($header)) {
    Write-Log -Level Warning "dh2005patch.ini wasn't written by this image and is left alone, so the DH2005_* patch and MATCH_STATS_* settings aren't applied. Delete it to have it generated"
} else {
    $section = ''
    $lines = @($header)
    foreach ($line in Get-Content -LiteralPath "$source/dh2005patch.ini") {
        if ($line -match '^\s*\[(.+)\]\s*$') {
            $section = $Matches[1]
        } elseif ($line -match '^\s*([A-Za-z0-9_]+)\s*=' -and $values.Contains($section) -and $values[$section].Contains($Matches[1])) {
            $key = $Matches[1]
            $value = $values[$section][$key]
            if ($value) { $line = "$key=$($value.Trim())" }
        }
        $lines += $line
    }
    [System.IO.File]::WriteAllText($ini, ($lines -join "`r`n") + "`r`n")
    $owned += $ini
}

if ($owned) { chown "$($Env:UID):$($Env:GID)" @($owned) }

if ($stats) {
    foreach ($setting in 'MATCH_STATS_SERVER_URL', 'MATCH_STATS_TOKEN', 'MATCH_STATS_GAME_ID') {
        if (-not [Environment]::GetEnvironmentVariable($setting)) {
            Write-Log -Level Warning "Match statistics are on, but $setting is empty"
        }
    }
}

Write-Log "Deer Hunter 2005 patch installed (MaxPlayers $maxPlayers, match statistics $(if ($stats) { 'on' } else { 'off' }))"
