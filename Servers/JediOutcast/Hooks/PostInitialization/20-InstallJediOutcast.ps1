#Requires -Modules Logging
#Requires -Modules Hooks

Invoke-Hook "PreInstallJediOutcast"

Write-Log -Message "Installing JK2MV..."

if (-not (Test-Path -Path "${Env:SERVER_DIR}/jk2mvded")) {
    Write-Log "Could not find jk2mvded in ${Env:SERVER_DIR}, proceeding with installation."

    $downloadUrl = $Env:JK2MV_URL

    Write-Log "Downloading JK2MV from $downloadUrl"

    curl -L --output /tmp/JK2MV.zip "$downloadUrl"

    unzip /tmp/JK2MV.zip -d /tmp/JK2MV

    Move-Item -Force -Path "/tmp/JK2MV/base" -Destination $Env:SERVER_DIR/base
    Move-Item -Force -Path "/tmp/JK2MV/linux-amd64/jk2mvded" -Destination $Env:SERVER_DIR/jk2mvded
} else {
    Write-Log "JK2MV already installed in ${Env:SERVER_DIR}, skipping installation."
}

chmod +x "${Env:SERVER_DIR}/jk2mvded"

Write-Log -Message "JK2MV installation complete."

Invoke-Hook "PostInstallJediOutcast"

Set-Location $Env:SERVER_ROOT