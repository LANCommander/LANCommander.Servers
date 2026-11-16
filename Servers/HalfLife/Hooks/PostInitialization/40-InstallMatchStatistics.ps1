#Requires -Modules Logging

# LANCommander match statistics: install the Metamod plugin
# (https://github.com/LANCommander/LANCommander.MatchStatistics.MetaMod), so the matches played on
# the server are reported to LANCommander.
#
# Metamod-P and the plugin are built into the image, in /opt/lancommander-stats. When the match
# statistics are on, this writes into the game directory (-game in START_ARGS, or GAME_MOD) in
# Merged/, so into Overlay/:
#
#   addons/metamod/                 Metamod-P, unless liblist.gam already loads a Metamod: metamod.so,
#                                   config.ini (the game DLL it loads) and .lancommander (the
#                                   gamedll_linux it replaced)
#   liblist.gam                     gamedll_linux pointed at Metamod
#   addons/metamod/plugins.ini      The plugin's line
#   addons/metamod/exec.cfg         exec addons/lancommander/lancommander.cfg
#   addons/lancommander/dlls/       The plugin. Its .interposer/ folder keeps the logs and the reports
#                                   not delivered yet
#   addons/lancommander/lancommander.cfg
#                                   The MATCH_STATS_* settings as lc_* cvars. One that this hook didn't
#                                   write is left alone
#
# Turned off, all of it is undone. lancommander.cfg and .interposer/ are kept.

$header = '// Generated from the MATCH_STATS_* environment variables on every start'
$source = '/opt/lancommander-stats'
$metamodDll = 'addons/metamod/dlls/metamod.so'
$pluginLine = 'linux addons/lancommander/dlls/lancommander_mm_i386.so'
$execLine = 'exec addons/lancommander/lancommander.cfg'

function ConvertTo-Bool([string] $Value) {
    switch ($Value.Trim().ToLowerInvariant()) {
        { $_ -in 'true', '1', 'yes', 'on' }   { return '1' }
        { $_ -in 'false', '0', 'no', 'off' } { return '0' }
        default                              { return $null }
    }
}

function Get-Hash([string] $Path) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
}

function ConvertTo-Quoted([string] $Value) { '"' + $Value.Replace('"', '').Replace(';', '') + '"' }

function Write-Lines([string] $Path, [string[]] $Lines) {
    [System.IO.File]::WriteAllText($Path, (($Lines | Where-Object { $_ -ne $null }) -join "`n") + "`n")
}

# Lines of a text file, without the line endings
function Read-Lines([string] $Path) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) { @([System.IO.File]::ReadAllLines($Path)) } else { @() }
}

# Adds a line to a file once, or with -Remove takes it out (and deletes the file if nothing is left)
function Set-Line([string] $Path, [string] $Line, [switch] $Remove) {
    $lines = Read-Lines $Path
    $present = @($lines | Where-Object { $_.Trim() -eq $Line }).Count -gt 0

    if ($Remove) {
        if (-not $present) { return $false }
        $kept = @($lines | Where-Object { $_.Trim() -ne $Line })
        if (@($kept | Where-Object { $_.Trim() }).Count -eq 0) { Remove-Item -Force -LiteralPath $Path } else { Write-Lines $Path $kept }
        return $true
    }

    if ($present) { return $false }
    Write-Lines $Path ($lines + $Line)
    return $true
}

$enabled = switch (ConvertTo-Bool "$Env:MATCH_STATS_ENABLED") {
    '1'     { $true }
    '0'     { $false }
    default { [bool]($Env:MATCH_STATS_SERVER_URL -and $Env:MATCH_STATS_TOKEN) }
}

# The game directory HLDS runs: -game in START_ARGS (Natural Selection runs ns on GAME_MOD valve)
$gameDirName = if ("$Env:START_ARGS" -match '(?:^|\s)-game\s+"?([^\s"]+)') { $Matches[1] } else { $Env:GAME_MOD }

if (-not $gameDirName -or -not (Test-Path -LiteralPath "$source/addons/lancommander" -PathType Container)) {
    Write-Log -Level Error "The match statistics plugin is missing from $source, or the game directory (-game, GAME_MOD) is unknown"
    return
}

