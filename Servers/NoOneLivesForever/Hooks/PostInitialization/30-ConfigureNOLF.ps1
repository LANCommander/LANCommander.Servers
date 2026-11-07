#Requires -Modules Logging

# Configure NolfServ for `-nowiz`:
#
# - startup.txt: the rez files NolfServ loads, in order. The stock file names patch rez files that
#   a 1.004 GOTY install doesn't have and never loads anything from Custom\, so it is rewritten with
#   the retail rez files that exist plus NOLF_CUSTOM_REZ (the NOLF Modernizer by default).
# - NetHost.txt: the [Host] section NolfServ saves its setup wizard answers to and reads back with
#   -nowiz. Each line is `Key = value`, numbers as `16.000000f`, strings quoted. Keys without a
#   non-empty NOLF_* setting keep their value, so the file can also be edited in Overlay/.
#
# Both files are edited through the merged view, so the edited copies land in Overlay/.

$root = $Env:SERVER_ROOT

if (-not (Test-Path -Path (Join-Path $root 'NolfServ.exe'))) {
    Write-Log -Level Error "NolfServ.exe not found in $root; skipping server configuration"
    return
}

# The game is case-insensitive, the filesystem isn't: find files by name in any case
function Find-Child([string] $Dir, [string] $Name) {
    if (-not (Test-Path -Path $Dir -PathType Container)) { return $null }
    Get-ChildItem -Path $Dir -Force | Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
}

function Find-RelativePath([string] $Path) {
    $current = Get-Item -Path $root
    foreach ($part in ($Path -split '[\\/]' | Where-Object { $_ })) {
        $current = Find-Child $current.FullName $part
        if (-not $current) { return $null }
    }
    return $current
}

