#Requires -Modules Logging

# Writes settings from the environment into the server's .ini
# (<PZ_CACHE_DIR>/Server/<PZ_SERVER_NAME>.ini) before it starts.
#
#   - The named PZ_* variables below map to their .ini keys.
#   - Any PZ_INI_<Key> variable sets <Key> as is, e.g. PZ_INI_SafehouseAllowLoot=false.
#
# Empty variables leave the existing value alone. On a first start the file doesn't exist yet;
# it is created with just these keys and the server fills in every other option with its
# default and rewrites the file.

$serverName = if ($Env:PZ_SERVER_NAME) { $Env:PZ_SERVER_NAME } else { "servertest" }
$cacheDir = if ($Env:PZ_CACHE_DIR) { $Env:PZ_CACHE_DIR } else { "/config/Zomboid" }

$named = [ordered]@{
    PublicName        = $Env:PZ_PUBLIC_NAME
    PublicDescription = $Env:PZ_PUBLIC_DESCRIPTION
    MaxPlayers        = $Env:PZ_MAX_PLAYERS
    Password          = $Env:PZ_PASSWORD
    DefaultPort       = $Env:PZ_PORT
    UDPPort           = $Env:PZ_UDP_PORT
    RCONPort          = $Env:PZ_RCON_PORT
    RCONPassword      = $Env:PZ_RCON_PASSWORD
    Public            = $Env:PZ_PUBLIC
    PVP               = $Env:PZ_PVP
    PauseEmpty        = $Env:PZ_PAUSE_EMPTY
    Map               = $Env:PZ_MAP
    Mods              = $Env:PZ_MODS
    WorkshopItems     = $Env:PZ_WORKSHOP_ITEMS
}

$wanted = [ordered]@{}
foreach ($key in $named.Keys) {
    if (-not [string]::IsNullOrEmpty($named[$key])) { $wanted[$key] = $named[$key] }
}
foreach ($item in (Get-ChildItem Env: | Where-Object Name -like 'PZ_INI_*' | Sort-Object Name)) {
    $key = $item.Name.Substring(7)
    if ($key -and -not [string]::IsNullOrEmpty($item.Value)) { $wanted[$key] = $item.Value }
}

$serverDir = Join-Path $cacheDir "Server"
$iniPath = Join-Path $serverDir "$serverName.ini"
New-Item -ItemType Directory -Path $serverDir -Force | Out-Null

if ((id -u) -eq "0") {
    chown "${Env:USER}:${Env:GROUP}" $cacheDir $serverDir
    if ($LASTEXITCODE -ne 0) { throw "Failed to set ownership of $serverDir" }
}

if ($wanted.Count -eq 0) {
    return
}

$lines = [System.Collections.Generic.List[string]]::new()
if (Test-Path -LiteralPath $iniPath) {
    $lines.AddRange([string[]](Get-Content -LiteralPath $iniPath))
}

$changed = $false
foreach ($key in $wanted.Keys) {
    $newLine = "$key=$($wanted[$key])"
    $index = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^$([regex]::Escape($key))=") { $index = $i; break }
    }

    if ($index -ge 0) {
        if ($lines[$index] -cne $newLine) { $lines[$index] = $newLine; $changed = $true }
    } else {
        $lines.Add($newLine)
        $changed = $true
    }

    $shown = if ($key -match 'Password') { '********' } else { $wanted[$key] }
    Write-Log "$serverName.ini $key=$shown"
}

if ($changed) {
    [System.IO.File]::WriteAllText($iniPath, ($lines -join "`n") + "`n")
    Write-Log "Updated $iniPath"
} else {
    Write-Log "$iniPath is up to date"
}

if ((id -u) -eq "0") {
    chown "${Env:USER}:${Env:GROUP}" $iniPath
    if ($LASTEXITCODE -ne 0) { throw "Failed to set ownership of $iniPath" }
}
