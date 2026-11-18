#Requires -Modules Logging

# Write the TES3MP_* settings into the server's two config files on every start:
#   - tes3mp-server-default.cfg ([General] port/players/name/password/log level,
#     [MasterServer] enabled)
#   - <CoreScripts>/scripts/config.lua (game mode, difficulty, sharing, console, ...); the
#     CoreScripts folder is [Plugins] home in the cfg (server/, or CoreScripts/ in 0.7.0)
# Only the lines for non-empty settings are changed, so the rest of both files (and your own
# edits to them in Overlay/) are kept. Both are edited through Merged/, so the edited copies land
# in Overlay/.

$cfgFile = Join-Path $Env:SERVER_ROOT 'tes3mp-server-default.cfg'

if (-not (Test-Path -Path $cfgFile)) {
    Write-Log -Level Error "tes3mp-server-default.cfg not found in $Env:SERVER_ROOT; set TES3MP_VERSION or TES3MP_SERVER_URL, or copy TES3MP into $Env:SERVER_DIR"
    return
}

# The CoreScripts folder is [Plugins] home: ./server since 0.8.0, ./CoreScripts in 0.7.0
$coreDir = Get-Content -Path $cfgFile | Where-Object { $_ -match '^\s*home\s*=' } | Select-Object -First 1
$coreDir = if ($coreDir) { ($coreDir -replace '^\s*home\s*=\s*', '').Trim().TrimStart('.').Trim('/') }
if (-not $coreDir) { $coreDir = 'server' }
$luaFile = Join-Path $Env:SERVER_ROOT "$coreDir/scripts/config.lua"

if (-not (Test-Path -Path $luaFile)) {
    Write-Log -Level Error "$coreDir/scripts/config.lua not found in $Env:SERVER_ROOT"
    return
}

function ConvertTo-LuaBool([string] $Value) {
    if (-not $Value) { return $null }
    switch ($Value.Trim().ToLowerInvariant()) {
        { $_ -in 'true', '1', 'yes' } { return 'true' }
        { $_ -in 'false', '0', 'no' } { return 'false' }
        default { Write-Log -Level Warning "Not a boolean: '$Value'; left alone"; return $null }
    }
}

function ConvertTo-LuaInt([string] $Name, [string] $Value) {
    if (-not $Value) { return $null }
    if ($Value.Trim() -match '^-?\d+$') { return $Value.Trim() }
    Write-Log -Level Warning "$Name must be a whole number, got '$Value'; left alone"
    return $null
}

function ConvertTo-LuaString([string] $Value) {
    if (-not $Value) { return $null }
    '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"'
}

# ---- tes3mp-server-default.cfg (INI) ---------------------------------------------------------

$lan = ConvertTo-LuaBool $Env:TES3MP_LAN
$ini = [ordered]@{
    'General' = [ordered]@{
        'port'           = $Env:TES3MP_PORT
        'maximumPlayers' = $Env:TES3MP_MAX_PLAYERS
        'hostname'       = $Env:TES3MP_SERVER_NAME
        'logLevel'       = $Env:TES3MP_LOG_LEVEL
        # Always written: an empty TES3MP_PASSWORD clears a password set earlier
        'password'       = "$Env:TES3MP_PASSWORD"
    }
    'MasterServer' = [ordered]@{
        # LAN only: don't announce to master.tes3mp.com
        'enabled' = $(if ($lan -eq 'true') { 'false' } elseif ($lan -eq 'false') { 'true' })
    }
}

$lines = [System.Collections.Generic.List[string]]::new([string[]](Get-Content -Path $cfgFile))
foreach ($section in $ini.Keys) {
    $start = $lines.FindIndex({ param($l) $l.Trim() -eq "[$section]" })
    if ($start -lt 0) {
        $lines.Add('')
        $lines.Add("[$section]")
        $start = $lines.Count - 1
    }
    foreach ($key in $ini[$section].Keys) {
        $value = $ini[$section][$key]
        if ($null -eq $value -or ($value -eq '' -and $key -ne 'password')) { continue }
        # Find the key inside this section (up to the next [section] header)
        $end = $start + 1
        while ($end -lt $lines.Count -and $lines[$end].Trim() -notmatch '^\[.+\]$') { $end++ }
        $line = "$key = $value"
        $found = $false
        for ($i = $start + 1; $i -lt $end; $i++) {
            if ($lines[$i] -match "^\s*$([regex]::Escape($key))\s*=") { $lines[$i] = $line; $found = $true; break }
        }
        if (-not $found) {
            # Insert after the section's last non-empty line
            $at = $end
            while ($at -gt $start + 1 -and -not $lines[$at - 1].Trim()) { $at-- }
            $lines.Insert($at, $line)
        }
    }
}
[System.IO.File]::WriteAllText($cfgFile, ($lines -join "`n") + "`n")
chown "$($Env:UID):$($Env:GID)" $cfgFile
Write-Log "Wrote TES3MP_* server settings to $cfgFile"

# ---- <CoreScripts>/scripts/config.lua ------------------------------------------------

$lua = [ordered]@{
    'gameMode'            = ConvertTo-LuaString $Env:TES3MP_GAME_MODE
    'difficulty'          = ConvertTo-LuaInt 'TES3MP_DIFFICULTY' $Env:TES3MP_DIFFICULTY
    'maxClientsPerIP'     = ConvertTo-LuaInt 'TES3MP_MAX_CLIENTS_PER_IP' $Env:TES3MP_MAX_CLIENTS_PER_IP
    'allowConsole'        = ConvertTo-LuaBool $Env:TES3MP_ALLOW_CONSOLE
    'passTimeWhenEmpty'   = ConvertTo-LuaBool $Env:TES3MP_PASS_TIME_WHEN_EMPTY
    'shareJournal'        = ConvertTo-LuaBool $Env:TES3MP_SHARE_JOURNAL
    'shareMapExploration' = ConvertTo-LuaBool $Env:TES3MP_SHARE_MAP_EXPLORATION
}

$text = Get-Content -Path $luaFile -Raw
$changed = $false
foreach ($key in $lua.Keys) {
    $value = $lua[$key]
    if ($null -eq $value) { continue }
    $pattern = "(?m)^config\.$key\s*=.*$"
    if ($text -notmatch $pattern) {
        Write-Log -Level Warning "config.$key not found in $luaFile; left alone"
        continue
    }
    # Only the first match; a MatchEvaluator keeps $ and \ in the value literal
    $text = ([regex]$pattern).Replace($text, { param($m) "config.$key = $value" }, 1)
    $changed = $true
}
if ($changed) {
    [System.IO.File]::WriteAllText($luaFile, $text)
    chown "$($Env:UID):$($Env:GID)" $luaFile
    Write-Log "Wrote TES3MP_* CoreScripts settings to $luaFile"
}
