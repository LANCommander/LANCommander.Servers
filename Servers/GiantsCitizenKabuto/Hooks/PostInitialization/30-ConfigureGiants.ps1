#Requires -Modules Logging

# Write the server rotation Bin/<GIANTS_GDF_NAME>.gdf from the GIANTS_* settings. This is the binary
# file the game's dedicated.exe setup tool (v1.06) writes with "Save":
#
#   header, 0x130 bytes:
#     int32  version (4)
#     int32  number of entries
#     int32  max players (2-20, includes the server itself)
#     byte   no voting (0/1)
#     char   game name[31]
#     char   message of the day[255]
#     (zero padding)
#   then one 0x140-byte entry per game in the rotation:
#     int32  vimp meat energy (0 easy, 1 medium, 2 hard)
#     int32  max smarties, as an index into 15, 13, 10, 7, 4, 0
#     int32  points per kill, points per capture, player score limit, team score limit,
#            time limit (minutes)
#     int32  first base destroyed (0/1)
#     int32  game type (0 DM ... 7 DefendBaseCap, see $gameTypes)
#     int32  teams (0 MvM ... 6 RvK, see $teams)
#     int32  index in the setup tool's world list (unused by the server; written as 0)
#     int32  damage teammates (0/1), no vimps (0/1), detente
#     char   world[256], e.g. "m_mecc_desertsnakes"
#     uint32 unavailable Mecc weapons, unavailable Reaper weapons (bit masks, readme_dedicated.txt)
#
# The file is written through the merged view, so it lands in Overlay/. It is regenerated on every
# start while the marker file Bin/<name>.gdf.lancommander exists next to it; a .gdf without one (your
# own, saved from dedicated.exe) is left alone.
#
# GiantsDedicated shows a modal "Giants Fatal Error" box and hangs when a world doesn't exist, which is
# invisible in a container, so every world is checked against the installed ones first. A world that
# exists but doesn't suit the teams is silently replaced by the server (MvM on m_3way_l1 played
# m_mecc_desertsnakes), so that only gets a warning.

$name    = if ($Env:GIANTS_GDF_NAME) { $Env:GIANTS_GDF_NAME } else { 'lancommander' }
$binDir  = Join-Path $Env:SERVER_ROOT 'Bin'
$file    = Join-Path $binDir "$name.gdf"
$managed = "$file.lancommander"

if ((Test-Path -Path $file) -and -not (Test-Path -Path $managed)) {
    Write-Log "Bin/$name.gdf is not managed by this image; using it as is"
    return
}

if (-not (Test-Path -Path $binDir)) {
    Write-Log -Level Error "$binDir not found; is the game installed?"
    return
}

# A hook error doesn't stop the container, so drop the old rotation first: a bad setting then makes
# the launcher fail ("Bin/<name>.gdf not found") instead of quietly running the previous rotation.
Remove-Item -Force -Path $file -ErrorAction SilentlyContinue

# Enum values as GiantsDedicated.exe names them (GameType%s / GameTeam%s)
$gameTypes = @('DM', 'DMFullBase', 'DMCap', 'DMCapFullBase', 'Build', 'BuildCap', 'DefendBase', 'DefendBaseCap')
$teams     = @('MvM', 'MvMvM', 'RvR', 'MvR', 'MvRvK', 'MvK', 'RvK')
$smarties  = @(15, 13, 10, 7, 4, 0)
$vimpMeat  = @('easy', 'medium', 'hard')

function ConvertTo-Bool([string] $Value) {
    if ("$Value".Trim().ToLower() -in @('true', '1', 'yes', 'on')) { 1 } else { 0 }
}

function ConvertTo-Int([string] $Value, [string] $Setting) {
    $v = "$Value".Trim()
    $n = 0
    if ($v -match '^0x[0-9a-f]+$') { return [Convert]::ToUInt32($v.Substring(2), 16) }
    if ([int]::TryParse($v, [ref] $n) -and $n -ge 0) { return $n }
    throw "$Setting must be a whole number, not '$Value'"
}

