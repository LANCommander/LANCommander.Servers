#Requires -Modules Logging

# LANCommander match statistics. Alpine Faction reports its games to FactionFiles
# (https://link.factionfiles.com/afstats/v1/) when its config has an fflink_gsk; the image's
# rf-stats-bridge answers in FactionFiles' place and reports them to LANCommander instead.
# When the match statistics are on, this:
#
#   - resolves link.factionfiles.com to 127.0.0.1 in /etc/hosts
#   - makes a certificate authority and a link.factionfiles.com certificate for the bridge, in
#     /config/.rf-stats-bridge/ (kept, so Wine's copy of the root store stays the same), and adds
#     the authority to the container's trusted roots, which Wine reads
#   - writes an fflink_gsk into <RF_CONFIG>.toml if it has none; FactionFiles never sees it
#   - with MATCH_STATS_DEMOS on, writes demo_auto_record = true if the config doesn't set it, so
#     each level is recorded and the demo uploaded to the bridge, which attaches it to the match
#   - flags rf-server to start the bridge before the game
#
# Turned off, the keys this wrote are taken out again. Ones that were there before are kept.

$marker  = '# LANCommander match statistics (MATCH_STATS_*)'
$certDir = Join-Path $Env:CONFIG_DIR '.rf-stats-bridge'
$flag    = '/etc/rf-stats-bridge/enabled'
$host_   = 'link.factionfiles.com'

function ConvertTo-Bool([string] $Value) {
    switch ($Value.Trim().ToLowerInvariant()) {
        { $_ -in 'true', '1', 'yes', 'on' }   { return $true }
        { $_ -in 'false', '0', 'no', 'off' } { return $false }
        default                              { return $null }
    }
}

$enabled = ConvertTo-Bool "$Env:MATCH_STATS_ENABLED"
if ($null -eq $enabled) { $enabled = [bool]($Env:MATCH_STATS_SERVER_URL -and $Env:MATCH_STATS_TOKEN) }

$demos = ConvertTo-Bool "$Env:MATCH_STATS_DEMOS"
if ($null -eq $demos) { $demos = $true }
$demos = $enabled -and $demos

$config = Join-Path $Env:SERVER_ROOT "$($Env:RF_CONFIG).toml"

Remove-Item -Force -Path $flag -ErrorAction SilentlyContinue

