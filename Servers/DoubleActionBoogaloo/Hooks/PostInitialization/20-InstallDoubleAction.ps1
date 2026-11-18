#Requires -Modules Hooks
#Requires -Modules Logging
#Requires -Modules OverlayFS

# Installs the Double Action Dedicated Server (Steam app 317800) with SteamCMD, forced to the
# Windows depot. The game content (dab/) comes from a depot shared with the game, which only has
# Windows server binaries (dab/bin/server.dll), so the server runs under Wine.
# Runs after the WINE image's 10-InitializeWinePrefix.ps1.

$serverDir = $Env:SERVER_DIR
$runAs     = "$($Env:UID):$($Env:GID)"
$changed   = $false

New-Item -ItemType Directory -Path $serverDir -Force | Out-Null

try {
    $srcds     = Join-Path $serverDir 'srcds.exe'
    $serverDll = Join-Path $serverDir 'dab/bin/server.dll'
    $manifest  = Join-Path $serverDir "steamapps/appmanifest_$($Env:STEAM_APP_ID).acf"

    if ($Env:STEAM_APP_UPDATE -in @('true', '1') -or -not (Test-Path -Path $manifest)) {
        Invoke-Hook "PreSteamInstallGame"

        Write-Log "Installing/updating Steam app $Env:STEAM_APP_ID (Windows depot) with SteamCMD"

        # A fresh SteamCMD fails the first install of this app with "Missing configuration" until
        # the app info has been refreshed, so app_info_update runs in the same session.
        $steamArgs = @(
            '+@ShutdownOnFailedCommand', '1',
            '+@NoPromptForPassword', '1',
            '+@sSteamCmdForcePlatformType', 'windows',
            '+force_install_dir', $serverDir,
            '+login', $Env:STEAM_USERNAME
        )
        if ($Env:STEAM_USERNAME -ne 'anonymous' -and $Env:STEAM_PASSWORD) { $steamArgs += $Env:STEAM_PASSWORD }

        $steamArgs += '+app_info_update', '1', '+app_update', $Env:STEAM_APP_ID
        if ($Env:STEAM_BRANCH) {
            $steamArgs += '-beta', $Env:STEAM_BRANCH
            if ($Env:STEAM_BRANCH_PASSWORD) { $steamArgs += '-betapassword', $Env:STEAM_BRANCH_PASSWORD }
        }

        $validate  = $Env:STEAM_VALIDATE -in @('true', '1')
        $attempts  = [Math]::Max(1, [int]$Env:STEAM_INSTALL_ATTEMPTS)
        $installed = $false

        for ($attempt = 1; $attempt -le $attempts; $attempt++) {
            $attemptArgs = $steamArgs
            if ($validate -or $attempt -gt 1) { $attemptArgs += 'validate' }

            & /opt/steamcmd/steamcmd.sh @($attemptArgs + '+quit')
            $exitCode = $LASTEXITCODE

            if ($exitCode -eq 0 -and (Test-Path -Path $srcds) -and (Test-Path -Path $serverDll)) {
                Write-Log "SteamCMD install completed"
                $installed = $true
                break
            }

            Write-Log -Level Warning "SteamCMD attempt $attempt of $attempts failed (exit code $exitCode)"
        }

        $changed = $true

        if (-not $installed) {
            Write-Log -Level Warning "SteamCMD did not finish after $attempts attempts"
        }

        Invoke-Hook "PostSteamInstallGame"
    } else {
        Write-Log "STEAM_APP_UPDATE is disabled. Skipping the Double Action Dedicated Server update."
    }

    if (-not (Test-Path -Path $srcds) -or -not (Test-Path -Path $serverDll)) {
        throw "srcds.exe or dab/bin/server.dll not found in $serverDir. The Double Action Dedicated Server (app $Env:STEAM_APP_ID) is not installed."
    }
} finally {
    # ---- Ownership and overlay (also after a failed install) ----

    if ($changed -and (id -u) -eq '0') {
        # SteamCMD ran as root. Chown Server/ directly, never through Merged/: a chown through the
        # overlay copies every file up into Overlay/.
        chown -R $runAs $serverDir

        # The overlay was mounted before Server/ was filled, and overlayfs doesn't reliably show
        # lower-dir changes made while it is mounted.
        mountpoint -q $Env:SERVER_ROOT
        if ($LASTEXITCODE -eq 0) {
            umount $Env:SERVER_ROOT
            Remove-Item -Path "$Env:WORK_DIR/*" -Recurse -Force -ErrorAction SilentlyContinue

            try {
                Mount-Overlay -MountPoint $Env:SERVER_ROOT -LowerDir $serverDir -UpperDir $Env:OVERLAY_DIR -WorkDir $Env:WORK_DIR -RequireEmptyWorkDir -OverlayOption "xino=on"
                Write-Log "OverlayFS remounted"
            } catch {
                Write-Log -Level Error "Failed to remount OverlayFS: $($_.Exception.Message)"
            }
        }
    }
}

Set-Location $Env:SERVER_ROOT