$gameDir = Join-Path $Env:SERVER_ROOT $gameDirName
$liblist = Join-Path $gameDir 'liblist.gam'
$metamodDir = Join-Path $gameDir 'addons/metamod'
$marker = Join-Path $metamodDir '.lancommander'
$pluginsIni = Join-Path $metamodDir 'plugins.ini'
$execCfg = Join-Path $metamodDir 'exec.cfg'
$configIni = Join-Path $metamodDir 'config.ini'
$configHeader = '// Written by the LANCommander image for the match statistics plugin'

$pluginFiles = Get-ChildItem -LiteralPath "$source/addons/lancommander" -Recurse -File | ForEach-Object {
    'addons/lancommander/' + [System.IO.Path]::GetRelativePath("$source/addons/lancommander", $_.FullName)
}

if (-not (Test-Path -LiteralPath $liblist -PathType Leaf)) {
    if ($enabled) { Write-Log -Level Error "$gameDirName/liblist.gam is missing, so the match statistics plugin can't be installed" }
    return
}

$liblistLines = Read-Lines $liblist
$gamedllPattern = '^\s*gamedll_linux\s+"?([^"\r\n]*?)"?\s*$'
$gamedll = ($liblistLines | Where-Object { $_ -match $gamedllPattern } | Select-Object -First 1) -replace $gamedllPattern, '$1'

