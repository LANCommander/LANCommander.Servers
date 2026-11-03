#Requires -Modules Logging

# Lets several players join with the same CD key. The digital releases of Legends of Might and
# Magic all share one key.
#
# The server's CD key code lives in Data\object.lto (the game's server DLL) and is GameSpy's CD key
# SDK. When a player joins, it walks the list of keys already connected and rejects the newcomer
# with "CD Key in use" if one matches. The patch turns the loop's `je` (list empty) at VA
# 0x1008E25F into a `jmp`, so the list is never searched. This is the same byte the LANCommander
# 1.1 archive already ships patched (with the original kept as object.lto.bak).
#
# The online check that follows sends the key to key.gamespy.com. That server is gone, so after
# three 2 s retries the SDK admits the player ("Validation Timeout"). Joining takes a few seconds
# longer because of it, but it isn't patched.
#
# The copy is written through the merged view, so it lands in Overlay/ and Server/ keeps the
# original. Clients don't need it, because only the server loads object.lto. Only the known 1.1
# object.lto is patched; anything else is left alone.

$lto = Join-Path $Env:SERVER_ROOT 'Data/object.lto'

$originalHash = '57E2A6516D679D32BF5892ED4B371D1809517CA6717F7493A3E6D314CDEFCF20'  # 1.1
$patchedHash  = '5D6769784991030EBC46AC4548B2B053B7F3F2B0A86CB1F0C8F5AA4840B95F31'

# .text: VirtualAddress 0x1000 = PointerToRawData 0x1000, image base 0x10000000
$offset = 0x8E25F
$old    = [byte] 0x74  # je
$new    = [byte] 0xEB  # jmp

if ($Env:LOMM_ALLOW_SHARED_CD_KEYS -in @('false', '0', 'no', 'off')) {
    Write-Log "LOMM_ALLOW_SHARED_CD_KEYS is off; not patching object.lto"
    return
}

if (-not (Test-Path -Path $lto)) {
    Write-Log -Level Error "$lto not found; skipping the CD key patch"
    return
}

$hash = (Get-FileHash -Path $lto -Algorithm SHA256).Hash

if ($hash -eq $patchedHash) {
    Write-Log "object.lto already allows shared CD keys"
    return
}

if ($hash -ne $originalHash) {
    Write-Log -Level Warning "Unknown object.lto (sha256 $hash); not patching it. Players sharing a CD key may be rejected with 'CD Key in use'."
    return
}

$bytes = [System.IO.File]::ReadAllBytes($lto)
if ($bytes[$offset] -ne $old) { throw ("Unexpected byte at object.lto+0x{0:X}" -f $offset) }
$bytes[$offset] = $new

[System.IO.File]::WriteAllBytes($lto, $bytes)
chown "$($Env:UID):$($Env:GID)" $lto

$hash = (Get-FileHash -Path $lto -Algorithm SHA256).Hash
if ($hash -ne $patchedHash) { throw "Patched object.lto has an unexpected sha256 $hash" }

Write-Log "Patched object.lto to allow shared CD keys"
