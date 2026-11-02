#Requires -Modules Logging

# Write the DAIKATANA_* settings into data/lancommander.cfg, which daikatana-server execs before
# +map. The file is regenerated on every start; put your own cvars in data/server.cfg (in
# Overlay/), which lancommander.cfg execs first (last when DAIKATANA_MAP is empty, so its own map
# command starts the server).

$data = Join-Path $Env:SERVER_ROOT 'data'
$file = Join-Path $data 'lancommander.cfg'

if (-not (Test-Path -Path (Join-Path $Env:SERVER_ROOT 'dk_ded.exe'))) {
    Write-Log -Level Error "dk_ded.exe not found in $Env:SERVER_ROOT; skipping server configuration"
    return
}

# Maps the server can load: maps/*.bsp inside data/*.pak, plus loose data/maps/*.bsp. A missing
# map in the rotation makes the server retry it forever ("Can't find map") instead of moving on.
function Get-AvailableMaps {
    $maps = @{}

    foreach ($pak in Get-ChildItem -Path $data -Filter '*.pak' -File -ErrorAction SilentlyContinue) {
        try {
            $stream = [System.IO.File]::OpenRead($pak.FullName)
            try {
                $reader = [System.IO.BinaryReader]::new($stream)
                if ([System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(4)) -ne 'PACK') { continue }
                $offset = $reader.ReadInt32()
                $length = $reader.ReadInt32()
                $stream.Position = $offset
                $directory = [System.Text.Encoding]::Latin1.GetString($reader.ReadBytes($length))
                foreach ($m in [regex]::Matches($directory, '(?i)maps/([^\x00/]+)\.bsp')) {
                    $maps[$m.Groups[1].Value.ToLowerInvariant()] = $m.Groups[1].Value
                }
            } finally {
                $stream.Dispose()
            }
        } catch {
            Write-Log -Level Warning "Could not read $($pak.Name): $_"
        }
    }

    Get-ChildItem -Path (Join-Path $data 'maps') -Filter '*.bsp' -File -ErrorAction SilentlyContinue |
        ForEach-Object { $maps[$_.BaseName.ToLowerInvariant()] = $_.BaseName }

    return $maps
}

function ConvertTo-Quoted([string] $Value) { '"' + $Value.Replace('"', '') + '"' }

function ConvertTo-Bool([string] $Value) {
    if (-not $Value) { return $null }
    if ($Value -in 'true', 'yes') { '1' } elseif ($Value -in 'false', 'no') { '0' } else { $Value }
}

# Game mode -> the cvars that pick it, and the cvar holding that mode's map rotation
$modes = @{
    'dm'   = @{ Cvars = [ordered]@{ deathmatch = 1; coop = 0; ctf = 0; deathtag = 0; dm_teamplay = 0 }; Rotation = 'maps_dm' }
    'tdm'  = @{ Cvars = [ordered]@{ deathmatch = 1; coop = 0; ctf = 0; deathtag = 0; dm_teamplay = 1 }; Rotation = 'maps_dm' }
    'ctf'  = @{ Cvars = [ordered]@{ deathmatch = 1; coop = 0; ctf = 1; deathtag = 0; dm_teamplay = 0 }; Rotation = 'maps_ctf' }
    'dt'   = @{ Cvars = [ordered]@{ deathmatch = 1; coop = 0; ctf = 0; deathtag = 1; dm_teamplay = 0 }; Rotation = 'maps_deathtag' }
    'coop' = @{ Cvars = [ordered]@{ deathmatch = 0; coop = 1; ctf = 0; deathtag = 0; dm_teamplay = 0 }; Rotation = $null }
}
$aliases = @{ 'deathmatch' = 'dm'; 'teamdeathmatch' = 'tdm'; 'team' = 'tdm'; 'deathtag' = 'dt'; 'cooperative' = 'coop' }