function Get-RelativePath($Item) {
    [System.IO.Path]::GetRelativePath($root, $Item.FullName).Replace('/', '\')
}

# ---------------------------------------------------------------------------------------------
# Rez files

# The stock startup.txt order, plus the nolfcres003.rez the 1.003 update adds
$retail = @('nolf', 'nolf.rez', 'nolf2.rez', 'nolfdll.rez', 'nolfl.rez', 'nolfu003.rez',
    'nolfcres003.rez', 'nolfc001.rez', 'nolfc002.rez', 'nolfgoty.rez')

$rez = [System.Collections.Generic.List[object]]::new()
foreach ($name in $retail) {
    $item = Find-Child $root $name
    if ($item) { $rez.Add($item) }
}

if (-not ($rez | Where-Object { $_.Name -ieq 'nolf.rez' })) {
    Write-Log -Level Error "NOLF.REZ not found in $root; the server can't start"
}

foreach ($name in @($Env:NOLF_CUSTOM_REZ -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    $path = if ($name -match '[\\/]') { $name } else { "Custom\$name" }
    $item = Find-RelativePath $path

    if ($item) {
        $rez.Add($item)
    } elseif ($name -ieq 'MODERNIZER.REZ') {
        Write-Log "Custom\MODERNIZER.REZ not found; running without the NOLF Modernizer"
    } else {
        Write-Log -Level Warning "NOLF_CUSTOM_REZ: $path not found; skipping it"
    }
}

$lines = @('[Rez]')
for ($i = 0; $i -lt $rez.Count; $i++) {
    $lines += "Rez$i = `"$(Get-RelativePath $rez[$i])`""
}

$startup = Find-Child $root 'startup.txt'
$startupPath = if ($startup) { $startup.FullName } else { Join-Path $root 'startup.txt' }
[System.IO.File]::WriteAllText($startupPath, ($lines -join "`r`n") + "`r`n")
chown "$($Env:UID):$($Env:GID)" $startupPath

Write-Log "Rez files: $(($rez | ForEach-Object { Get-RelativePath $_ }) -join ', ')"

# ---------------------------------------------------------------------------------------------
# Levels: every Worlds\Multi\<type>\*.dat in the loaded rez files and loose folders

# A LithTech 1.x/2.0 rez file: a 127-byte text header, then a version, the root directory's
# position and size. Directory entries are `u32 type, pos, size, time`, then for a directory its
# name; for a resource `u32 id, char ext[4] (reversed), u32 numKeys, name, comment, keys`.
function Get-RezEntries([string] $Path) {
    $stream = [System.IO.File]::OpenRead($Path)
    $reader = [System.IO.BinaryReader]::new($stream)
    $found  = [System.Collections.Generic.List[string]]::new()

    function Read-CString {
        $bytes = [System.Collections.Generic.List[byte]]::new()
        while ($true) {
            $b = $reader.ReadByte()
            if ($b -eq 0) { break }
            $bytes.Add($b)
        }
        [System.Text.Encoding]::Latin1.GetString($bytes.ToArray())
    }

    function Read-Dir([long] $Pos, [long] $Size, [string] $Prefix) {
        $end = $Pos + $Size
        while ($Pos -lt $end) {
            $stream.Position = $Pos
            $type = $reader.ReadUInt32()
            $childPos = $reader.ReadUInt32()
            $childSize = $reader.ReadUInt32()
            [void]$reader.ReadUInt32()

            if ($type -eq 1) {
                $name = Read-CString
                $Pos = $stream.Position
                Read-Dir $childPos $childSize "$Prefix$name\"
            } else {
                [void]$reader.ReadUInt32()
                $chars = [System.Text.Encoding]::Latin1.GetString($reader.ReadBytes(4)).TrimEnd([char]0).ToCharArray()
                [array]::Reverse($chars)
                $ext = -join $chars
                $keys = $reader.ReadUInt32()
                $name = Read-CString
                [void](Read-CString)
                $stream.Position += 4 * $keys
                $Pos = $stream.Position
                $found.Add("$Prefix$name.$ext")
            }
        }
    }

    try {
        $stream.Position = 127
        [void]$reader.ReadUInt32()
        $rootPos = $reader.ReadUInt32()
        $rootSize = $reader.ReadUInt32()
        Read-Dir $rootPos $rootSize ''
    } finally {
        $reader.Dispose()
    }

    $found
}

$isHarm = $Env:NOLF_GAME_TYPE -match '^(harm|h\.a\.r\.m\..*|hvu|ca|assault|1)$'
if (-not $isHarm -and $Env:NOLF_GAME_TYPE -and $Env:NOLF_GAME_TYPE -notmatch '^(deathmatch|dm|2)$') {
    Write-Log -Level Warning "Unknown NOLF_GAME_TYPE '$Env:NOLF_GAME_TYPE'; using deathmatch"
}

$typeDir = if ($isHarm) { 'AssaultMap' } else { 'DeathMatch' }
$available = [ordered]@{}

foreach ($item in $rez) {
    $entries = if ($item.PSIsContainer) {
        $dir = Find-RelativePath "$(Get-RelativePath $item)\Worlds\Multi\$typeDir"
        if ($dir) { Get-ChildItem -Path $dir.FullName -File | ForEach-Object { "WORLDS\MULTI\$typeDir\$($_.Name)" } }
    } else {
        try { Get-RezEntries $item.FullName } catch { Write-Log -Level Warning "Could not read $($item.Name): $_" }
    }

    foreach ($entry in $entries) {
        if ($entry -match "^Worlds\\Multi\\$typeDir\\([^\\]+)\.dat$") {
            $available[$Matches[1].ToUpperInvariant()] = $Matches[1]
        }
    }
}

$levels = @()
if ($Env:NOLF_LEVELS) {
    foreach ($level in @($Env:NOLF_LEVELS -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
        $name = ($level -replace '\.dat$', '') -split '[\\/]' | Select-Object -Last 1
        if ($available.Contains($name.ToUpperInvariant())) {
            $levels += $name
        } else {
            Write-Log -Level Warning "NOLF_LEVELS: no $typeDir level '$level' in the loaded rez files; skipping it"
        }
    }

    if ($levels.Count -eq 0) {
        Write-Log -Level Warning "None of NOLF_LEVELS exist; using every $typeDir level"
    }
}

if ($levels.Count -eq 0) {
    $levels = @($available.Values | Sort-Object)
}

if ($levels.Count -eq 0) {
    Write-Log -Level Error "No $typeDir levels found in the rez files; NolfServ won't start a game"
}

# ---------------------------------------------------------------------------------------------
# NetHost.txt

$hostFile = Find-Child $root 'NetHost.txt'
$hostPath = if ($hostFile) { $hostFile.FullName } else { Join-Path $root 'NetHost.txt' }

# Keys are case-insensitive to the game; keep the file's order and spelling
$settings = [ordered]@{}

if ($hostFile) {
    $section = ''
    foreach ($line in [System.IO.File]::ReadAllLines($hostPath)) {
        if ($line -match '^\s*\[(.+)\]\s*$') { $section = $Matches[1]; continue }
        if ($section -ieq 'Host' -and $line -match '^\s*([^=]+?)\s*=\s*(.*?)\s*$') {
            $settings[$Matches[1]] = $Matches[2]
        }
    }
}

function Format-Number([double] $Value) { $Value.ToString('F6', [cultureinfo]::InvariantCulture) + 'f' }
function Format-String([string] $Value) { '"' + $Value.Replace('"', '') + '"' }

function Set-Number([string] $Key, $Value) { $settings[$Key] = Format-Number ([double]$Value) }

function Set-Default([string] $Key, [string] $Value) {
    if (-not $settings.Contains($Key)) { $settings[$Key] = $Value }
}

function ConvertTo-Flag([string] $Value) {
    if ($Value -match '^(1|true|yes|on)$') { 1 } else { 0 }
}

# The wizard's defaults, so a fresh NetHost.txt has everything -nowiz needs
Set-Default 'NetPort'        (Format-Number 27888)
Set-Default 'NetMaxPlayers'  (Format-Number 16)
Set-Default 'NetSessionName' (Format-String 'No One Lives Forever')
Set-Default 'NetUsePassword' (Format-Number 0)
Set-Default 'NetPassword'    (Format-String 'password')
Set-Default 'SendBandwidth'  (Format-Number 1000000)

# 1 = H.A.R.M. vs. UNITY, 2 = Deathmatch. Anything else makes -nowiz fail with "Unable to start
# server".
Set-Number 'NetGameType' $(if ($isHarm) { 1 } else { 2 })

if ($Env:NOLF_SERVER_NAME) {
    $name = $Env:NOLF_SERVER_NAME.Replace('"', '')
    if ($name.Length -gt 24) {
        Write-Log -Level Warning "NOLF_SERVER_NAME is longer than 24 characters; cutting it to '$($name.Substring(0, 24))'"
        $name = $name.Substring(0, 24)
    }
    $settings['NetSessionName'] = Format-String $name
}

if ($Env:NOLF_PORT)        { Set-Number 'NetPort' $Env:NOLF_PORT }
if ($Env:NOLF_MAX_PLAYERS) { Set-Number 'NetMaxPlayers' $Env:NOLF_MAX_PLAYERS }

# An empty password turns password protection off
if ($Env:NOLF_PASSWORD) {
    Set-Number 'NetUsePassword' 1
    $settings['NetPassword'] = Format-String $Env:NOLF_PASSWORD
} else {
    Set-Number 'NetUsePassword' 0
}

if ($Env:NOLF_SEND_BANDWIDTH) { Set-Number 'SendBandwidth' $Env:NOLF_SEND_BANDWIDTH }

# The options pages: percentages are stored as fractions
$percent = [ordered]@{
    'NetRunSpeed'           = $Env:NOLF_RUN_SPEED
    'NetRespawnScale'       = $Env:NOLF_RESPAWN_SCALE
    'NetFallDamageScale'    = $Env:NOLF_FALL_DAMAGE
    'NetArmorHealthPercent' = $Env:NOLF_ARMOR_HEALTH_BONUS
}
foreach ($s in $percent.GetEnumerator()) {
    if ($s.Value) { Set-Number $s.Key ([double]$s.Value / 100) }
}

$numbers = [ordered]@{
    'NetDefaultWeapon' = $Env:NOLF_DEFAULT_WEAPON
    'NetIntelScore'    = $Env:NOLF_INTEL_SCORE
}
foreach ($s in $numbers.GetEnumerator()) {
    if ($s.Value) { Set-Number $s.Key $s.Value }
}

$flags = [ordered]@{
    'NetWeaponsStay'  = $Env:NOLF_WEAPONS_STAY
    'NetHitLocation'  = $Env:NOLF_HIT_LOCATION
    'NetAudioTaunts'  = $Env:NOLF_AUDIO_TAUNTS
    'NetFragScore'    = $Env:NOLF_FRAG_SCORE
    'NetFriendlyFire' = $Env:NOLF_FRIENDLY_FIRE
}
foreach ($s in $flags.GetEnumerator()) {
    if ($s.Value) { Set-Number $s.Key (ConvertTo-Flag $s.Value) }
}

# Level ending: 0 = score/frag limit, 1 = time limit, 2 = either, 3 = never. Deathmatch uses
# NetDMGameEnd + NetEndFrags, H.A.R.M. vs. UNITY NetCAGameEnd + NetEndScore; both use NetEndTime.
$limitVar = if ($isHarm) { $Env:NOLF_SCORE_LIMIT } else { $Env:NOLF_FRAG_LIMIT }
if ($limitVar -or $Env:NOLF_TIME_LIMIT) {
    $limit = if ($limitVar) { [int]$limitVar } else { 0 }
    $time  = if ($Env:NOLF_TIME_LIMIT) { [int]$Env:NOLF_TIME_LIMIT } else { 0 }

    if ($limit -gt 0) { Set-Number $(if ($isHarm) { 'NetEndScore' } else { 'NetEndFrags' }) $limit }
    if ($time -gt 0)  { Set-Number 'NetEndTime' $time }

    $end = if ($limit -gt 0 -and $time -gt 0) { 2 } elseif ($limit -gt 0) { 0 } elseif ($time -gt 0) { 1 } else { 3 }
    Set-Number $(if ($isHarm) { 'NetCAGameEnd' } else { 'NetDMGameEnd' }) $end
}

# Replace the rotation for this game type
$countKey = if ($isHarm) { 'NetCANumLevels' } else { 'NetNumLevels' }
$levelKey = if ($isHarm) { 'NetCALevel' } else { 'NetLevel' }

foreach ($key in @($settings.Keys)) {
    if ($key -match "^$levelKey\d+$") { $settings.Remove($key) }
}

Set-Number $countKey $levels.Count
for ($i = 0; $i -lt $levels.Count; $i++) {
    $settings["$levelKey$i"] = Format-String "Worlds\Multi\$typeDir\$($levels[$i])"
}

$lines = @('[Host]') + @(foreach ($s in $settings.GetEnumerator()) { "$($s.Key) = $($s.Value)" })

[System.IO.File]::WriteAllText($hostPath, ($lines -join "`r`n") + "`r`n")
chown "$($Env:UID):$($Env:GID)" $hostPath

Write-Log "Applied NOLF_* settings to NetHost.txt ($(if ($isHarm) { 'H.A.R.M. vs. UNITY' } else { 'Deathmatch' }), $($levels.Count) levels: $($levels -join ', '))"
