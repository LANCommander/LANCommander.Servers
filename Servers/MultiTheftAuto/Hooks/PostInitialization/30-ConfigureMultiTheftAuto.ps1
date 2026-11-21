#Requires -Modules Logging

# Apply the MTA_* settings on every start. Everything is written through Merged/, so it lands in
# Overlay/ and Server/ stays vanilla.
#
#   - mods/deathmatch/mtaserver.conf: servername, ports, players, password, LAN, fps limit, voice,
#     MTA_CONFIG ("element=value;..."), and the startup resources. Empty variables leave the
#     file's value alone, so other edits to the file are kept
#   - mods/deathmatch/acl.xml: resource.lancommander in the Admin group (it creates the admin account)
#   - mods/deathmatch/settings.xml: the party rotation settings, the admin account and
#     MTA_RESOURCE_SETTINGS ("resource.setting=value;...")
#   - mods/deathmatch/resources: the image's resources from /opt/lancommander/mta-resources:
#     [lancommander]/lancommander always, [managers]/mapcycler (the party rotation, replacing the
#     stock one) when MTA_PARTY_ROTATION=true

$dm = Join-Path $Env:SERVER_ROOT 'mods/deathmatch'
$confFile = Join-Path $dm 'mtaserver.conf'
$aclFile = Join-Path $dm 'acl.xml'
$settingsFile = Join-Path $dm 'settings.xml'
$resources = Join-Path $dm 'resources'
$bundled = '/opt/lancommander/mta-resources'

if (-not (Test-Path -Path $confFile)) {
    Write-Log -Level Error "$confFile not found; set MTA_BASECONFIG_URL or put an mtaserver.conf in Overlay/mods/deathmatch/"
    return
}

function Test-True([string] $Value) { $Value -in 'true', '1', 'yes', 'on' }

function ConvertTo-Bit([string] $Value) {
    if (-not $Value) { return $null }
    if (Test-True $Value) { '1' } elseif ($Value -in 'false', '0', 'no', 'off') { '0' } else { $Value }
}

# "a=b;c=d" (also newlines) -> ordered name/value pairs
function ConvertFrom-Pairs([string] $Text) {
    $pairs = [ordered]@{}
    foreach ($item in ($Text -split '[;\r\n]+')) {
        $item = $item.Trim()
        if (-not $item) { continue }
        $index = $item.IndexOf('=')
        if ($index -lt 1) { Write-Log -Level Warning "Ignoring '$item' (expected name=value)"; continue }
        $pairs[$item.Substring(0, $index).Trim()] = $item.Substring($index + 1).Trim()
    }
    $pairs
}

function Save-Xml([xml] $Document, [string] $Path) {
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.IndentChars = '    '
    $settings.OmitXmlDeclaration = $true
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try { $Document.Save($writer) } finally { $writer.Dispose() }
    # Not -R: a recursive chown through Merged/ would copy every file up into Overlay/
    chown "$($Env:UID):$($Env:GID)" $Path
}

# ---- Bundled resources ----
$ownResources = @('[lancommander]/lancommander')
$party = Test-True $Env:MTA_PARTY_ROTATION
if ($party) { $ownResources += '[managers]/mapcycler' }

foreach ($relative in $ownResources) {
    $target = Join-Path $resources $relative
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    cp -a "$bundled/$relative/." "$target/"
    if ($LASTEXITCODE -ne 0) { throw "Could not copy the $relative resource" }
    chown -R "$($Env:UID):$($Env:GID)" $target
}

# Party rotation off: put the stock mapcycler's meta.xml back (party.lua stays, unused)
$cyclerMeta = Join-Path $resources '[managers]/mapcycler/meta.xml'
$stockMeta = Join-Path $Env:SERVER_DIR 'mods/deathmatch/resources/[managers]/mapcycler/meta.xml'
if (-not $party -and (Test-Path -Path $cyclerMeta) -and (Select-String -Path $cyclerMeta -SimpleMatch 'LANCommander' -Quiet)) {
    if (Test-Path -Path $stockMeta) {
        Copy-Item -Force -Path $stockMeta -Destination $cyclerMeta
        Write-Log "MTA_PARTY_ROTATION is off; restored the stock mapcycler"
    }
}