function Set-Gamedll([string] $Value) {
    $lines = Read-Lines $liblist
    if (@($lines | Where-Object { $_ -match $gamedllPattern }).Count -gt 0) {
        $lines = $lines | ForEach-Object { if ($_ -match $gamedllPattern) { "gamedll_linux `"$Value`"" } else { $_ } }
    } else {
        $lines = @($lines) + "gamedll_linux `"$Value`""
    }
    Write-Lines $liblist $lines
}

if (-not $enabled) {
    $changed = $false

    foreach ($file in $pluginFiles) {
        $target = Join-Path $gameDir $file
        if (Test-Path -LiteralPath $target -PathType Leaf) { Remove-Item -Force -LiteralPath $target; $changed = $true }
    }
    if (Set-Line $pluginsIni $pluginLine -Remove) { $changed = $true }
    if (Set-Line $execCfg $execLine -Remove) { $changed = $true }

    # Metamod goes again if this hook installed it and no other plugin is left in plugins.ini
    if (Test-Path -LiteralPath $marker -PathType Leaf) {
        $others = @(Read-Lines $pluginsIni | Where-Object { $_.Trim() -and $_.Trim() -notmatch '^(;|//|#)' })
        if ($others.Count -eq 0) {
            Set-Gamedll (Get-Content -LiteralPath $marker -Raw).Trim()
            Remove-Item -Force -LiteralPath (Join-Path $gameDir $metamodDll), $marker
            if ("$(Get-Content -LiteralPath $configIni -TotalCount 1 -ErrorAction SilentlyContinue)" -eq $configHeader) {
                Remove-Item -Force -LiteralPath $configIni
            }
            foreach ($dir in (Join-Path $metamodDir 'dlls'), $metamodDir) {
                if (-not (Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue)) {
                    Remove-Item -Force -LiteralPath $dir -ErrorAction SilentlyContinue
                }
            }
            $changed = $true
        } else {
            Write-Log -Level Warning "Metamod is left in $gameDirName/addons/metamod: plugins.ini loads other plugins"
        }
    }

    if ($changed) { Write-Log "Match statistics are off; removed the plugin from $gameDirName/addons" }
    return
}

$owned = [System.Collections.Generic.HashSet[string]]::new()

function Copy-IfChanged([string] $From, [string] $To) {
    $dir = Split-Path -Parent $To
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [void]$owned.Add($dir)
    if ((Get-Hash $To) -ne (Get-Hash $From)) {
        Copy-Item -Force -LiteralPath $From -Destination $To
        [void]$owned.Add($To)
    }
}

# Metamod: kept if liblist.gam already loads one (AMX Mod X, ...), otherwise Metamod-P goes in front
# of the game DLL
if ($gamedll -notmatch '(^|/)addons/metamod/') {
    if (-not $gamedll) {
        Write-Log -Level Error "$gameDirName/liblist.gam names no gamedll_linux, so Metamod can't be installed in front of it"
        return
    }

    Write-Log "Installing Metamod-P in $gameDirName/addons/metamod in front of $gamedll"
    New-Item -ItemType Directory -Path $metamodDir -Force | Out-Null
    Set-Content -LiteralPath $marker -Value $gamedll -NoNewline
    [void]$owned.Add($marker)
    Set-Gamedll $metamodDll
    [void]$owned.Add($liblist)
    $gamedll = $metamodDll
}

if (Test-Path -LiteralPath $marker -PathType Leaf) {
    Copy-IfChanged "$source/$metamodDll" (Join-Path $gameDir $metamodDll)

    # The game DLL Metamod loads, so mods it doesn't know work too
    if (-not (Test-Path -LiteralPath $configIni) -or "$(Get-Content -LiteralPath $configIni -TotalCount 1)" -eq $configHeader) {
        Write-Lines $configIni @($configHeader, "gamedll $((Get-Content -LiteralPath $marker -Raw).Trim())")
        [void]$owned.Add($configIni)
    }
}

foreach ($file in $pluginFiles) {
    Copy-IfChanged (Join-Path $source $file) (Join-Path $gameDir $file)
}

if (Set-Line $pluginsIni $pluginLine) { [void]$owned.Add($pluginsIni) }
if (Set-Line $execCfg $execLine) { [void]$owned.Add($execCfg) }
[void]$owned.Add($metamodDir)

# Only settings that are set, so the others can come from server.cfg. The token stays in the
# environment: the plugin expands %MATCH_STATS_TOKEN% itself
$values = [ordered]@{
    'lc_enabled'       = '1'
    'lc_server_url'    = $(if ($Env:MATCH_STATS_SERVER_URL) { ConvertTo-Quoted $Env:MATCH_STATS_SERVER_URL.TrimEnd('/') })
    'lc_token'         = $(if ($Env:MATCH_STATS_TOKEN) { '"%MATCH_STATS_TOKEN%"' })
    'lc_game_id'       = $(if ($Env:MATCH_STATS_GAME_ID) { ConvertTo-Quoted $Env:MATCH_STATS_GAME_ID })
    'lc_server_id'     = $(if ($Env:MATCH_STATS_SERVER_ID) { ConvertTo-Quoted $Env:MATCH_STATS_SERVER_ID })
    'lc_reporter_name' = $(if ($Env:MATCH_STATS_REPORTER_NAME) { ConvertTo-Quoted $Env:MATCH_STATS_REPORTER_NAME })
    'lc_min_players'   = $Env:MATCH_STATS_MIN_PLAYERS
    'lc_mode'          = $(if ($Env:MATCH_STATS_MODE) { ConvertTo-Quoted $Env:MATCH_STATS_MODE })
    'lc_record_bots'   = $(if ($Env:MATCH_STATS_RECORD_BOTS) { ConvertTo-Bool $Env:MATCH_STATS_RECORD_BOTS })
    'lc_record_chat'   = $(if ($Env:MATCH_STATS_RECORD_CHAT) { ConvertTo-Bool $Env:MATCH_STATS_RECORD_CHAT })
}

$lines = @("$header. Settings left out keep their defaults; set them in server.cfg")
foreach ($key in $values.Keys) {
    if ($values[$key]) { $lines += "$key $($values[$key])" }
}

$cfg = Join-Path $gameDir 'addons/lancommander/lancommander.cfg'
if ((Test-Path -LiteralPath $cfg) -and -not "$(Get-Content -LiteralPath $cfg -TotalCount 1)".StartsWith($header)) {
    Write-Log -Level Warning "$gameDirName/addons/lancommander/lancommander.cfg wasn't written by this image and is left alone, so the MATCH_STATS_* settings aren't applied. Delete it to have it generated"
} else {
    Write-Lines $cfg $lines
    [void]$owned.Add($cfg)
}

# The server runs as UID:GID and the plugin writes .interposer/ next to itself. Not -R through
# Merged/, which would copy every file up into Overlay/
chown "$($Env:UID):$($Env:GID)" @($owned)

foreach ($setting in 'MATCH_STATS_SERVER_URL', 'MATCH_STATS_TOKEN', 'MATCH_STATS_GAME_ID') {
    if (-not [Environment]::GetEnvironmentVariable($setting)) {
        Write-Log -Level Warning "Match statistics are on, but $setting is empty; set it here or as lc_* in server.cfg"
    }
}

Write-Log "Match statistics are on: the LANCommander plugin is installed in $gameDirName/addons through Metamod"
