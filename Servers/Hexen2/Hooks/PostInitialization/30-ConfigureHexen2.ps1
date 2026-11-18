#Requires -Modules Logging

# Write the HEXEN2_* settings into <HEXEN2_GAME or data1>/lancommander.cfg, which hexen2-server
# execs before +map. The file is regenerated on every start. h2ded execs server.cfg on its own
# before the command line runs, so put your own settings in server.cfg (in Overlay/); the
# HEXEN2_* settings that are set override it.

$game = if ($Env:HEXEN2_GAME) { $Env:HEXEN2_GAME } else { 'data1' }
$dir = Join-Path $Env:SERVER_ROOT $game
$file = Join-Path $dir 'lancommander.cfg'

if (-not (Test-Path -Path (Join-Path $Env:SERVER_ROOT 'data1/pak0.pak'))) {
    Write-Log -Level Error "data1/pak0.pak not found in $Env:SERVER_ROOT; copy the Hexen II data1/ folder (pak0.pak, pak1.pak) into $Env:SERVER_DIR"
    return
}

function ConvertTo-Quoted([string] $Value) { '"' + $Value.Replace('"', '') + '"' }

function ConvertTo-Bool([string] $Value) {
    if (-not $Value) { return $null }
    if ($Value -in 'true', '1', 'yes') { '1' } elseif ($Value -in 'false', '0', 'no') { '0' } else { $Value }
}

$deathmatch = $Env:HEXEN2_DEATHMATCH
$coop = ConvertTo-Bool $Env:HEXEN2_COOP

# h2ded forces deathmatch 1 at startup, and deathmatch wins over coop, so co-op needs deathmatch 0
if ($coop -eq '1' -and $deathmatch -ne '0') {
    if ($deathmatch) {
        Write-Log -Level Warning "HEXEN2_COOP is on, so deathmatch is set to 0 instead of HEXEN2_DEATHMATCH=$deathmatch"
    }
    $deathmatch = '0'
}

$values = [ordered]@{
    'hostname'    = $(if ($Env:HEXEN2_SERVER_NAME) { ConvertTo-Quoted $Env:HEXEN2_SERVER_NAME })
    'deathmatch'  = $deathmatch
    'coop'        = $coop
    'teamplay'    = $Env:HEXEN2_TEAMPLAY
    'fraglimit'   = $Env:HEXEN2_FRAG_LIMIT
    'timelimit'   = $Env:HEXEN2_TIME_LIMIT
    'skill'       = $Env:HEXEN2_SKILL
    'randomclass' = ConvertTo-Bool $Env:HEXEN2_RANDOM_CLASS
    'samelevel'   = ConvertTo-Bool $Env:HEXEN2_SAME_LEVEL
    'noexit'      = ConvertTo-Bool $Env:HEXEN2_NO_EXIT
}

$lines = @('// Generated from the HEXEN2_* environment variables on every start, edit server.cfg instead')

foreach ($key in $values.Keys) {
    if ($null -ne $values[$key] -and $values[$key] -ne '') { $lines += "$key $($values[$key])" }
}

New-Item -ItemType Directory -Path $dir -Force | Out-Null
[System.IO.File]::WriteAllText($file, ($lines -join "`n") + "`n")
# Not -R: a recursive chown through Merged/ would copy every pak up into Overlay/
chown "$($Env:UID):$($Env:GID)" $file

Write-Log "Wrote HEXEN2_* settings to $file"