function Get-EnumIndex([string[]] $Names, [string] $Value, [string] $Setting) {
    $v = "$Value".Trim()
    for ($i = 0; $i -lt $Names.Count; $i++) {
        if ($Names[$i] -eq $v -or "$i" -eq $v) { return $i }
    }
    throw "$Setting '$Value' must be one of $($Names -join ', ')"
}

# Installed worlds: built-in Bin/w_<world>.gzp and add-on Bin/Worlds/w_<world>.gck, keyed by lower case
# (-like, not -Filter: file names mix cases and -Filter is case-sensitive on Linux)
$worlds = @{}
foreach ($f in @(Get-ChildItem -Path $binDir -File) +
               @(Get-ChildItem -Path (Join-Path $binDir 'Worlds') -File -ErrorAction SilentlyContinue)) {
    if ($f.Name -like 'w_m_*.gzp' -or $f.Name -like 'w_m_*.gck') {
        $worlds[$f.BaseName.Substring(2).ToLower()] = $true
    }
}

# Defaults for every entry, from the GIANTS_* settings
$defaults = [ordered]@{
    timelimit                = $Env:GIANTS_TIME_LIMIT
    pointsperkill            = $Env:GIANTS_POINTS_PER_KILL
    pointspercapture         = $Env:GIANTS_POINTS_PER_CAPTURE
    playerscorelimit         = $Env:GIANTS_PLAYER_SCORE_LIMIT
    teamscorelimit           = $Env:GIANTS_TEAM_SCORE_LIMIT
    detente                  = $Env:GIANTS_DETENTE
    firstbasedestroyed       = $Env:GIANTS_FIRST_BASE_DESTROYED
    damageteammates          = $Env:GIANTS_DAMAGE_TEAMMATES
    novimps                  = $Env:GIANTS_NO_VIMPS
    maxsmarties              = $Env:GIANTS_MAX_SMARTIES
    vimpmeatenergy           = $Env:GIANTS_VIMP_MEAT_ENERGY
    meccweaponsunavailable   = $Env:GIANTS_MECC_WEAPONS_UNAVAILABLE
    reaperweaponsunavailable = $Env:GIANTS_REAPER_WEAPONS_UNAVAILABLE
}

$latin1  = [System.Text.Encoding]::Latin1
$entries = [System.Collections.Generic.List[byte[]]]::new()

