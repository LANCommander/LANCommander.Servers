#Requires -Modules Logging

# LegendServ.exe has no config file or command-line settings. Its Host Settings dialog is filled
# from HKLM\Software\New World Computing\Legends of Might and Magic\1.0 (32-bit view) and the map
# rotation from ROTATION.TXT in the game folder. When OK is pressed, it saves the dialog back to
# both and starts hosting. This hook writes the LOMM_* settings to both on every start, and the
# launcher (lomm-server) presses OK.
#
# The server password isn't saved anywhere, so the launcher types LOMM_PASSWORD into the dialog.

$runAs = "$($Env:UID):$($Env:GID)"

if (-not (Test-Path -Path (Join-Path $Env:SERVER_ROOT 'LegendServ.exe'))) {
    Write-Log -Level Error "LegendServ.exe not found in $Env:SERVER_ROOT; skipping server configuration"
    return
}

function ConvertTo-Flag([string] $Name, [string] $Value) {
    if ($Value -match '^(1|true|yes|on)$') { return 1 }
    if ($Value -match '^(0|false|no|off|)$') { return 0 }
    throw "$Name must be true or false, not '$Value'"
}

# The ranges are the ones the dialog enforces. A value outside them makes LegendServ show an error
# box instead of hosting.
function ConvertTo-Number([string] $Name, [string] $Value, [int] $Min, [int] $Max) {
    $number = 0
    if (-not [int]::TryParse($Value, [ref] $number) -or $number -lt $Min -or $number -gt $Max) {
        throw "$Name must be a number from $Min to $Max, not '$Value'"
    }
    return $number
}

# --- Map rotation ---
# The 20 retail maps are inside Data\worlds.rez. Custom maps are Data\Worlds\<name>.dat. A name the
# server doesn't know makes it hang at "Starting world.." forever, so unknown names are dropped.
$retailMaps = @(
    '_RescueAtTheRuins', '_TempleOfBark', 'BloodFeud', 'ChateauEscape', 'CultOfTheSpider',
    'Dragonblade', 'DragonSlayers', 'DungeonRescue', 'DungeonsOfDragadune', 'FahlteeTower',
    'ForgottenKeep', 'Gauntlet', 'Hideout', 'IsleOfFire', 'OnTheRun', 'SecretsOfTheSphinx',
    'SpidersDen', 'Stoneham', 'SwordInTheStone', 'WeddingDay'
)

$rotationFile = Join-Path $Env:SERVER_ROOT 'ROTATION.TXT'

