#Requires -Modules Logging

# Write eula.txt, the MINECRAFT_* settings into server.properties and MINECRAFT_OPS into ops.json.
#
#   - server.properties keeps every line it already has; the MINECRAFT_* settings (and the
#     MINECRAFT_PROPERTIES lines) replace or add their keys on every start. Empty settings leave
#     the key alone, so the rest of the file can be edited in Overlay/
#   - MINECRAFT_OPS: whitespace/comma-separated player names made level 4 operators. In offline
#     mode the UUID is the one the server derives from the name ("OfflinePlayer:<name>"); in
#     online mode the name is looked up when the player is opped by the server instead, so names
#     are only written here in offline mode

$root = $Env:SERVER_ROOT

function ConvertTo-Bool([string] $Value) {
    if (-not $Value) { return $null }
    if ($Value -in 'true', '1', 'yes') { 'true' } elseif ($Value -in 'false', '0', 'no') { 'false' } else { $Value }
}

function Set-OwnedFile([string] $Path, [string] $Content) {
    [System.IO.File]::WriteAllText($Path, $Content)
    # Not -R: a recursive chown through Merged/ would copy every file up into Overlay/
    chown "$($Env:UID):$($Env:GID)" $Path
}

# ---- EULA -----------------------------------------------------------------------------------
$eula = (ConvertTo-Bool $Env:MINECRAFT_EULA) -eq 'true'
Set-OwnedFile (Join-Path $root 'eula.txt') "# Set from MINECRAFT_EULA (https://aka.ms/MinecraftEULA)`neula=$($eula.ToString().ToLowerInvariant())`n"
if (-not $eula) {
    Write-Log -Level Error "MINECRAFT_EULA isn't true; the server won't start until you accept the Minecraft EULA (https://aka.ms/MinecraftEULA) with MINECRAFT_EULA=true"
}

# ---- server.properties ------------------------------------------------------------------------
$settings = [ordered]@{
    'server-port'            = $Env:MINECRAFT_PORT
    'query.port'             = $Env:MINECRAFT_PORT
    'online-mode'            = ConvertTo-Bool $Env:MINECRAFT_ONLINE_MODE
    'enforce-secure-profile' = ConvertTo-Bool $Env:MINECRAFT_ENFORCE_SECURE_PROFILE
    'motd'                   = $Env:MINECRAFT_MOTD
    'max-players'            = $Env:MINECRAFT_MAX_PLAYERS
    'level-name'             = $Env:MINECRAFT_LEVEL_NAME
    'level-type'             = $Env:MINECRAFT_LEVEL_TYPE
    'gamemode'               = $Env:MINECRAFT_GAMEMODE
    'difficulty'             = $Env:MINECRAFT_DIFFICULTY
    'pvp'                    = ConvertTo-Bool $Env:MINECRAFT_PVP
    'spawn-protection'       = $Env:MINECRAFT_SPAWN_PROTECTION
    'view-distance'          = $Env:MINECRAFT_VIEW_DISTANCE
    'allow-nether'           = ConvertTo-Bool $Env:MINECRAFT_ALLOW_NETHER
}

if ($Env:MINECRAFT_RCON_PASSWORD) {
    $settings['enable-rcon'] = 'true'
    $settings['rcon.port'] = $Env:MINECRAFT_RCON_PORT
    $settings['rcon.password'] = $Env:MINECRAFT_RCON_PASSWORD
} else {
    $settings['enable-rcon'] = 'false'
}

foreach ($line in ("$Env:MINECRAFT_PROPERTIES" -split '[\r\n;]+')) {
    if ($line -match '^\s*([^=#\s][^=]*?)\s*=(.*)$') { $settings[$Matches[1]] = $Matches[2].Trim() }
}

# server.properties is a Java properties file: escape what Java would
function ConvertTo-PropertyValue([string] $Value) {
    $sb = [System.Text.StringBuilder]::new()
    foreach ($c in $Value.ToCharArray()) {
        switch ($c) {
            '\' { [void]$sb.Append('\\') }
            ':' { [void]$sb.Append('\:') }
            '=' { [void]$sb.Append('\=') }
            default { if ([int]$c -gt 126) { [void]$sb.Append(('\u{0:x4}' -f [int]$c)) } else { [void]$sb.Append($c) } }
        }
    }
    $sb.ToString()
}

$propertiesFile = Join-Path $root 'server.properties'
$lines = [System.Collections.Generic.List[string]]::new()
if (Test-Path -Path $propertiesFile) { $lines.AddRange([string[]](Get-Content -Path $propertiesFile)) }

foreach ($key in $settings.Keys) {
    $value = $settings[$key]
    if ($null -eq $value -or $value -eq '') { continue }
    $entry = "$key=$(ConvertTo-PropertyValue $value)"
    $index = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^\s*$([regex]::Escape($key))\s*=") { $index = $i; break }
    }
    if ($index -ge 0) { $lines[$index] = $entry } else { $lines.Add($entry) }
}

Set-OwnedFile $propertiesFile (($lines -join "`n") + "`n")
Write-Log "Wrote the MINECRAFT_* settings to $propertiesFile"

# ---- Operators ----------------------------------------------------------------------------------
function Get-OfflineUuid([string] $Name) {
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $bytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes("OfflinePlayer:$Name"))
    $bytes[6] = ($bytes[6] -band 0x0f) -bor 0x30
    $bytes[8] = ($bytes[8] -band 0x3f) -bor 0x80
    $hex = ($bytes | ForEach-Object { $_.ToString('x2') }) -join ''
    '{0}-{1}-{2}-{3}-{4}' -f $hex.Substring(0, 8), $hex.Substring(8, 4), $hex.Substring(12, 4), $hex.Substring(16, 4), $hex.Substring(20)
}

$ops = @("$Env:MINECRAFT_OPS" -split '[\s,;]+' | Where-Object { $_ })
if ($ops) {
    if ((ConvertTo-Bool $Env:MINECRAFT_ONLINE_MODE) -eq 'true') {
        Write-Log -Level Warning "MINECRAFT_OPS is only applied in offline mode; op players with the console 'op <name>' command instead"
    } else {
        $opsFile = Join-Path $root 'ops.json'
        $list = [System.Collections.Generic.List[object]]::new()
        if (Test-Path -Path $opsFile) {
            try { foreach ($o in @(Get-Content -Path $opsFile -Raw | ConvertFrom-Json)) { if ($o) { $list.Add($o) } } } catch { Write-Log -Level Warning "Could not read $opsFile; rewriting it" }
        }
        foreach ($name in $ops) {
            if (-not ($list | Where-Object { $_.name -eq $name })) {
                $list.Add([ordered]@{ uuid = (Get-OfflineUuid $name); name = $name; level = 4; bypassesPlayerLimit = $false })
            }
        }
        Set-OwnedFile $opsFile (ConvertTo-Json -InputObject @($list) -Depth 3)
        Write-Log "Operators: $($ops -join ', ')"
    }
}
