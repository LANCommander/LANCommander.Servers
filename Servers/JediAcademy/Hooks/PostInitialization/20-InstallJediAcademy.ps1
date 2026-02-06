#Requires -Modules Logging
#Requires -Modules Hooks

Invoke-Hook "PreInstallJediAcademy"

Write-Log -Message "Installing OpenJK..."

if (-not (Test-Path -Path "${Env:SERVER_DIR}/openjkded.x86_64")) {
    Write-Log "Could not find openjkded.x86_64 in ${Env:SERVER_DIR}, proceeding with installation."

    $downloadUrl = $Env:OPENJK_URL

    Write-Log "Downloading OpenJK from $downloadUrl"

    curl -L --output /tmp/openjk.tar.gz "$downloadUrl"

    mkdir -p /tmp/openjk

    tar -xvzf /tmp/openjk.tar.gz -C /tmp/openjk

    Move-Item -Force -Path "/tmp/openjk/*" -Destination $Env:SERVER_DIR
} else {
    Write-Log "OpenJK already installed in ${Env:SERVER_DIR}, skipping installation."
}

chmod +x "${Env:SERVER_DIR}/openjkded.x86_64"

Write-Log -Message "OpenJK installation complete."

Invoke-Hook "PostInstallJediAcademy"

Set-Location $Env:SERVER_ROOT