#Requires -Modules Logging

# Write the COD2_* settings into <COD2_FS_GAME or main>/lancommander.cfg, which cod2-server
# execs before map_rotate. The file is regenerated on every start; put your own settings in
# server.cfg next to it (in Overlay/), which lancommander.cfg execs first when it exists.

if (-not (Test-Path -Path (Join-Path $Env:SERVER_ROOT 'main/iw_00.iwd'))) {
    Write-Log -Level Error "main/iw_00.iwd not found in $Env:SERVER_ROOT; copy the retail Call of Duty 2 (1.3) main/ folder into $Env:SERVER_DIR"
    return
}

$game = if ($Env:COD2_FS_GAME) { $Env:COD2_FS_GAME } else { 'main' }
$dir  = Join-Path $Env:SERVER_ROOT $game
$file = Join-Path $dir 'lancommander.cfg'

function ConvertTo-Quoted([string] $Value) { '"' + $Value.Replace('"', '') + '"' }

function ConvertTo-Bool([string] $Value) {
    if (-not $Value) { return $null }
    if ($Value -in 'true', '1', 'yes') { '1' } else { '0' }
}

$gameType = $Env:COD2_GAME_TYPE.ToLowerInvariant()

# sv_mapRotation: "gametype <type> map <a> map <b> ..."; map_rotate starts the first entry
$rotation = $null
if ($Env:COD2_MAPS) {
    $maps = @($Env:COD2_MAPS -split '[,\s]+' | Where-Object { $_ })
    $rotation = @()
    if ($gameType) { $rotation += "gametype $gameType" }
    $rotation += $maps | ForEach-Object { "map $_" }
    $rotation = ConvertTo-Quoted ($rotation -join ' ')
}

$values = [ordered]@{
    'sv_hostname'       = $(if ($Env:COD2_SERVER_NAME) { ConvertTo-Quoted $Env:COD2_SERVER_NAME })
    'scr_motd'          = $(if ($Env:COD2_MOTD) { ConvertTo-Quoted $Env:COD2_MOTD })
    'sv_maxclients'     = $Env:COD2_MAX_PLAYERS
    'g_password'        = $(if ($Env:COD2_PASSWORD) { ConvertTo-Quoted $Env:COD2_PASSWORD })
    'rcon_password'     = $(if ($Env:COD2_RCON_PASSWORD) { ConvertTo-Quoted $Env:COD2_RCON_PASSWORD })
    'g_gametype'        = $gameType
    'sv_mapRotation'    = $rotation
    'scr_friendlyfire'  = $Env:COD2_FRIENDLY_FIRE
    'scr_killcam'       = ConvertTo-Bool $Env:COD2_KILLCAM
    'g_allowvote'       = ConvertTo-Bool $Env:COD2_ALLOW_VOTE
    'sv_allowDownload'  = ConvertTo-Bool $Env:COD2_ALLOW_DOWNLOAD
    'sv_wwwDownload'    = $(if ($Env:COD2_WWW_BASE_URL) { '1' })
    'sv_wwwBaseURL'     = $(if ($Env:COD2_WWW_BASE_URL) { ConvertTo-Quoted $Env:COD2_WWW_BASE_URL.TrimEnd('/') })
}

# Time and score limits are per game type (scr_tdm_timelimit, scr_ctf_scorelimit, ...)
if ($gameType) {
    $values["scr_$($gameType)_timelimit"]  = $Env:COD2_TIME_LIMIT
    $values["scr_$($gameType)_scorelimit"] = $Env:COD2_SCORE_LIMIT
}

$lines = @('// Generated from the COD2_* environment variables on every start, edit server.cfg instead')
$lines += 'exec server.cfg'

foreach ($key in $values.Keys) {
    if ($null -ne $values[$key] -and $values[$key] -ne '') { $lines += "set $key $($values[$key])" }
}

New-Item -ItemType Directory -Path $dir -Force | Out-Null
[System.IO.File]::WriteAllText($file, ($lines -join "`n") + "`n")
# Not -R: a recursive chown through Merged/ would copy every .iwd up into Overlay/
chown "$($Env:UID):$($Env:GID)" $dir $file

Write-Log "Wrote COD2_* settings to $file"
