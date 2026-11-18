#Requires -Modules Logging

# Write the QUAKE_* settings into <QUAKE_GAME or id1>/lancommander.cfg, which quake-server execs
# before +map. The file is regenerated on every start; put your own settings in server.cfg next
# to it (in Overlay/), which lancommander.cfg execs first when it exists.

$game = if ($Env:QUAKE_GAME) { $Env:QUAKE_GAME } else { 'id1' }
$dir = Join-Path $Env:SERVER_ROOT $game
$file = Join-Path $dir 'lancommander.cfg'

if (-not (Test-Path -Path (Join-Path $Env:SERVER_ROOT 'id1/pak0.pak'))) {
    Write-Log -Level Error "id1/pak0.pak not found in $Env:SERVER_ROOT; copy the Quake id1/ folder (pak0.pak, pak1.pak) into $Env:SERVER_DIR"
    return
}

function ConvertTo-Quoted([string] $Value) { '"' + $Value.Replace('"', '') + '"' }

function ConvertTo-Bool([string] $Value) {
    if (-not $Value) { return $null }
    if ($Value -in 'true', '1', 'yes') { '1' } elseif ($Value -in 'false', '0', 'no') { '0' } else { $Value }
}

$deathmatch = $Env:QUAKE_DEATHMATCH
$coop = ConvertTo-Bool $Env:QUAKE_COOP

# deathmatch wins over coop, so co-op needs deathmatch 0
if ($coop -eq '1' -and $deathmatch -and $deathmatch -ne '0') {
    Write-Log -Level Warning "QUAKE_COOP is on, so deathmatch is set to 0 instead of QUAKE_DEATHMATCH=$deathmatch"
    $deathmatch = '0'
}

$values = [ordered]@{
    'hostname'  = $(if ($Env:QUAKE_SERVER_NAME) { ConvertTo-Quoted $Env:QUAKE_SERVER_NAME })
    'deathmatch' = $deathmatch
    'coop'      = $coop
    'teamplay'  = $Env:QUAKE_TEAMPLAY
    'fraglimit' = $Env:QUAKE_FRAG_LIMIT
    'timelimit' = $Env:QUAKE_TIME_LIMIT
    'skill'     = $Env:QUAKE_SKILL
    'samelevel' = ConvertTo-Bool $Env:QUAKE_SAME_LEVEL
    'noexit'    = ConvertTo-Bool $Env:QUAKE_NO_EXIT
}

$lines = @('// Generated from the QUAKE_* environment variables on every start, edit server.cfg instead')
$lines += 'exec server.cfg'

foreach ($key in $values.Keys) {
    if ($null -ne $values[$key] -and $values[$key] -ne '') { $lines += "$key $($values[$key])" }
}

New-Item -ItemType Directory -Path $dir -Force | Out-Null
[System.IO.File]::WriteAllText($file, ($lines -join "`n") + "`n")
# Not -R: a recursive chown through Merged/ would copy every pak up into Overlay/
chown "$($Env:UID):$($Env:GID)" $file

Write-Log "Wrote QUAKE_* settings to $file"
