#Requires -Modules Logging
#Requires -Modules Hooks

Invoke-Hook "PreServerInstall"

Write-Log "Installing Tribes: Vengeance Dedicated Server..."

if (-not (Test-Path -Path "${Env:SERVER_DIR}/Program/Bin/Beta_Dedicated_Server.exe")) {
    Write-Log "Could not find server files in ${Env:SERVER_DIR}/Program/Bin, proceeding with installation."

    $downloadUrl = $Env:SERVER_DOWNLOAD_URL

    Invoke-WebRequest -Uri $downloadUrl -OutFile /tmp/server.zip

    Expand-Archive -Path /tmp/server.zip -DestinationPath $Env:SERVER_DIR -Force
} else {
    Write-Log "Server files already exist in ${Env:SERVER_DIR}/Program/Bin, skipping installation."
}

Write-Log "Tribes: Vengeance Dedicated Server installation complete."

Invoke-Hook "PostServerInstall"

Set-Location $Env:SERVER_ROOT