$modeName = if ($Env:DAIKATANA_MODE) { $Env:DAIKATANA_MODE.ToLowerInvariant() } else { '' }
if ($aliases.ContainsKey($modeName)) { $modeName = $aliases[$modeName] }
$mode = $null
if ($modeName) {
    if ($modes.ContainsKey($modeName)) {
        $mode = $modes[$modeName]
    } else {
        Write-Log -Level Warning "Unknown DAIKATANA_MODE '$($Env:DAIKATANA_MODE)' (use dm, tdm, ctf, dt or coop); the mode is left to server.cfg"
    }
}

$available = Get-AvailableMaps
if ($available.Count -eq 0) { Write-Log -Level Warning "Found no maps in $data/*.pak; map names aren't checked" }

if ($Env:DAIKATANA_MAP -and $available.Count -and -not $available.ContainsKey($Env:DAIKATANA_MAP.ToLowerInvariant())) {
    Write-Log -Level Error "DAIKATANA_MAP '$($Env:DAIKATANA_MAP)' is not in data/*.pak or data/maps/; the server won't start a map"
}

$lines = @('// Generated from the DAIKATANA_* environment variables on every start, edit server.cfg instead')

$serverCfg = Join-Path $data 'server.cfg'
$hasServerCfg = Test-Path -Path $serverCfg
if ($hasServerCfg -and $Env:DAIKATANA_MAP) { $lines += 'exec server.cfg' }

if ($mode) {
    foreach ($key in $mode.Cvars.Keys) { $lines += "set $key $($mode.Cvars[$key])" }
}

$values = [ordered]@{
    'hostname'      = $(if ($Env:DAIKATANA_SERVER_NAME) { ConvertTo-Quoted $Env:DAIKATANA_SERVER_NAME })
    'maxclients'    = $Env:DAIKATANA_MAX_PLAYERS
    'fraglimit'     = $Env:DAIKATANA_FRAG_LIMIT
    'timelimit'     = $Env:DAIKATANA_TIME_LIMIT
    'skill'         = $Env:DAIKATANA_SKILL
    'password'      = $(if ($Env:DAIKATANA_PASSWORD) { ConvertTo-Quoted $Env:DAIKATANA_PASSWORD })
    'rcon_password' = $(if ($Env:DAIKATANA_RCON_PASSWORD) { ConvertTo-Quoted $Env:DAIKATANA_RCON_PASSWORD })
    'public'        = ConvertTo-Bool $Env:DAIKATANA_PUBLIC
}

foreach ($key in $values.Keys) {
    if ($null -ne $values[$key] -and $values[$key] -ne '') { $lines += "set $key $($values[$key])" }
}

# Map rotation: a space-separated list in maps_dm, maps_ctf or maps_deathtag, depending on the mode
if ($Env:DAIKATANA_MAPS) {
    if (-not $mode) {
        Write-Log -Level Warning "DAIKATANA_MAPS needs DAIKATANA_MODE to pick the rotation cvar; ignored"
    } elseif (-not $mode.Rotation) {
        Write-Log -Level Warning "Co-op has no map rotation (levels follow the campaign); DAIKATANA_MAPS ignored"
    } else {
        $maps = @()
        foreach ($m in ($Env:DAIKATANA_MAPS -split '[,;\s]+' | Where-Object { $_ })) {
            $m = $m -replace '\.bsp$', ''
            if ($available.Count -and -not $available.ContainsKey($m.ToLowerInvariant())) {
                Write-Log -Level Warning "Map $m is not in data/*.pak or data/maps/; left out of the rotation"
                continue
            }
            $maps += $m
        }

        $lines += "set $($mode.Rotation) $(ConvertTo-Quoted ($maps -join ' '))"
        Write-Log "Map rotation ($($mode.Rotation)): $($maps -join ', ')"
    }
}

if ($hasServerCfg -and -not $Env:DAIKATANA_MAP) { $lines += 'exec server.cfg' }

New-Item -ItemType Directory -Path $data -Force | Out-Null
[System.IO.File]::WriteAllText($file, ($lines -join "`r`n") + "`r`n")
chown "$($Env:UID):$($Env:GID)" $file

Write-Log "Wrote DAIKATANA_* settings to $file"
