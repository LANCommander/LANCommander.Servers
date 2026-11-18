#Requires -Modules Logging

# Writes the ICELAKES_* environment variables into the [Server] section of server.cfg.
# Unset/empty variables leave the existing value alone. The file is edited through the
# merged view, so the first change copies it into Overlay/ and SteamCMD updates (which
# restore the stock Server/server.cfg) don't undo it. The map rotation ([MapN] sections)
# is never touched: overlay your own server.cfg to change it.

$settings = [ordered]@{
    Name              = $Env:ICELAKES_SERVER_NAME
    MaxPlayers        = $Env:ICELAKES_MAX_PLAYERS
    Port              = $Env:ICELAKES_PORT
    OutPort           = $Env:ICELAKES_QUERY_PORT
    Password          = $Env:ICELAKES_PASSWORD
    AdminPassword     = $Env:ICELAKES_ADMIN_PASSWORD
    FishNotifications = $Env:ICELAKES_FISH_NOTIFICATIONS
    FishFight         = $Env:ICELAKES_FISH_FIGHT
    BattleRoyale      = $Env:ICELAKES_BATTLE_ROYALE
}

$wanted = [ordered]@{}
foreach ($key in $settings.Keys) {
    if (-not [string]::IsNullOrEmpty($settings[$key])) {
        $wanted[$key] = $settings[$key]
    }
}

if ($wanted.Count -eq 0) {
    return
}

$configPath = Join-Path $Env:SERVER_ROOT "server.cfg"

if (-not (Test-Path -LiteralPath $configPath)) {
    throw "server.cfg not found at $configPath. Is the game installed?"
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.AddRange([string[]](Get-Content -LiteralPath $configPath))

$sectionStart = -1
$sectionEnd = $lines.Count

for ($i = 0; $i -lt $lines.Count; $i++) {
    $trimmed = $lines[$i].Trim()
    if ($trimmed -match '^\[(.+)\]$') {
        if ($sectionStart -ge 0) {
            $sectionEnd = $i
            break
        }
        if ($Matches[1] -eq 'Server') {
            $sectionStart = $i
        }
    }
}

if ($sectionStart -lt 0) {
    $lines.Insert(0, "[Server]")
    $lines.Insert(1, "")
    $sectionStart = 0
    $sectionEnd = 1
}

$changed = $false

foreach ($key in $wanted.Keys) {
    $value = $wanted[$key]
    $newLine = "$key=$value"
    $found = $false

    for ($i = $sectionStart + 1; $i -lt $sectionEnd; $i++) {
        if ($lines[$i] -match "^\s*$([regex]::Escape($key))\s*=") {
            $found = $true
            if ($lines[$i] -ne $newLine) {
                $lines[$i] = $newLine
                $changed = $true
            }
            break
        }
    }

    if (-not $found) {
        # Insert after the last non-blank line of the section
        $insertAt = $sectionEnd
        while ($insertAt -gt $sectionStart + 1 -and [string]::IsNullOrWhiteSpace($lines[$insertAt - 1])) {
            $insertAt--
        }
        $lines.Insert($insertAt, $newLine)
        $sectionEnd++
        $changed = $true
    }

    $shown = if ($key -match 'Password') { '********' } else { $value }
    Write-Log "server.cfg [Server] $key=$shown"
}

if (-not $changed) {
    Write-Log "server.cfg is up to date"
    return
}

# Keep the stock file's Windows line endings
[System.IO.File]::WriteAllText($configPath, ($lines -join "`r`n") + "`r`n")

if ((id -u) -eq "0") {
    chown "${Env:USER}:${Env:GROUP}" $configPath
    if ($LASTEXITCODE -ne 0) { throw "Failed to set ownership of $configPath" }
}

Write-Log "Updated $configPath"
