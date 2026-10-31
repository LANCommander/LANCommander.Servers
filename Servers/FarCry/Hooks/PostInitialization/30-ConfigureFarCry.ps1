#Requires -Modules Logging

# Write the FC_* settings into the server profile, Profiles/server/<FC_PROFILE>_server.cfg. A
# profile is a Lua script of `cvar = "value"` lines, the format the game's Create Server menu
# saves, and `SProfile_run <FC_PROFILE>` runs it and loads gr_NextMap. The file is edited through
# the merged view, so the edited copy lands in Overlay/ and can be changed there; cvars without a
# non-empty FC_* setting keep their value, and any other cvar can be added by hand.
#
# FC_MAPCYCLE is written to Profiles/server/<FC_PROFILE>_mapcycle.txt and the profile points
# sv_mapcyclefile at it.

$profileName = if ($Env:FC_PROFILE) { $Env:FC_PROFILE } else { 'LANCommander' }
$serverDir   = Join-Path $Env:SERVER_ROOT 'Profiles/server'
$file        = Join-Path $serverDir "$($profileName)_server.cfg"

if (-not (Test-Path -Path (Join-Path $Env:SERVER_ROOT 'Bin32/FarCry_WinSV.exe'))) {
    Write-Log -Level Error "Bin32/FarCry_WinSV.exe not found in $Env:SERVER_ROOT; skipping server configuration"
    return
}

New-Item -ItemType Directory -Path $serverDir -Force | Out-Null

# Values are kept as written (quoted Lua strings or bare numbers); keep the file's order
$settings = [ordered]@{}

if (Test-Path -Path $file) {
    foreach ($line in [System.IO.File]::ReadAllLines($file)) {
        if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*;?\s*$') {
            $settings[$Matches[1]] = $Matches[2]
        }
    }
}

function ConvertTo-LuaString([string] $Value) {
    '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"'
}

function ConvertTo-Flag([string] $Value) {
    if ($Value -match '^(1|true|yes|on)$') { '1' } else { '0' }
}

# Cvar names are case-insensitive to the game; reuse the file's spelling if it has one
function Set-Cvar([string] $Name, [string] $Value) {
    $key = @($settings.Keys) | Where-Object { $_ -ieq $Name } | Select-Object -First 1
    if (-not $key) { $key = $Name }
    $settings[$key] = ConvertTo-LuaString $Value
}

$values = [ordered]@{
    'sv_name'          = $Env:FC_SERVER_NAME
    'sv_ServerType'    = $Env:FC_SERVER_TYPE
    'g_GameType'       = $Env:FC_GAME_TYPE
    'gr_NextMap'       = $Env:FC_MAP
    'sv_maxplayers'    = $Env:FC_MAX_PLAYERS
    'gr_TimeLimit'     = $Env:FC_TIME_LIMIT
    'gr_ScoreLimit'    = $Env:FC_SCORE_LIMIT
    'gr_RespawnTime'   = $Env:FC_RESPAWN_TIME
    'sv_password'      = $Env:FC_PASSWORD
    'sv_rcon_password' = $Env:FC_RCON_PASSWORD
}

$flags = [ordered]@{
    'gr_FriendlyFire' = $Env:FC_FRIENDLY_FIRE
    'sv_punkbuster'   = $Env:FC_PUNKBUSTER
}

foreach ($s in $values.GetEnumerator()) {
    if ($s.Value) { Set-Cvar $s.Key $s.Value }
}

foreach ($s in $flags.GetEnumerator()) {
    if ($s.Value) { Set-Cvar $s.Key (ConvertTo-Flag $s.Value) }
}

# The game types are upper case in the levels' mission lists
foreach ($key in @($settings.Keys)) {
    if ($key -ieq 'g_GameType') { $settings[$key] = $settings[$key].ToUpperInvariant() }
}

# Replace the whole rotation. Each entry is `<map> <FFA|TDM|ASSAULT>`, optionally followed by the
# mapcycle.txt per-map overrides (time limit, respawn time, invulnerability, max players, min and
# max team size).
if ($Env:FC_MAPCYCLE) {
    $cycleName = "$($profileName)_mapcycle.txt"
    $entries   = @($Env:FC_MAPCYCLE -split ',' | ForEach-Object { ($_.Trim() -split '\s+') -join ' ' } | Where-Object { $_ })

    $cycleFile = Join-Path $serverDir $cycleName
    [System.IO.File]::WriteAllText($cycleFile, ($entries -join "`r`n") + "`r`n")
    chown "$($Env:UID):$($Env:GID)" $cycleFile

    Set-Cvar 'sv_mapcyclefile' "profiles/server/$cycleName"
    Write-Log "Wrote $($entries.Count) maps to $cycleName"
}

$haveMap = @($settings.Keys) | Where-Object { $_ -ieq 'gr_NextMap' }
if (-not $haveMap) {
    Write-Log -Level Error "No gr_NextMap in $($profileName)_server.cfg and FC_MAP is empty; the server will start without a map"
}

$width = ($settings.Keys | Measure-Object -Property Length -Maximum).Maximum
$lines = foreach ($s in $settings.GetEnumerator()) { $s.Key.PadRight($width + 1) + '= ' + $s.Value }

[System.IO.File]::WriteAllText($file, ($lines -join "`r`n") + "`r`n")
chown "$($Env:UID):$($Env:GID)" $file

Write-Log "Applied FC_* settings to Profiles/server/$($profileName)_server.cfg"
