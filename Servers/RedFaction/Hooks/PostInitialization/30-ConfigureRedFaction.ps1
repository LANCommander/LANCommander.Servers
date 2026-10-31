#Requires -Modules Logging

# Write the RF_* settings into the RF_CONFIG block of dedicated_server.txt. A block starts at its
# `$Name: "<config>"` line and runs to the next `$Name:` or `#End`. The file is edited through the
# merged view, so the edited copy lands in Overlay/ and can be changed there; options without an
# RF_* setting are never touched.

$file = Join-Path $Env:SERVER_ROOT 'dedicated_server.txt'

if (-not (Test-Path -Path $file)) {
    Write-Log -Level Error "$file not found; skipping server configuration"
    return
}

$text    = [System.IO.File]::ReadAllText($file)
$newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
$lines   = [System.Collections.Generic.List[string]]::new([string[]]($text -split "\r?\n"))

$start = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*\$Name:\s*"?([^"]*)"?\s*$' -and $Matches[1].Trim() -eq $Env:RF_CONFIG) {
        $start = $i
        break
    }
}

if ($start -lt 0) {
    Write-Log -Level Error "No `$Name: `"$Env:RF_CONFIG`" game configuration in dedicated_server.txt; skipping server configuration"
    return
}

$end = $start + 1
while ($end -lt $lines.Count -and $lines[$end] -notmatch '^\s*(\$Name:|#End)') { $end++ }

function ConvertTo-Quoted([string] $Value) { '"' + $Value.Replace('"', '') + '"' }

$settings = @(
    @('Server Name',   $(if ($Env:RF_SERVER_NAME)   { ConvertTo-Quoted $Env:RF_SERVER_NAME })),
    @('Max Players',   $Env:RF_MAX_PLAYERS),
    @('Password',      $(if ($Env:RF_PASSWORD)      { ConvertTo-Quoted $Env:RF_PASSWORD })),
    @('Rcon Password', $(if ($Env:RF_RCON_PASSWORD) { ConvertTo-Quoted $Env:RF_RCON_PASSWORD }))
)

# Replace each option's line in the block, or add it after $Name:
foreach ($s in $settings) {
    if (-not $s[1]) { continue }

    $line  = "`$$($s[0]):`t`t$($s[1])"
    $found = $false

    for ($i = $start + 1; $i -lt $end; $i++) {
        if ($lines[$i] -match "^\s*\`$$([regex]::Escape($s[0])):") {
            $lines[$i] = $line
            $found = $true
            break
        }
    }

    if (-not $found) {
        $lines.Insert($start + 1, $line)
        $end++
    }
}

[System.IO.File]::WriteAllText($file, ($lines -join $newline))
chown "$($Env:UID):$($Env:GID)" $file

Write-Log "Applied RF_* settings to the '$Env:RF_CONFIG' configuration in dedicated_server.txt"
