#Requires -Modules Logging

# Write the JK_* settings into registry.json in the game folder. OpenJKDF2 keeps its "registry" in
# that JSON file, and the dedicated server (-dedicatedServer) takes all of its settings from it:
# the same keys the game's Host Game menu saves. The file is edited through the merged view, so
# the edited copy lands in Overlay/ and can be changed there; keys without a non-empty JK_*
# setting keep their value.
#
# The server rewrites registry.json itself when it starts, so the file can show slightly
# different flag values afterwards.

$exeName = if ($Env:JK_EXE) { $Env:JK_EXE } else { 'openjkdf2-64.exe' }
$file    = Join-Path $Env:SERVER_ROOT 'registry.json'

if (-not (Test-Path -Path (Join-Path $Env:SERVER_ROOT $exeName))) {
    Write-Log -Level Error "$exeName not found in $Env:SERVER_ROOT; skipping server configuration"
    return
}

$registry = [ordered]@{}
if (Test-Path -Path $file) {
    $json = Get-Content -Raw -Path $file
    if ($json.Trim()) {
        $registry = $json | ConvertFrom-Json -AsHashtable
    }
}

function Get-Flag([string] $Value) {
    $Value -match '^(1|true|yes|on)$'
}

function Get-Int([string] $Name, [string] $Value, [int] $Min, [int] $Max) {
    $n = 0
    if (-not [int]::TryParse($Value, [ref] $n)) { throw "$Name must be a number, not '$Value'" }
    [Math]::Min([Math]::Max($n, $Min), $Max)
}

# Session and game flag bits (types_enums.h)
$SESSIONFLAG_PASSWORD     = 0x400
$MULTIMODEFLAG_TEAMS      = 0x103  # TEAMS | 0x2 | 0x100, what the Host Game menu sets
$MULTIMODEFLAG_TIMELIMIT  = 0x8
$MULTIMODEFLAG_SCORELIMIT = 0x10

$gameFlags    = [int]($registry['gameFlags'] ?? 0)
$sessionFlags = [int]($registry['sessionFlags'] ?? 0)

# The server is headless and dedicated; the window settings only matter for the hidden window
# it creates while starting
$registry['bIsDedicated']        = $true
$registry['Window_isFullscreen'] = $false

if ($Env:JK_PORT)        { $registry['portNum']          = Get-Int 'JK_PORT' $Env:JK_PORT 1 65535 }
if ($Env:JK_SERVER_NAME) { $registry['gameName']         = $Env:JK_SERVER_NAME }
if ($Env:JK_EPISODE)     { $registry['serverEpisodeGob'] = $Env:JK_EPISODE }
if ($Env:JK_MAP)         { $registry['serverMapJkl']     = $Env:JK_MAP }
if ($Env:JK_TICK_RATE)   { $registry['tickRate']         = Get-Int 'JK_TICK_RATE' $Env:JK_TICK_RATE 1 1000 }
if ($Env:JK_MAX_RANK)    { $registry['maxRank']          = Get-Int 'JK_MAX_RANK' $Env:JK_MAX_RANK 0 8 }

# With bIsDedicated set, the game adds a slot for the server's own (invisible) player, so this is
# the number of real players. The Host Game menu allows 1-30 for a dedicated server.
if ($Env:JK_MAX_PLAYERS) { $registry['maxPlayers'] = Get-Int 'JK_MAX_PLAYERS' $Env:JK_MAX_PLAYERS 1 30 }

# 0 turns a limit off. The time limit is stored in milliseconds.
if ($Env:JK_SCORE_LIMIT) {
    $score = Get-Int 'JK_SCORE_LIMIT' $Env:JK_SCORE_LIMIT 0 999
    $registry['bUseScoreLimit'] = $score -gt 0
    if ($score -gt 0) { $registry['scoreLimit'] = $score }
}

if ($Env:JK_TIME_LIMIT) {
    $minutes = Get-Int 'JK_TIME_LIMIT' $Env:JK_TIME_LIMIT 0 100
    $registry['bUseTimeLimit'] = $minutes -gt 0
    if ($minutes -gt 0) { $registry['timeLimit'] = $minutes * 60000 }
}

if ($Env:JK_TEAMS)        { $registry['bIsTeams']       = Get-Flag $Env:JK_TEAMS }
if ($Env:JK_SINGLE_LEVEL) { $registry['bIsSingleLevel'] = Get-Flag $Env:JK_SINGLE_LEVEL }

# The game only syncs the bIs*/bUse* booleans into gameFlags bit by bit, and teams needs two more
# bits than bIsTeams covers, so keep gameFlags consistent here
foreach ($f in @(
    @{ Key = 'bIsTeams';       Bits = $MULTIMODEFLAG_TEAMS },
    @{ Key = 'bUseTimeLimit';  Bits = $MULTIMODEFLAG_TIMELIMIT },
    @{ Key = 'bUseScoreLimit'; Bits = $MULTIMODEFLAG_SCORELIMIT }
)) {
    if ($registry.Contains($f.Key)) {
        if ($registry[$f.Key]) { $gameFlags = $gameFlags -bor $f.Bits } else { $gameFlags = $gameFlags -band -bnot $f.Bits }
    }
}
$registry['gameFlags'] = $gameFlags

# The password flag is never cleared by the game once saved, so set it from the password here.
# An empty JK_PASSWORD clears the password.
$registry['serverPassword'] = [string]$Env:JK_PASSWORD
if ($registry['serverPassword']) {
    $sessionFlags = $sessionFlags -bor $SESSIONFLAG_PASSWORD
} else {
    $sessionFlags = $sessionFlags -band -bnot $SESSIONFLAG_PASSWORD
}
$registry['sessionFlags'] = $sessionFlags

[System.IO.File]::WriteAllText($file, ($registry | ConvertTo-Json -Depth 5) + "`n")
chown "$($Env:UID):$($Env:GID)" $file

Write-Log "Applied JK_* settings to registry.json: $($registry['serverEpisodeGob']) $($registry['serverMapJkl']) on port $($registry['portNum'])"
