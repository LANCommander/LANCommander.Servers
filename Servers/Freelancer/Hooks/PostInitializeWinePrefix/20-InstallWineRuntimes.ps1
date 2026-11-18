#Requires -Modules Logging
#Requires -Modules Hooks

# Install the Windows runtimes FLServer needs into the prefix. Both redists are cached in the image
# ($Env:W_CACHE), so this needs no download.
#   - directplay: FLServer hosts with DirectPlay 8, and Wine's builtin dpnet stubs out
#     IDirectPlay8Server::Host.
#   - mfc42: FLServer.exe imports MFC42.DLL, which Wine doesn't ship ("Library MFC42.DLL ... not
#     found", exit code 53).

$prefix = $Env:WINEPREFIX
$runAs  = "$($Env:UID):$($Env:GID)"

foreach ($verb in 'directplay', 'mfc42') {
    $marker = Join-Path $prefix ".lancommander-$verb"

    if (Test-Path -Path $marker) {
        Write-Log "$verb already installed"
        continue
    }

    Write-Log "Installing $verb into the Wine prefix"

    & gosu $runAs env "W_CACHE=$Env:W_CACHE" winetricks -q $verb
    $exitCode = $LASTEXITCODE
    & gosu $runAs wineserver --wait

    if ($exitCode -ne 0) {
        throw "winetricks $verb failed with exit code $exitCode"
    }

    New-Item -ItemType File -Path $marker -Force | Out-Null
    chown $runAs $marker

    Write-Log "$verb installed"
}