# ---- mtaserver.conf ----
[xml] $conf = Get-Content -Path $confFile -Raw
$root = $conf.DocumentElement

function Set-ConfValue([string] $Name, $Value) {
    if ($null -eq $Value -or "$Value" -eq '') { return }
    $node = $root.SelectSingleNode($Name)
    if (-not $node) {
        $node = $conf.CreateElement($Name)
        $first = $root.SelectSingleNode('resource')
        if ($first) { [void] $root.InsertBefore($node, $first) } else { [void] $root.AppendChild($node) }
    }
    $node.InnerText = "$Value"
}

$lan = Test-True $Env:MTA_LAN
$values = [ordered]@{
    'servername'                   = $Env:MTA_SERVER_NAME
    'serverport'                   = $Env:MTA_PORT
    'httpport'                     = $Env:MTA_HTTP_PORT
    'maxplayers'                   = $Env:MTA_MAX_PLAYERS
    'fpslimit'                     = $Env:MTA_FPS_LIMIT
    'voice'                        = ConvertTo-Bit $Env:MTA_VOICE
    # ase 0 + donotbroadcastlan 0: answers the LAN browser only; 1: also the internet master list
    'ase'                          = $(if ($Env:MTA_LAN) { if ($lan) { '0' } else { '1' } })
    'donotbroadcastlan'            = $(if ($Env:MTA_LAN) { '0' })
    # Without these a LAN server with internet access raises the minimum client version on its
    # own and sends crash dumps out
    'minclientversion_auto_update' = $(if ($lan) { '0' })
    'crash_dump_upload'            = $(if ($lan) { '0' })
}
foreach ($key in $values.Keys) { Set-ConfValue $key $values[$key] }

# The password is always written, so clearing MTA_PASSWORD opens the server again
$passwordNode = $root.SelectSingleNode('password')
if ($passwordNode -or $Env:MTA_PASSWORD) {
    if (-not $passwordNode) { $passwordNode = $root.AppendChild($conf.CreateElement('password')) }
    $passwordNode.InnerText = "$Env:MTA_PASSWORD"
}

# LAN: no serial authorization for admin logins (otherwise every new PC an admin logs in from
# has to be approved with `authserial` first). MTA_CONFIG can set it back
if ($lan) {
    $node = $root.SelectSingleNode('auth_serial_groups')
    if ($node) { $node.InnerText = '' }
}

foreach ($pair in (ConvertFrom-Pairs $Env:MTA_CONFIG).GetEnumerator()) {
    if ($pair.Value -eq '') {
        $node = $root.SelectSingleNode($pair.Key)
        if ($node) { $node.InnerText = '' }
    } else {
        Set-ConfValue $pair.Key $pair.Value
    }
}

function Set-StartupResource([string] $Name, [bool] $Startup) {
    $node = $root.SelectSingleNode("resource[@src='$Name']")
    if (-not $node) {
        if (-not $Startup) { return }
        $node = $conf.CreateElement('resource')
        $node.SetAttribute('src', $Name)
        $node.SetAttribute('protected', '0')
        [void] $root.AppendChild($node)
    }
    $node.SetAttribute('startup', $(if ($Startup) { '1' } else { '0' }))
}

Set-StartupResource 'lancommander' $true
# The party rotation starts the first game mode itself, and play (freeroam) has no end
Set-StartupResource 'mapcycler' $true
if ($party) { Set-StartupResource 'play' $false }
foreach ($name in ($Env:MTA_START_RESOURCES -split '[\s,;]+' | Where-Object { $_ })) {
    if ($name.StartsWith('-')) { Set-StartupResource $name.Substring(1) $false } else { Set-StartupResource $name $true }
}

