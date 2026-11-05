#Requires -Modules Logging

# goserver.exe has no command-line settings. Its Server Settings dialog is filled from
# Globalops\server.cfg, and when OK is pressed it writes the dialog back there and starts hosting.
# This hook writes the GO_* settings into server.cfg on every start, and the launcher (go-server)
# presses OK. A GO_* variable left empty keeps the value server.cfg already has.
#
# server.cfg is one `"key" "value"` pair per line. The file is written through the merged view, so
# it lands in Overlay/ and Server/ keeps the original.

$runAs = "$($Env:UID):$($Env:GID)"
$cfg   = Join-Path $Env:SERVER_ROOT 'Globalops/server.cfg'

if (-not (Test-Path -Path (Join-Path $Env:SERVER_ROOT 'goserver.exe'))) {
    Write-Log -Level Error "goserver.exe not found in $Env:SERVER_ROOT; skipping server configuration"
    return
}

function Test-Set([string] $Value) { return -not [string]::IsNullOrWhiteSpace($Value) }

function ConvertTo-Flag([string] $Name, [string] $Value) {
    if ($Value -match '^(1|true|yes|on)$') { return '1' }
    if ($Value -match '^(0|false|no|off)$') { return '0' }
    throw "$Name must be true or false, not '$Value'"
}

function ConvertTo-Number([string] $Name, [string] $Value, [int] $Min, [int] $Max) {
    $number = 0
    if (-not [int]::TryParse($Value, [ref] $number) -or $number -lt $Min -or $number -gt $Max) {
        throw "$Name must be a number from $Min to $Max, not '$Value'"
    }
    return $number
}

# The dialog's sliders store a percentage as a fraction, e.g. 50 -> "0.500000"
function ConvertTo-Fraction([string] $Name, [string] $Value) {
    $percent = ConvertTo-Number $Name $Value 0 100
    return ($percent / 100).ToString('0.000000', [System.Globalization.CultureInfo]::InvariantCulture)
}

# --- Read server.cfg ---
$settings = [ordered]@{}
if (Test-Path -Path $cfg) {
    foreach ($line in [System.IO.File]::ReadAllLines($cfg, [System.Text.Encoding]::Latin1)) {
        if ($line -match '^\s*"([^"]+)"\s+"(.*)"\s*$') {
            $settings[$Matches[1]] = $Matches[2]
        }
    }
} else {
    Write-Log -Level Warning "$cfg not found; writing a new one"
}

# --- Text settings ---
# The server writes a single space for an empty field
$text = [ordered]@{
    'servername'          = 'GO_SERVER_NAME'
    'serverpassword'      = 'GO_PASSWORD'
    'adminname'           = 'GO_ADMIN_NAME'
    'adminemail'          = 'GO_ADMIN_EMAIL'
    'serverwebsite'       = 'GO_WEBSITE'
    'remoteadminpassword' = 'GO_REMOTE_ADMIN_PASSWORD'
}
foreach ($t in $text.GetEnumerator()) {
    $value = [Environment]::GetEnvironmentVariable($t.Value)
    if ($null -ne $value -and $value -ne '') {
        if ($value.Contains('"')) { throw "$($t.Value) can't contain a double quote" }
        $settings[$t.Key] = $value
    } elseif (-not $settings.Contains($t.Key)) {
        $settings[$t.Key] = ' '
    }
}

# --- Numbers, flags and percentages ---
$numbers = @(
    # key,                 variable,                     min, max
    @('maxplayers',        'GO_MAX_PLAYERS',             1,   24),
    @('timelimit',         'GO_TIME_LIMIT',              0,   999),
    @('numrounds',         'GO_ROUNDS',                  0,   999),
    @('flipround',         'GO_TEAM_FLIP_ROUNDS',        1,   999),
    @('mirrorcash',        'GO_MIRROR_CASH',             0,   99999),
    @('numtkstokick',      'GO_TEAM_KILLS_TO_KICK',      0,   999),
    @('numcivstokick',     'GO_CIVILIAN_KILLS_TO_KICK',  0,   999),
    @('kickafktime',       'GO_AFK_KICK',                0,   999)
)
foreach ($n in $numbers) {
    $value = [Environment]::GetEnvironmentVariable($n[1])
    if (Test-Set $value) { $settings[$n[0]] = [string](ConvertTo-Number $n[1] $value $n[2] $n[3]) }
}

$flags = [ordered]@{
    'teamflip'          = 'GO_TEAM_FLIP'
    'lan'               = 'GO_LAN'
    'mirrordamage'      = 'GO_MIRROR_DAMAGE'
    'tkpunish'          = 'GO_TEAM_KILL_PUNISH'
    'autoteambalance'   = 'GO_AUTO_TEAM_BALANCE'
    'forceteambalance'  = 'GO_FORCE_TEAM_BALANCE'
    'allowuploads'      = 'GO_ALLOW_BADGES'
    'logevents'         = 'GO_LOG_EVENTS'
    'voip'              = 'GO_VOICE'
    'voting'            = 'GO_VOTING'
    'TimeSyncCheck'     = 'GO_TIME_SYNC'
}
foreach ($f in $flags.GetEnumerator()) {
    $value = [Environment]::GetEnvironmentVariable($f.Value)
    if (Test-Set $value) { $settings[$f.Key] = ConvertTo-Flag $f.Value $value }
}

