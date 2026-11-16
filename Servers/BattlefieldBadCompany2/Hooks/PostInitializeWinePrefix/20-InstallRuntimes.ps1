#Requires -Modules Logging

# The BFBC2 server needs the Visual C++ 2005/2008/2010 runtimes, and the emulator's dinput8.dll
# hook passes its calls on to a native dinput8 in the system folder. Install them into the prefix
# with winetricks. The installers are cached in the image ($Env:W_CACHE), so this needs no
# download.

$prefix = $Env:WINEPREFIX
$runAs  = "$($Env:UID):$($Env:GID)"
$verbs  = @('dinput8', 'vcrun2005', 'vcrun2008', 'vcrun2010')
$marker = Join-Path $prefix '.lancommander-bfbc2-runtimes'

if ((Test-Path -LiteralPath $marker) -and ((Get-Content -LiteralPath $marker -Raw).Trim() -eq ($verbs -join ' '))) {
    Write-Log "Visual C++ runtimes and dinput8 already installed"
    return
}

Write-Log "Installing $($verbs -join ', ') into the Wine prefix (first start, this takes a few minutes)"

& gosu $runAs env "W_CACHE=$Env:W_CACHE" "HOME=/tmp" xvfb-run -a winetricks -q @verbs
$exitCode = $LASTEXITCODE
& gosu $runAs wineserver --wait

if ($exitCode -ne 0) {
    throw "winetricks $($verbs -join ' ') failed with exit code $exitCode"
}

Set-Content -LiteralPath $marker -Value ($verbs -join ' ')
chown $runAs $marker

Write-Log "Visual C++ runtimes and dinput8 installed"
