#Requires -Modules Logging

# Start minecraft-lan-announce in the background when MINECRAFT_LAN_ANNOUNCE is true, so the
# server shows up under "LAN Worlds" in clients' multiplayer screen. It dies with the container.

if ("$Env:MINECRAFT_LAN_ANNOUNCE".ToLowerInvariant() -in 'true', '1', 'yes') {
    sh -c '/usr/local/bin/minecraft-lan-announce </dev/null >/dev/null 2>&1 &'
    Write-Log "Announcing the server on the LAN (224.0.2.60:4445)"
}
