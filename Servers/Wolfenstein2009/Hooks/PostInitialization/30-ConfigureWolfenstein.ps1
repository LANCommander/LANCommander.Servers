#Requires -Modules Logging

# Write the WOLF_* settings into base/lancommander.cfg, which the launcher execs after the server's
# own configs. It's written through the merged view, so it lands in Overlay/base/. Set
# WOLF_MANAGE_CONFIG=false to leave it alone and write it yourself.
#
# The server saves most si_* cvars to wolfdedconfig.cfg in the Wine prefix, so every setting is
# written on every start, not just the ones that differ from the defaults. The map rotation is the
# one the game's serverlauncher.exe writes: each m<i> sets g_nextMap to the next entry and spawns
# its map, and `vstr m0` starts it.

$root = $Env:SERVER_ROOT
$cfg  = Join-Path $root 'base/lancommander.cfg'

if (-not (Test-Path -Path (Join-Path $root 'Wolf2MPLite.exe'))) {
    Write-Log -Level Error "Wolf2MPLite.exe not found in $root; skipping server configuration"
    return
}

if ($Env:WOLF_MANAGE_CONFIG -match '^(0|false|no|off)$') {
    Write-Log "WOLF_MANAGE_CONFIG is off; leaving base/lancommander.cfg as it is"
    if (-not (Test-Path -Path $cfg)) {
        Write-Log -Level Warning "base/lancommander.cfg doesn't exist; the server will start without a map"
    }
    return
}

function ConvertTo-Flag([string] $Value, [string] $Default = 'false') {
    if (-not $Value) { $Value = $Default }
    if ($Value -match '^(1|true|yes|on)$') { '1' } else { '0' }
}

function ConvertTo-Int([string] $Value, [int] $Default, [string] $Name) {
    if (-not $Value) { return $Default }
    $n = 0
    if (-not [int]::TryParse($Value, [ref] $n)) { throw "$Name must be a number, not '$Value'" }
    $n
}

# Quoted cvar value. The command parser has no escape for quotes, and ; would end the command.
function ConvertTo-Quoted([string] $Value) {
    '"' + ($Value -replace '["\r\n;]', '') + '"'
}

$rulesAliases = @{
    'objective' = 'sdGameRulesObjective'; 'obj' = 'sdGameRulesObjective'; 'sdgamerulesobjective' = 'sdGameRulesObjective'
    'stopwatch' = 'sdGameRulesStopWatch'; 'sw' = 'sdGameRulesStopWatch'; 'sdgamerulesstopwatch' = 'sdGameRulesStopWatch'
    'tdm' = 'sdGameRulesTDM'; 'teamdeathmatch' = 'sdGameRulesTDM'; 'sdgamerulestdm' = 'sdGameRulesTDM'
}

function Resolve-Rules([string] $Value) {
    $key = $Value.Trim().ToLowerInvariant() -replace '[^a-z]', ''
    if (-not $rulesAliases.ContainsKey($key)) {
        throw "Unknown rules '$Value' (use objective, stopwatch or tdm)"
    }
    $rulesAliases[$key]
}

$allMaps = 'mp_bank', 'mp_canals', 'mp_chemical', 'mp_facility', 'mp_hospital', 'mp_manor', 'mp_rooftops', 'mp_tesla'

$defaultRules = Resolve-Rules $(if ($Env:WOLF_RULES) { $Env:WOLF_RULES } else { 'objective' })

$entries = if ($Env:WOLF_MAPS) { $Env:WOLF_MAPS -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } } else { $allMaps }
$rotation = foreach ($entry in $entries) {
    $map, $rules = $entry -split ':', 2
    $map = $map.Trim().ToLowerInvariant()
    if ($map -notmatch '^mp_') { $map = "mp_$map" }   # bank -> mp_bank
    if ($map -notmatch '^[a-z0-9_]+$') { throw "Invalid map name '$entry' in WOLF_MAPS" }
    if ($allMaps -notcontains $map) { Write-Log -Level Warning "$map isn't a stock map; passing it through" }
    [pscustomobject]@{ Map = $map; Rules = $(if ($rules) { Resolve-Rules $rules } else { $defaultRules }) }
}
$rotation = @($rotation)

$name       = if ($Env:WOLF_SERVER_NAME) { $Env:WOLF_SERVER_NAME } else { 'LANCommander Wolfenstein' }
$maxPlayers = ConvertTo-Int $Env:WOLF_MAX_PLAYERS 12 'WOLF_MAX_PLAYERS'
$perTeam    = ConvertTo-Int $Env:WOLF_MAX_PLAYERS_PER_TEAM ([math]::Ceiling($maxPlayers / 2)) 'WOLF_MAX_PLAYERS_PER_TEAM'
$minPlayers = ConvertTo-Int $Env:WOLF_MIN_PLAYERS 0 'WOLF_MIN_PLAYERS'
$timeLimit  = ConvertTo-Int $Env:WOLF_TIME_LIMIT 20 'WOLF_TIME_LIMIT'

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('// Written by LANCommander from the WOLF_* environment variables on every start.')
$lines.Add('// Set WOLF_MANAGE_CONFIG=false to edit this file yourself.')
$lines.Add('')
$lines.Add("set si_name $(ConvertTo-Quoted $name)")
$lines.Add("set si_maxPlayers `"$maxPlayers`"")
$lines.Add("set si_maxPlayersPerTeam `"$perTeam`"")
$lines.Add("set si_minPlayers `"$minPlayers`"")
$lines.Add("set si_timeLimit `"$timeLimit`"")
$lines.Add("set si_teamDamage `"$(ConvertTo-Flag $Env:WOLF_TEAM_DAMAGE)`"")
$lines.Add("set g_password $(ConvertTo-Quoted $Env:WOLF_PASSWORD)")
$lines.Add("set si_needPass `"$(if ($Env:WOLF_PASSWORD) { 1 } else { 0 })`"")
$lines.Add("set net_serverRemoteConsolePassword $(ConvertTo-Quoted $Env:WOLF_RCON_PASSWORD)")

$motd = @($Env:WOLF_MOTD -split '\|' | ForEach-Object { $_.Trim() })
for ($i = 1; $i -le 4; $i++) {
    $line = if ($motd.Count -ge $i) { $motd[$i - 1] } else { '' }
    $lines.Add("set si_motd_$i $(ConvertTo-Quoted $line)")
}

if ($Env:WOLF_EXTRA_CONFIG) {
    $lines.Add('')
    $lines.Add('// WOLF_EXTRA_CONFIG')
    foreach ($extra in ($Env:WOLF_EXTRA_CONFIG -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
        $lines.Add($extra)
    }
}

$lines.Add('')
$lines.Add('// Map rotation')
for ($i = 0; $i -lt $rotation.Count; $i++) {
    $next = ($i + 1) % $rotation.Count
    $lines.Add("set m$i `"set g_nextMap `$m$next;set si_rules $($rotation[$i].Rules);spawnServer $($rotation[$i].Map)`"")
}
$lines.Add('vstr m0')

New-Item -ItemType Directory -Path (Split-Path $cfg) -Force | Out-Null
[System.IO.File]::WriteAllText($cfg, (($lines -join "`r`n") + "`r`n"))
chown "$($Env:UID):$($Env:GID)" $cfg

$summary = ($rotation | ForEach-Object { "$($_.Map) ($($_.Rules -replace '^sdGameRules', ''))" }) -join ', '
Write-Log "Applied WOLF_* settings to base/lancommander.cfg: '$name', rotation $summary"