foreach ($entry in ("$Env:GIANTS_ROTATION" -split '[;\r\n]+' | Where-Object { $_.Trim() })) {
    $parts = @($entry -split ',' | ForEach-Object { $_.Trim() })
    if ($parts.Count -lt 3) {
        throw "GIANTS_ROTATION entry '$($entry.Trim())' must be 'World, GameType, Teams[, setting=value ...]'"
    }

    $world    = $parts[0].ToLower() -replace '^w_', ''
    $gameType = Get-EnumIndex $gameTypes $parts[1] 'Game type'
    $team     = Get-EnumIndex $teams $parts[2] 'Teams'

    if (-not $worlds.ContainsKey($world)) {
        throw "World '$world' in GIANTS_ROTATION is not installed (have: $(($worlds.Keys | Sort-Object) -join ', '))"
    }

    $expected = switch ($teams[$team]) { 'MvM' { 'm_mecc_' } 'RvR' { 'm_reaper_' } default { 'm_3way_' } }
    if (-not $world.StartsWith($expected)) {
        Write-Log -Level Warning "World $world is not a $expected* world, which $($teams[$team]) normally uses; the server may play another world instead"
    }

    # Per-entry overrides: setting=value, with the setting named like the GIANTS_* variable
    $s = [ordered]@{}
    foreach ($key in $defaults.Keys) { $s[$key] = $defaults[$key] }
    foreach ($override in ($parts | Select-Object -Skip 3)) {
        $key, $value = $override -split '=', 2
        $key = ($key -replace '[_\-\s]', '').ToLower()
        if ($null -eq $value -or -not $s.Contains($key)) {
            throw "GIANTS_ROTATION setting '$override' must be one of $($defaults.Keys -join ', ') as setting=value"
        }
        $s[$key] = $value.Trim()
    }

    $smartieCount = ConvertTo-Int $s.maxsmarties 'Max smarties'
    $smartieIndex = [array]::IndexOf($smarties, [int] $smartieCount)
    if ($smartieIndex -lt 0) { throw "Max smarties must be one of $($smarties -join ', '), not $smartieCount" }

    $buffer = [System.IO.MemoryStream]::new()
    $w = [System.IO.BinaryWriter]::new($buffer)
    $w.Write([int] (Get-EnumIndex $vimpMeat "$($s.vimpmeatenergy)".ToLower() 'Vimp meat energy'))
    $w.Write([int] $smartieIndex)
    $w.Write([int] (ConvertTo-Int $s.pointsperkill 'Points per kill'))
    $w.Write([int] (ConvertTo-Int $s.pointspercapture 'Points per capture'))
    $w.Write([int] (ConvertTo-Int $s.playerscorelimit 'Player score limit'))
    $w.Write([int] (ConvertTo-Int $s.teamscorelimit 'Team score limit'))
    $w.Write([int] (ConvertTo-Int $s.timelimit 'Time limit'))
    $w.Write([int] (ConvertTo-Bool $s.firstbasedestroyed))
    $w.Write([int] $gameType)
    $w.Write([int] $team)
    $w.Write([int] 0)
    $w.Write([int] (ConvertTo-Bool $s.damageteammates))
    $w.Write([int] (ConvertTo-Bool $s.novimps))
    $w.Write([int] (ConvertTo-Int $s.detente 'Detente'))
    $worldBytes = [byte[]]::new(256)
    $latin1.GetBytes($world).CopyTo($worldBytes, 0)
    $w.Write($worldBytes)
    $w.Write([uint32] (ConvertTo-Int $s.meccweaponsunavailable 'Mecc weapons unavailable'))
    $w.Write([uint32] (ConvertTo-Int $s.reaperweaponsunavailable 'Reaper weapons unavailable'))
    $w.Flush()
    $entries.Add($buffer.ToArray())

    Write-Log "Rotation: $world, $($gameTypes[$gameType]), $($teams[$team]), $($s.timelimit) min"
}

if (-not $entries.Count) { throw 'GIANTS_ROTATION is empty' }

$maxPlayers = ConvertTo-Int $Env:GIANTS_MAX_PLAYERS 'GIANTS_MAX_PLAYERS'
if ($maxPlayers -lt 2 -or $maxPlayers -gt 20) { throw "GIANTS_MAX_PLAYERS must be 2-20, not $maxPlayers" }

$serverName = "$Env:GIANTS_SERVER_NAME"
if ($serverName.Length -gt 30) {
    Write-Log -Level Warning "GIANTS_SERVER_NAME is longer than 30 characters; it is cut off"
    $serverName = $serverName.Substring(0, 30)
}
$motd = "$Env:GIANTS_MOTD"
if ($motd.Length -gt 254) { $motd = $motd.Substring(0, 254) }

$header = [byte[]]::new(0x130)
[BitConverter]::GetBytes([int] 4).CopyTo($header, 0)
[BitConverter]::GetBytes([int] $entries.Count).CopyTo($header, 4)
[BitConverter]::GetBytes([int] $maxPlayers).CopyTo($header, 8)
$header[0x0c] = [byte] (ConvertTo-Bool $Env:GIANTS_NO_VOTING)
$latin1.GetBytes($serverName).CopyTo($header, 0x0d)
$latin1.GetBytes($motd).CopyTo($header, 0x2d)

$out = [System.IO.MemoryStream]::new()
$out.Write($header, 0, $header.Length)
foreach ($e in $entries) { $out.Write($e, 0, $e.Length) }

[System.IO.File]::WriteAllBytes($file, $out.ToArray())
New-Item -ItemType File -Path $managed -Force | Out-Null
chown "$($Env:UID):$($Env:GID)" $file $managed

Write-Log "Generated Bin/$name.gdf ($($entries.Count) game(s), $maxPlayers players)"