if ($Env:LOMM_MAPS -ieq 'config') {
    Write-Log "LOMM_MAPS=config: keeping ROTATION.TXT as it is"
} else {
    $known = @{}
    foreach ($map in $retailMaps) { $known[$map.ToLowerInvariant()] = $map }

    $worlds = Join-Path $Env:SERVER_ROOT 'Data/Worlds'
    if (Test-Path -Path $worlds) {
        Get-ChildItem -Path $worlds -File | Where-Object { $_.Extension -ieq '.dat' } | ForEach-Object {
            $known[$_.BaseName.ToLowerInvariant()] = $_.BaseName
        }
    }

    $requested = if ($Env:LOMM_MAPS) {
        @($Env:LOMM_MAPS -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    } else {
        $retailMaps
    }

    $rotation = foreach ($map in $requested) {
        $name = $map -replace '(?i)\.dat$', ''
        if ($known.ContainsKey($name.ToLowerInvariant())) {
            $known[$name.ToLowerInvariant()]
        } else {
            Write-Log -Level Warning "Map '$map' is not a retail map or a Data/Worlds/*.dat file; leaving it out of the rotation"
        }
    }

    if (-not $rotation) {
        throw "No valid maps in LOMM_MAPS ('$Env:LOMM_MAPS')"
    }

    [System.IO.File]::WriteAllText($rotationFile, (($rotation | ForEach-Object { "$_`r`n" }) -join ''))
    chown $runAs $rotationFile

    Write-Log "Map rotation: $($rotation -join ', ')"
}

# --- Registry ---
$connectionTypes = [ordered]@{ '56k' = 0; 'isdn' = 1; 'cable' = 2; 'dsl' = 3; 't1' = 4; 'custom' = 5 }
$connectionKey = "$Env:LOMM_CONNECTION_TYPE".ToLowerInvariant() -replace '[^a-z0-9]', ''
if (-not $connectionKey) { $connectionKey = 't1' }
if (-not $connectionTypes.Contains($connectionKey)) {
    throw "LOMM_CONNECTION_TYPE must be one of $($connectionTypes.Keys -join ', '), not '$Env:LOMM_CONNECTION_TYPE'"
}

$dwords = [ordered]@{
    'ServerTotalPlayers' = ConvertTo-Number 'LOMM_MAX_PLAYERS'   $Env:LOMM_MAX_PLAYERS   1 16
    'ServerMapTime'      = ConvertTo-Number 'LOMM_MAP_TIME'      $Env:LOMM_MAP_TIME      0 180
    'ServerRoundTime'    = ConvertTo-Number 'LOMM_ROUND_TIME'    $Env:LOMM_ROUND_TIME    0 10
    'ServerPurchaseTime' = ConvertTo-Number 'LOMM_PURCHASE_TIME' $Env:LOMM_PURCHASE_TIME 0 15
    'FriendlyFire'       = ConvertTo-Flag 'LOMM_FRIENDLY_FIRE'        $Env:LOMM_FRIENDLY_FIRE
    'AllowVoting'        = ConvertTo-Flag 'LOMM_ALLOW_VOTING'         $Env:LOMM_ALLOW_VOTING
    'BalanceTeams'       = ConvertTo-Flag 'LOMM_BALANCE_TEAMS'        $Env:LOMM_BALANCE_TEAMS
    'Monsters'           = ConvertTo-Flag 'LOMM_MONSTERS'             $Env:LOMM_MONSTERS
    'SuperWeapons'       = ConvertTo-Flag 'LOMM_SUPER_WEAPONS'        $Env:LOMM_SUPER_WEAPONS
    'DmgThroughWalls'    = ConvertTo-Flag 'LOMM_DAMAGE_THROUGH_WALLS' $Env:LOMM_DAMAGE_THROUGH_WALLS
    'LockedCam'          = ConvertTo-Flag 'LOMM_LOCKED_CHASE_CAM'     $Env:LOMM_LOCKED_CHASE_CAM
    'LanOnly'            = ConvertTo-Flag 'LOMM_LAN_ONLY'             $Env:LOMM_LAN_ONLY
    'ConnectionSpeed'    = $connectionTypes[$connectionKey]
    'Port'               = ConvertTo-Number 'LOMM_PORT'         $Env:LOMM_PORT         1 65535
    'GameSpyPort'        = ConvertTo-Number 'LOMM_GAMESPY_PORT' $Env:LOMM_GAMESPY_PORT 1 65535
}

# Upload bandwidth (bytes/s) only applies to the custom connection type; the others set their own
if ($Env:LOMM_UPLOAD_BANDWIDTH) {
    $dwords['CustomDataRate'] = ConvertTo-Number 'LOMM_UPLOAD_BANDWIDTH' $Env:LOMM_UPLOAD_BANDWIDTH 1 10000000
}

$serverName = "$Env:LOMM_SERVER_NAME".Trim()
if (-not $serverName) { throw "LOMM_SERVER_NAME can't be empty" }

$reg = [System.Collections.Generic.List[string]]::new()
$reg.Add('REGEDIT4')
$reg.Add('')
$reg.Add('[HKEY_LOCAL_MACHINE\Software\New World Computing\Legends of Might and Magic\1.0]')
$reg.Add('"ServerName"="' + $serverName.Replace('\', '\\').Replace('"', '\"') + '"')
foreach ($s in $dwords.GetEnumerator()) {
    $reg.Add(('"{0}"=dword:{1:x8}' -f $s.Key, $s.Value))
}
$reg.Add('')

$regFile = '/tmp/lomm-settings.reg'
[System.IO.File]::WriteAllText($regFile, ($reg -join "`r`n"), [System.Text.Encoding]::Latin1)
chown $runAs $regFile

# /reg:32 writes the 32-bit view (Wow6432Node in a 64-bit prefix), which is where the game looks
& gosu $runAs wine reg import $regFile /reg:32 2>&1 | Where-Object { $_ -notmatch 'fixme|completed successfully' } | ForEach-Object { Write-Log "$_" }
$exitCode = $LASTEXITCODE
& gosu $runAs wineserver --wait
Remove-Item -Force -Path $regFile

if ($exitCode -ne 0) {
    throw "Could not write the server settings to the Wine registry (exit code $exitCode)"
}

Write-Log ("Server settings: '{0}', {1} players, map time {2} min, round time {3} min, ports {4}/{5}, password {6}" -f
    $serverName, $dwords['ServerTotalPlayers'], $dwords['ServerMapTime'], $dwords['ServerRoundTime'],
    $dwords['Port'], $dwords['GameSpyPort'], $(if ($Env:LOMM_PASSWORD) { 'set' } else { 'none' }))
