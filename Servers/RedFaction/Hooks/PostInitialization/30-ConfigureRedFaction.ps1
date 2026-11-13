#Requires -Modules Logging

# Create <RF_CONFIG>.toml (the Alpine Faction dedicated server config) from the image's default
# if it doesn't exist, then write the RF_* settings into its top-level keys. Top-level keys are
# the ones before the first [table] header; a key that isn't there yet is added just above it.
# The file is edited through the merged view, so it lands in Overlay/ and can be changed there;
# keys without an RF_* setting are never touched.

$file = Join-Path $Env:SERVER_ROOT "$($Env:RF_CONFIG).toml"

if (-not (Test-Path -Path $file)) {
    Copy-Item -Path '/usr/local/share/redfaction/server.toml' -Destination $file
    Write-Log "Created $($Env:RF_CONFIG).toml from the default config"
}

$text    = [System.IO.File]::ReadAllText($file)
$newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
$lines   = [System.Collections.Generic.List[string]]::new([string[]]($text -split "\r?\n"))

function ConvertTo-TomlString([string] $Value) { '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"' }

if ($Env:RF_MAX_PLAYERS -and $Env:RF_MAX_PLAYERS -notmatch '^\d+$') {
    Write-Log -Level Error "RF_MAX_PLAYERS must be a number; ignoring '$Env:RF_MAX_PLAYERS'"
    $Env:RF_MAX_PLAYERS = ''
}

$settings = @(
    @('server_name',   $(if ($Env:RF_SERVER_NAME)   { ConvertTo-TomlString $Env:RF_SERVER_NAME })),
    @('max_players',   $Env:RF_MAX_PLAYERS),
    @('password',      $(if ($Env:RF_PASSWORD)      { ConvertTo-TomlString $Env:RF_PASSWORD })),
    @('rcon_password', $(if ($Env:RF_RCON_PASSWORD) { ConvertTo-TomlString $Env:RF_RCON_PASSWORD }))
)

foreach ($s in $settings) {
    if (-not $s[1]) { continue }

    $firstTable = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\[') { $firstTable = $i; break }
    }

    $line  = "$($s[0]) = $($s[1])"
    $found = $false

    for ($i = 0; $i -lt $firstTable; $i++) {
        if ($lines[$i] -match "^\s*$([regex]::Escape($s[0]))\s*=") {
            $lines[$i] = $line
            $found = $true
            break
        }
    }

    if (-not $found) { $lines.Insert($firstTable, $line) }
}

[System.IO.File]::WriteAllText($file, ($lines -join $newline))
chown "$($Env:UID):$($Env:GID)" $file

Write-Log "Applied RF_* settings to $($Env:RF_CONFIG).toml"
