#Requires -Modules Logging

# FLServer has no command-line or text config. On first run it shows a EULA and then a modal
# "Server Configuration" dialog, which it saves to My Games\Freelancer\Accts\MultiPlayer\FLServer.cfg.
# With a saved FLServer.cfg and the EULA accepted, `FLServer.exe /c` starts hosting straight away.
# This hook does both, from the FL_* variables, on every start.

$runAs = "$($Env:UID):$($Env:GID)"

# --- EULA: accepting it sets HKCU\...\Freelancer\1.0 FIRSTRUN=1 ---
$userReg = Join-Path $Env:WINEPREFIX 'user.reg'
if (-not (Select-String -Path $userReg -Pattern 'Microsoft Games\\\\Freelancer\\\\1\.0' -Quiet)) {
    Write-Log "Accepting the Freelancer server EULA"
    & gosu $runAs wine reg add 'HKCU\Software\Microsoft\Microsoft Games\Freelancer\1.0' /v FIRSTRUN /t REG_DWORD /d 1 /f | Out-Null
    $exitCode = $LASTEXITCODE
    & gosu $runAs wineserver --wait
    if ($exitCode -ne 0) { throw "Could not set FIRSTRUN in the Wine registry (exit code $exitCode)" }
}

# --- FLServer.cfg ---
# 369 bytes, written straight from the dialog's data:
#   0x000 int32   3 (version)
#   0x004 wchar   name[33]
#   0x046 wchar   description[129]
#   0x148 wchar   password[17]
#   0x16A byte    allow new players
#   0x16B byte    make server internet accessible
#   0x16C int32   max players
#   0x170 byte    allow players to harm other players (PvP)

function Test-True([string] $Value) {
    return $Value -match '^(1|true|yes|on)$'
}

function Write-WString([byte[]] $Buffer, [int] $Offset, [int] $Chars, [string] $Value) {
    if ($Value.Length -ge $Chars) {
        Write-Log -Level Warning "'$Value' is longer than $($Chars - 1) characters and will be cut off"
        $Value = $Value.Substring(0, $Chars - 1)
    }
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($Value)
    [Array]::Copy($bytes, 0, $Buffer, $Offset, $bytes.Length)
}

$maxPlayers = 16
if (-not [int]::TryParse($Env:FL_MAX_PLAYERS, [ref] $maxPlayers) -or $maxPlayers -lt 1 -or $maxPlayers -gt 128) {
    Write-Log -Level Warning "FL_MAX_PLAYERS '$Env:FL_MAX_PLAYERS' is not a number from 1 to 128, using 16"
    $maxPlayers = 16
}

$cfg = [byte[]]::new(0x171)
[BitConverter]::GetBytes([int32] 3).CopyTo($cfg, 0x000)
Write-WString $cfg 0x004 33  "$Env:FL_SERVER_NAME"
Write-WString $cfg 0x046 129 "$Env:FL_DESCRIPTION"
Write-WString $cfg 0x148 17  "$Env:FL_PASSWORD"
$cfg[0x16A] = [byte](Test-True $Env:FL_ALLOW_NEW_PLAYERS)
$cfg[0x16B] = [byte](Test-True $Env:FL_INTERNET)
[BitConverter]::GetBytes([int32] $maxPlayers).CopyTo($cfg, 0x16C)
$cfg[0x170] = [byte](Test-True $Env:FL_PVP)

# Wine names the profile folder after the user the server runs as
$user = (getent passwd $Env:UID) -split ':' | Select-Object -First 1
if (-not $user) { $user = $Env:USER }

$myGames = Join-Path $Env:WINEPREFIX "drive_c/users/$user/Documents/My Games/Freelancer"
$accounts = Join-Path $myGames 'Accts/MultiPlayer'
New-Item -ItemType Directory -Path $accounts -Force | Out-Null

$cfgPath = Join-Path $accounts 'FLServer.cfg'
[System.IO.File]::WriteAllBytes($cfgPath, $cfg)
chown -R $runAs $myGames

Write-Log "Wrote $cfgPath (name '$Env:FL_SERVER_NAME', $maxPlayers players, PvP $(Test-True $Env:FL_PVP))"
