#Requires -Modules Logging

# Write the KAG_* settings into autoconfig.cfg (lines of `name = value   # comment`). It is edited
# through the merged view, so it lands in Overlay/ and can be edited there; variables without a
# KAG_* setting are never touched. The server writes every variable back into the file when it
# exits cleanly, so a file that doesn't exist yet (first start) is created with just these lines.

$cfg = Join-Path $Env:SERVER_ROOT 'autoconfig.cfg'
$lines = [System.Collections.Generic.List[string]]::new()
if (Test-Path -Path $cfg) {
    $lines.AddRange([string[]]([System.IO.File]::ReadAllText($cfg) -split "\r?\n"))
    while ($lines.Count -and $lines[$lines.Count - 1] -eq '') { $lines.RemoveAt($lines.Count - 1) }
}

# Replace the value of `name = ...`, keeping the column-aligned comment, or append the variable
function Set-CfgValue([string] $Name, [string] $Value) {
    $pattern = '^' + [regex]::Escape($Name) + '\s*='
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $pattern) {
            $comment = ''
            if ($lines[$i] -match '^[^#]*?(\s+#.*)$') { $comment = $Matches[1] }
            $setting = "$Name = $Value"
            if ($comment) {
                $comment = $comment.TrimStart()
                $setting = $setting.PadRight(72) + ' ' + $comment
            }
            $lines[$i] = $setting
            return
        }
    }
    $lines.Add("$Name = $Value")
}

function ConvertTo-Bit([string] $Value) {
    if (-not $Value) { return '' }
    if ($Value -in 'true', '1', 'yes') { '1' } else { '0' }
}

$settings = [ordered]@{
    'sv_port'             = $Env:KAG_PORT
    'sv_name'             = $Env:KAG_SERVER_NAME
    'sv_info'             = $Env:KAG_SERVER_INFO
    'sv_maxplayers'       = $Env:KAG_MAX_PLAYERS
    'sv_spectatorslots'   = $Env:KAG_SPECTATOR_SLOTS
    'sv_password'         = $Env:KAG_PASSWORD
    'sv_rconpassword'     = $Env:KAG_RCON_PASSWORD
    'sv_tcpr'             = (ConvertTo-Bit $Env:KAG_TCPR)
    'sv_gamemode'         = $Env:KAG_GAME_MODE
    'sv_mapcycle_shuffle' = (ConvertTo-Bit $Env:KAG_MAP_CYCLE_SHUFFLE)
    'sv_canpause'         = (ConvertTo-Bit $Env:KAG_CAN_PAUSE)
    # Colour codes would end up in docker logs
    'g_ansiconsole'       = '0'
}

# A LAN server doesn't register with the kag2d.com master list or send it minimaps
if ($Env:KAG_LAN) {
    $register = if ((ConvertTo-Bit $Env:KAG_LAN) -eq '1') { '0' } else { '1' }
    $settings['sv_register']    = $register
    $settings['sv_sendminimap'] = $register
}

# Map cycle: KAG_MAP_CYCLE=keep leaves sv_mapcycle alone; empty = the game mode's own cycle
# (Base/Rules/<mode>/mapcycle.cfg); otherwise the maps (paths under Base/, e.g.
# Maps/Official/CTF/FG_Forsaken.png, or bare file names) are written into
# Base/Maps/lancommander_mapcycle.cfg. KAG only finds files that are under Base/ (or a mod) at
# startup, and it crashes (exit 139) when the cycle has no loadable map, so unknown maps are
# dropped and an empty result falls back to the game mode's cycle.
$base = Join-Path $Env:SERVER_ROOT 'Base'
$baseFiles = $null
function Resolve-Map([string] $Map) {
    $Map = $Map.Replace('\', '/').TrimStart('/')
    if ($Map -match '^Base/') { $Map = $Map.Substring(5) }
    if (Test-Path -LiteralPath (Join-Path $base $Map) -PathType Leaf) { return $Map }
    if ($null -eq $script:baseFiles) {
        $script:baseFiles = @(Get-ChildItem -Path $base -Recurse -File -Include '*.png', '*.kag', '*.as' -ErrorAction SilentlyContinue)
    }
    $name = Split-Path -Leaf $Map
    $match = $script:baseFiles | Where-Object { $_.Name -ieq $name } | Select-Object -First 1
    if ($match) { return [System.IO.Path]::GetRelativePath($base, $match.FullName).Replace('\', '/') }
    return $null
}

$settings['sv_mapcycle'] = ''
if ($Env:KAG_MAP_CYCLE -ieq 'keep') {
    Write-Log "KAG_MAP_CYCLE=keep; sv_mapcycle left as it is"
    $settings.Remove('sv_mapcycle')
} elseif ($Env:KAG_MAP_CYCLE) {
    $maps = @()
    foreach ($map in @($Env:KAG_MAP_CYCLE -split '[;,\r\n]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
        $resolved = Resolve-Map $map
        if ($resolved) { $maps += $resolved }
        else { Write-Log -Level Warning "Map $map not found under Base/; left out of the cycle" }
    }

    if ($maps) {
        Write-Log "Map cycle: $($maps -join ', ')"

        # The end-of-match map vote (Rules/CommonScripts/MapVotesCommon.as) needs 3 maps for its
        # 3 buttons. With fewer it loads the next map from inside onRestart, which recurses until
        # the server segfaults, so a short cycle is padded by repeating its maps.
        $count = $maps.Count
        for ($i = 0; $maps.Count -lt 3; $i++) { $maps += $maps[$i % $count] }

        $cycleFile = Join-Path $base 'Maps/lancommander_mapcycle.cfg'
        $text = "# Written by 30-ConfigureKAG.ps1 from KAG_MAP_CYCLE`nmapcycle = $($maps -join '; ')`n"
        [System.IO.File]::WriteAllText($cycleFile, $text)
        chown "$($Env:UID):$($Env:GID)" $cycleFile
        $settings['sv_mapcycle'] = 'Maps/lancommander_mapcycle.cfg'
    } else {
        Write-Log -Level Warning "No KAG_MAP_CYCLE map was found; using the game mode's own cycle"
    }
}

foreach ($name in $settings.Keys) {
    $value = $settings[$name]
    # sv_mapcycle is cleared on purpose; every other empty setting is left alone
    if ($value -or $name -eq 'sv_mapcycle') { Set-CfgValue $name $value }
}

[System.IO.File]::WriteAllText($cfg, ($lines -join "`n") + "`n")
chown "$($Env:UID):$($Env:GID)" $cfg
Write-Log "Applied KAG_* settings to $cfg (game mode $($settings['sv_gamemode']))"
