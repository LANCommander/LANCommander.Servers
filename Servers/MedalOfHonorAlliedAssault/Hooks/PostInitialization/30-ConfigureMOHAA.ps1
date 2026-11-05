#Requires -Modules Logging

# Write the MOHAA_* settings into <game dir>/lancommander.cfg, which mohaa-server execs at
# startup. The file is regenerated on every start; put your own settings in server.cfg next to
# it (in Overlay/), which lancommander.cfg execs first when it exists. It ends with the `map`
# command that starts the first map of the rotation.

$game = switch ("$Env:MOHAA_GAME".ToLowerInvariant()) {
    { $_ -in '', 'aa', '0', 'base', 'alliedassault' } { 'aa'; break }
    { $_ -in 'sh', '1', 'spearhead' }                 { 'sh'; break }
    { $_ -in 'bt', '2', 'breakthrough' }              { 'bt'; break }
    default { throw "Unknown MOHAA_GAME '$($Env:MOHAA_GAME)' (use aa, sh or bt)" }
}

$gameDir = @{ aa = 'main'; sh = 'mainta'; bt = 'maintt' }[$game]

$gameType = switch ("$Env:MOHAA_GAME_TYPE".ToLowerInvariant()) {
    { $_ -in '1', 'ffa', 'dm', 'freeforall' }     { 1; break }
    { $_ -in '', '2', 'tdm', 'team' }             { 2; break }
    { $_ -in '3', 'round', 'rb' }                 { 3; break }
    { $_ -in '4', 'obj', 'objective' }            { 4; break }
    { $_ -in '5', 'tow', 'tugofwar' }             { 5; break }
    { $_ -in '6', 'lib', 'liberation' }           { 6; break }
    default { throw "Unknown MOHAA_GAME_TYPE '$($Env:MOHAA_GAME_TYPE)' (use ffa, tdm, round, obj, tow or lib)" }
}

if ($gameType -eq 5 -and $game -eq 'aa') { Write-Log -Level Warning "Tug of War (MOHAA_GAME_TYPE=tow) needs Spearhead or Breakthrough (MOHAA_GAME=sh or bt)" }
if ($gameType -eq 6 -and $game -ne 'bt') { Write-Log -Level Warning "Liberation (MOHAA_GAME_TYPE=lib) needs Breakthrough (MOHAA_GAME=bt)" }

# Stock rotations for when MOHAA_MAPS is empty
$aaDm   = 'dm/mohdm1 dm/mohdm2 dm/mohdm3 dm/mohdm4 dm/mohdm5 dm/mohdm6 dm/mohdm7'
$aaObj  = 'obj/obj_team1 obj/obj_team2 obj/obj_team3 obj/obj_team4'
$shDm   = 'dm/mp_bahnhof_dm dm/mp_bazaar_dm dm/mp_brest_dm dm/mp_gewitter_dm dm/mp_holland_dm dm/mp_malta_dm dm/mp_stadt_dm dm/mp_unterseite_dm dm/mp_verschneit_dm'
$shTow  = 'obj/mp_ardennes_tow obj/mp_berlin_tow obj/mp_druckkammern_tow obj/mp_flughafen_tow'
$btObj  = 'obj/mp_bizertefort_obj obj/mp_bologna_obj obj/mp_castello_obj obj/mp_palermo_obj'
$btTow  = "obj/mp_kasserine_tow obj/mp_montebattaglia_tow obj/mp_montecassino_tow $shTow"
$btLib  = 'lib/mp_anzio_lib lib/mp_bizerteharbor_lib lib/mp_ship_lib lib/mp_tunisia_lib'

$defaultMaps = switch ($gameType) {
    { $_ -in 1, 2, 3 } { if ($game -eq 'aa') { $aaDm } else { $shDm }; break }
    4 { if ($game -eq 'bt') { $btObj } else { $aaObj }; break }
    5 { if ($game -eq 'bt') { $btTow } else { $shTow }; break }
    6 { $btLib }
}

$mapList = if ($Env:MOHAA_MAPS) { $Env:MOHAA_MAPS } else { $defaultMaps }
$maps = @($mapList -split '[,\s]+' | Where-Object { $_ })

if (-not (Test-Path -Path (Join-Path $Env:SERVER_ROOT $gameDir))) {
    Write-Log -Level Error "$gameDir/ not found in $Env:SERVER_ROOT; copy the retail game folders (main/, plus mainta/ for Spearhead and maintt/ for Breakthrough) into $Env:SERVER_DIR"
    return
}

$dir  = Join-Path $Env:SERVER_ROOT $gameDir
$file = Join-Path $dir 'lancommander.cfg'

function ConvertTo-Quoted([string] $Value) { '"' + $Value.Replace('"', '') + '"' }

function ConvertTo-Bool([string] $Value) {
    if (-not $Value) { return $null }
    if ($Value -in 'true', '1', 'yes') { '1' } else { '0' }
}

$values = [ordered]@{
    'sv_hostname'    = $(if ($Env:MOHAA_SERVER_NAME) { ConvertTo-Quoted $Env:MOHAA_SERVER_NAME })
    'sv_maxclients'  = $Env:MOHAA_MAX_PLAYERS
    'g_password'     = $(if ($Env:MOHAA_PASSWORD) { ConvertTo-Quoted $Env:MOHAA_PASSWORD })
    'rconpassword'   = $(if ($Env:MOHAA_RCON_PASSWORD) { ConvertTo-Quoted $Env:MOHAA_RCON_PASSWORD })
    'g_gametype'     = "$gameType"
    'timelimit'      = $Env:MOHAA_TIME_LIMIT
    'fraglimit'      = $Env:MOHAA_FRAG_LIMIT
    'roundlimit'     = $Env:MOHAA_ROUND_LIMIT
    'g_teamdamage'   = ConvertTo-Bool $Env:MOHAA_TEAM_DAMAGE
    'g_allowvote'    = ConvertTo-Bool $Env:MOHAA_ALLOW_VOTE
    'sv_maplist'     = $(if ($maps.Count -gt 0) { ConvertTo-Quoted ($maps -join ' ') })
}

$lines = @('// Generated from the MOHAA_* environment variables on every start, edit server.cfg instead')
$lines += 'exec server.cfg'

foreach ($key in $values.Keys) {
    if ($null -ne $values[$key] -and $values[$key] -ne '') { $lines += "set $key $($values[$key])" }
}

if ($maps.Count -gt 0) {
    $lines += "map $(ConvertTo-Quoted $maps[0])"
} else {
    Write-Log -Level Warning "No map to start: MOHAA_MAPS is empty and there is no stock rotation for this game type"
}

[System.IO.File]::WriteAllText($file, ($lines -join "`n") + "`n")
# Not -R: a recursive chown through Merged/ would copy every .pk3 up into Overlay/
chown "$($Env:UID):$($Env:GID)" $dir $file

Write-Log "Wrote MOHAA_* settings to $file (game $game, g_gametype $gameType, first map $($maps[0]))"
