#Requires -Modules Logging

# Write the AA_* settings into the game's server ini (AA_INI, default System/server.ini). It's
# edited through the merged view, so the changed copy lands in Overlay/ and can be edited there;
# keys without an AA_* setting are never touched.

$system = Join-Path $Env:SERVER_ROOT 'System'
$ini    = Join-Path $system $Env:AA_INI

if (-not (Test-Path -Path $ini)) {
    $template = Join-Path $system 'server.ini'
    if ($Env:AA_INI -ne 'server.ini' -and (Test-Path -Path $template)) {
        Copy-Item -Path $template -Destination $ini
        Write-Log "Created $ini from server.ini"
    } else {
        Write-Log -Level Error "$ini not found; skipping server configuration"
        return
    }
}

$text    = [System.IO.File]::ReadAllText($ini)
$newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
$lines   = [System.Collections.Generic.List[string]]::new([string[]]($text -split "\r?\n"))

function Get-SectionRange([string] $Section) {
    $start = $lines.IndexOf("[$Section]")
    if ($start -lt 0) { return $null }

    $end = $start + 1
    while ($end -lt $lines.Count -and -not $lines[$end].StartsWith('[')) { $end++ }
    return @($start, $end)
}

# Set Key=Value in [Section], replacing the first existing Key= line or appending to the section
function Set-IniValue([string] $Section, [string] $Key, [string] $Value) {
    $range = Get-SectionRange $Section
    if (-not $range) {
        if ($lines.Count -and $lines[$lines.Count - 1] -ne '') { $lines.Add('') }
        $lines.Add("[$Section]")
        $lines.Add("$Key=$Value")
        return
    }

    $start, $end = $range
    for ($i = $start + 1; $i -lt $end; $i++) {
        if ($lines[$i].StartsWith("$Key=", [System.StringComparison]::OrdinalIgnoreCase)) {
            $lines[$i] = "$Key=$Value"
            return
        }
    }

    # Insert after the section's last non-blank line
    $at = $end
    while ($at -gt $start + 1 -and [string]::IsNullOrWhiteSpace($lines[$at - 1])) { $at-- }
    $lines.Insert($at, "$Key=$Value")
}

# GameSpy query reporting binds to [IpDrv.GameSpyQR] IP. The stock 127.0.0.1 hides the server
# from the LAN browser, so default to the container's own address.
$gameSpyIp = $Env:AA_GAMESPY_IP
if (-not $gameSpyIp) {
    $gameSpyIp = (hostname -I 2>$null) -split '\s+' | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -First 1
}

$settings = @(
    @('URL',                                  'Port',           $Env:AA_PORT),
    @('Engine.GameReplicationInfo',           'ServerName',     $Env:AA_SERVER_NAME),
    @('Engine.GameReplicationInfo',           'AdminName',      $Env:AA_ADMIN_NAME),
    @('Engine.GameReplicationInfo',           'AdminEmail',     $Env:AA_ADMIN_EMAIL),
    @('Engine.GameReplicationInfo',           'MOTDLine1',      $Env:AA_MOTD),
    @('Engine.GameInfo',                      'MaxPlayers',     $Env:AA_MAX_PLAYERS),
    @('Engine.GameInfo',                      'TimeLimit',      $Env:AA_TIME_LIMIT),
    @('Engine.AccessControl',                 'GamePassword',   $Env:AA_GAME_PASSWORD),
    @('Engine.AccessControl',                 'AdminPassword',  $Env:AA_ADMIN_PASSWORD),
    @('AGP_Gameplay.AGP_GameDeathMatch',      'RoundsPerMatch', $Env:AA_ROUNDS_PER_MATCH),
    @('IpDrv.GameSpyQR',                      'IP',             $gameSpyIp)
)

foreach ($s in $settings) {
    if ($s[2]) { Set-IniValue $s[0] $s[1] $s[2] }
}

# Map rotation: [AGP_Gameplay.AGP_MapList] holds repeated Maps= lines plus a MapNum count, and
# rotation only happens with [AGP_Gameplay.AGP_GameDeathMatch] bCycleMaps=True.
if ($Env:AA_MAPS) {
    $available = @{}
    Get-ChildItem -Path (Join-Path $Env:SERVER_ROOT 'Maps') -Filter '*.aao' -File -ErrorAction SilentlyContinue |
        ForEach-Object { $available[$_.Name.ToLowerInvariant()] = $_.Name }

    $maps = @()
    foreach ($m in ($Env:AA_MAPS -split '[,;\s]+' | Where-Object { $_ })) {
        if ($m -notmatch '\.aao$') { $m = "$m.aao" }
        if ($available.Count -and -not $available.ContainsKey($m.ToLowerInvariant())) {
            Write-Log -Level Warning "Map $m is not in Maps/; left out of the rotation"
            continue
        }
        $maps += $(if ($available.Count) { $available[$m.ToLowerInvariant()] } else { $m })
    }

    # Replace the list where it stands, so the comments around it stay in place
    $section = 'AGP_Gameplay.AGP_MapList'
    $range = Get-SectionRange $section
    if (-not $range) {
        if ($lines.Count -and $lines[$lines.Count - 1] -ne '') { $lines.Add('') }
        $lines.Add("[$section]")
        $range = Get-SectionRange $section
    }
    $start, $end = $range
    $at = $end
    while ($at -gt $start + 1 -and [string]::IsNullOrWhiteSpace($lines[$at - 1])) { $at-- }
    for ($i = $end - 1; $i -gt $start; $i--) {
        if ($lines[$i] -match '^(Maps|MapNum)=') { $lines.RemoveAt($i); $at = $i }
    }
    $lines.Insert($at++, "MapNum=$($maps.Count)")
    foreach ($m in $maps) { $lines.Insert($at++, "Maps=$m") }

    Set-IniValue 'AGP_Gameplay.AGP_GameDeathMatch' 'bCycleMaps' $(if ($maps.Count -gt 1) { 'True' } else { 'False' })
    Write-Log "Map rotation: $($maps -join ', ')"
}

[System.IO.File]::WriteAllText($ini, ($lines -join $newline))
chown "$($Env:UID):$($Env:GID)" $ini

Write-Log "Applied AA_* settings to $ini"