Save-Xml $conf $confFile
Write-Log "Wrote the MTA_* settings to $confFile"

# ---- acl.xml: let the bundled resources create the admin account ----
if (Test-Path -Path $aclFile) {
    [xml] $acl = Get-Content -Path $aclFile -Raw
    $admin = $acl.DocumentElement.SelectSingleNode("group[@name='Admin']")
    if ($admin) {
        $changed = $false
        foreach ($object in 'resource.lancommander') {
            if (-not $admin.SelectSingleNode("object[@name='$object']")) {
                $node = $acl.CreateElement('object')
                $node.SetAttribute('name', $object)
                [void] $admin.AppendChild($node)
                $changed = $true
            }
        }
        if ($changed) { Save-Xml $acl $aclFile; Write-Log "Added resource.lancommander to the Admin ACL group" }
    }
}

# ---- settings.xml: resource settings ----
# Stored as <setting name="<access><resource>.<name>" value="<JSON>"/>; access is * (public),
# # (private) or @ (protected), and has to match the resource's meta.xml
if (Test-Path -Path $settingsFile) {
    [xml] $settingsXml = Get-Content -Path $settingsFile -Raw
} else {
    [xml] $settingsXml = '<settings></settings>'
}
$settingsRoot = $settingsXml.DocumentElement

function Set-ResourceSetting([string] $Name, [string] $Value) {
    if (-not ($Name -match '^[*#@]')) { $Name = "*$Name" }
    $bare = $Name.Substring(1)
    # Drop the setting under any other access prefix, so the new value isn't shadowed
    foreach ($prefix in '*', '#', '@') {
        foreach ($old in @($settingsRoot.SelectNodes("setting[@name='$prefix$bare']"))) {
            [void] $settingsRoot.RemoveChild($old)
        }
    }
    $json = if ($Value -match '^-?\d+(\.\d+)?$' -or $Value -in 'true', 'false') { $Value } else { $Value | ConvertTo-Json -Compress }
    $node = $settingsXml.CreateElement('setting')
    $node.SetAttribute('name', $Name)
    $node.SetAttribute('value', "[ $json ]")
    [void] $settingsRoot.AppendChild($node)
}

$resourceSettings = [ordered]@{
    '#lancommander.admin_user'     = $Env:MTA_ADMIN_USER
    '#lancommander.admin_password' = "$Env:MTA_ADMIN_PASSWORD"
}
if ($party) {
    $resourceSettings['*mapcycler.gamemodes'] = $Env:MTA_PARTY_GAMEMODES
    $resourceSettings['*mapcycler.start'] = $Env:MTA_PARTY_START
    $resourceSettings['*mapcycler.race_maps'] = $Env:MTA_PARTY_RACE_MAPS
    $resourceSettings['*mapcycler.time_limit'] = $Env:MTA_PARTY_TIME_LIMIT
    $resourceSettings['*mapcycler.vote_options'] = $Env:MTA_PARTY_VOTE_OPTIONS
}
foreach ($pair in (ConvertFrom-Pairs $Env:MTA_RESOURCE_SETTINGS).GetEnumerator()) {
    $resourceSettings[$pair.Key] = $pair.Value
}

foreach ($key in $resourceSettings.Keys) {
    $value = $resourceSettings[$key]
    # Admin password: always written (empty = no account); others: empty = leave alone
    if ($null -eq $value -or ($value -eq '' -and $key -ne '#lancommander.admin_password')) { continue }
    Set-ResourceSetting $key $value
}

Save-Xml $settingsXml $settingsFile
chmod 600 $settingsFile
Write-Log "Wrote resource settings to $settingsFile"

if ($party) {
    Write-Log "Party rotation: $Env:MTA_PARTY_GAMEMODES; starting with $(if ($Env:MTA_PARTY_START) { $Env:MTA_PARTY_START } else { 'a random mode' })"
}