# ---- fflink_gsk and demo_auto_record in <RF_CONFIG>.toml (top-level keys come before the first [table]) ----
if (Test-Path -LiteralPath $config) {
    $text    = [System.IO.File]::ReadAllText($config)
    $newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lines   = [System.Collections.Generic.List[string]]::new([string[]]($text -split "\r?\n"))
    $changed = $false

    # Adds `key = value` (marked) when wanted and the config doesn't set the key; takes the
    # marked line out again when not wanted. True when it changed something
    function Set-MarkedKey([string] $Key, [bool] $Want, [string] $Value) {
        $firstTable = $lines.Count
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*\[') { $firstTable = $i; break }
        }

        $line = -1
        for ($i = 0; $i -lt $firstTable; $i++) {
            if ($lines[$i] -match "^\s*$([regex]::Escape($Key))\s*=") { $line = $i; break }
        }

        if ($Want -and $line -lt 0) {
            $lines.Insert($firstTable, "$Key = $Value   $marker")
            return $true
        }
        if (-not $Want -and $line -ge 0 -and $lines[$line].Contains($marker)) {
            $lines.RemoveAt($line)
            return $true
        }
        return $false
    }

    $gsk = -join (1..32 | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
    if (Set-MarkedKey 'fflink_gsk' $enabled "`"$gsk`"") { $changed = $true }
    if (Set-MarkedKey 'demo_auto_record' $demos 'true') { $changed = $true }

    if ($changed) {
        [System.IO.File]::WriteAllText($config, ($lines -join $newline))
        chown "$($Env:UID):$($Env:GID)" $config
    }
}

if (-not $enabled) {
    # A restarted container keeps its /etc/hosts
    $hosts = Get-Content -Path '/etc/hosts' -ErrorAction SilentlyContinue
    if ($hosts -match "\b$([regex]::Escape($host_))\b") {
        Set-Content -Path '/etc/hosts' -Value ($hosts | Where-Object { $_ -notmatch "\b$([regex]::Escape($host_))\b" })
    }

    Write-Log "LANCommander match statistics are off (set MATCH_STATS_SERVER_URL and MATCH_STATS_TOKEN)"
    return
}

# ---- The certificate authority and the bridge's certificate ----
$caKey   = Join-Path $certDir 'ca.key'
$caCrt   = Join-Path $certDir 'ca.crt'
$srvKey  = Join-Path $certDir 'server.key'
$srvCrt  = Join-Path $certDir 'server.crt'

New-Item -ItemType Directory -Force -Path $certDir | Out-Null

if (-not (Test-Path $caKey) -or -not (Test-Path $caCrt)) {
    openssl req -x509 -newkey rsa:2048 -nodes -days 7300 -subj '/CN=LANCommander Red Faction stats bridge' `
        -addext 'basicConstraints=critical,CA:TRUE' -addext 'keyUsage=critical,keyCertSign,cRLSign' `
        -keyout $caKey -out $caCrt 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the stats bridge certificate authority' }
    Remove-Item -Force -Path $srvCrt -ErrorAction SilentlyContinue
}

if (-not (Test-Path $srvKey) -or -not (Test-Path $srvCrt)) {
    $csr = Join-Path $certDir 'server.csr'
    $ext = Join-Path $certDir 'server.ext'
    Set-Content -Path $ext -Value "subjectAltName=DNS:$host_`nextendedKeyUsage=serverAuth`nbasicConstraints=CA:FALSE"
    openssl req -newkey rsa:2048 -nodes -subj "/CN=$host_" -keyout $srvKey -out $csr 2>&1 | Out-Null
    openssl x509 -req -in $csr -CA $caCrt -CAkey $caKey -CAcreateserial -days 3650 -out $srvCrt -extfile $ext 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the stats bridge certificate' }
    Remove-Item -Force -Path $csr, $ext
}

chown -R "$($Env:UID):$($Env:GID)" $certDir
chmod 700 $certDir

# Wine builds its root store from the container's trusted roots
Copy-Item -Force -Path $caCrt -Destination '/usr/local/share/ca-certificates/rf-stats-bridge.crt'
update-ca-certificates 2>&1 | Out-Null

# ---- link.factionfiles.com -> the bridge ----
$hosts = Get-Content -Path '/etc/hosts' -ErrorAction SilentlyContinue
if (-not ($hosts | Where-Object { $_ -match "^\s*127\.0\.0\.1\s+.*\b$([regex]::Escape($host_))\b" })) {
    Add-Content -Path '/etc/hosts' -Value "127.0.0.1 $host_"
}

New-Item -ItemType Directory -Force -Path (Split-Path $flag) | Out-Null
Set-Content -Path $flag -Value 'enabled'

$demoDir = Join-Path $certDir 'demos'
if ($demos) {
    New-Item -ItemType Directory -Force -Path $demoDir | Out-Null
    chown "$($Env:UID):$($Env:GID)" $demoDir
    Set-Content -Path '/etc/rf-stats-bridge/demos' -Value $demoDir
} else {
    Remove-Item -Force -Path '/etc/rf-stats-bridge/demos' -ErrorAction SilentlyContinue
}

$target = if ($Env:MATCH_STATS_SERVER_URL) { $Env:MATCH_STATS_SERVER_URL } else { 'nowhere (MATCH_STATS_SERVER_URL is empty)' }
Write-Log "LANCommander match statistics are on: Alpine Faction's stats$(if ($demos) { ' and demos' }) go to $target"