$fractions = [ordered]@{
    'ffteam'              = 'GO_FRIENDLY_FIRE'
    'ffallies'            = 'GO_FRIENDLY_FIRE_ALLIES'
    'mirrordamagepercent' = 'GO_MIRROR_DAMAGE_PERCENT'
    'playerkickvote'      = 'GO_VOTE_KICK_RATIO'
    'mapvote'             = 'GO_VOTE_MAP_RATIO'
}
foreach ($f in $fractions.GetEnumerator()) {
    $value = [Environment]::GetEnvironmentVariable($f.Value)
    if (Test-Set $value) { $settings[$f.Key] = ConvertTo-Fraction $f.Value $value }
}

# --- Bandwidth ---
# The dialog's Bandwidth list, in order. CUSTOM uses custombandwidth (bytes/s).
$bandwidths = [ordered]@{ '56k' = 0; 'isdn' = 1; 'dsl' = 2; 't1' = 3; 't3' = 4; 'custom' = 5 }
if (Test-Set $Env:GO_BANDWIDTH) {
    $key = "$Env:GO_BANDWIDTH".ToLowerInvariant().Trim()
    if (-not $bandwidths.Contains($key)) {
        throw "GO_BANDWIDTH must be one of $($bandwidths.Keys -join ', '), not '$Env:GO_BANDWIDTH'"
    }
    $settings['serverbandwidth'] = [string]$bandwidths[$key]
}
if (Test-Set $Env:GO_CUSTOM_BANDWIDTH) {
    $bps = ConvertTo-Number 'GO_CUSTOM_BANDWIDTH' $Env:GO_CUSTOM_BANDWIDTH 1000 100000000
    $settings['custombandwidth'] = ([double]$bps).ToString('0.000000', [System.Globalization.CultureInfo]::InvariantCulture)
}

# goserver.exe only hosts dedicated, so leave its client-server flags off
$settings['dedicated'] = '0.000000'

# --- Map rotation ---
# Maps are Globalops/worlds/<name>.dat. A name the server can't load stops the rotation, so unknown
# names are dropped. server.cfg holds them as map0..mapN-1 with nummaps.
if ($Env:GO_MAPS -ieq 'config' -or -not (Test-Set $Env:GO_MAPS)) {
    Write-Log "GO_MAPS=config: keeping the map rotation in server.cfg"
} else {
    $known = @{}
    $worlds = Join-Path $Env:SERVER_ROOT 'Globalops/worlds'
    if (Test-Path -Path $worlds) {
        Get-ChildItem -Path $worlds -File | Where-Object { $_.Extension -ieq '.dat' } | ForEach-Object {
            $known[$_.BaseName.ToLowerInvariant()] = $_.BaseName.ToLowerInvariant()
        }
    }

    $rotation = foreach ($map in ($Env:GO_MAPS -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
        $name = ($map -replace '(?i)\.dat$', '' -replace '^(?i)worlds[\\/]', '').ToLowerInvariant()
        if ($known.ContainsKey($name)) {
            $known[$name]
        } else {
            Write-Log -Level Warning "Map '$map' is not in Globalops/worlds; leaving it out of the rotation"
        }
    }

    if (-not $rotation) {
        throw "No valid maps in GO_MAPS ('$Env:GO_MAPS')"
    }

    foreach ($key in @($settings.Keys)) {
        if ($key -match '^map\d+$') { $settings.Remove($key) }
    }
    $i = 0
    foreach ($map in $rotation) {
        $settings["map$i"] = "worlds/$map"
        $i++
    }
    $settings['nummaps'] = [string]$i

    Write-Log "Map rotation: $($rotation -join ', ')"
}

# --- Write server.cfg ---
$lines = foreach ($s in $settings.GetEnumerator()) { '"{0}" "{1}"' -f $s.Key, $s.Value }
$dir = Split-Path -Parent $cfg
New-Item -ItemType Directory -Path $dir -Force | Out-Null
[System.IO.File]::WriteAllText($cfg, (($lines | ForEach-Object { "$_`r`n" }) -join ''), [System.Text.Encoding]::Latin1)
chown $runAs $cfg

$bandwidthName = ($bandwidths.GetEnumerator() | Where-Object { [string]$_.Value -eq $settings['serverbandwidth'] } | Select-Object -First 1).Key
Write-Log ("Server settings: '{0}', {1} players, {2} min x {3} rounds, LAN {4}, bandwidth {5}, password {6}" -f
    $settings['servername'], $settings['maxplayers'], $settings['timelimit'], $settings['numrounds'],
    $(if ($settings['lan'] -eq '1') { 'on' } else { 'off' }), $bandwidthName,
    $(if ("$($settings['serverpassword'])".Trim()) { 'set' } else { 'none' }))
