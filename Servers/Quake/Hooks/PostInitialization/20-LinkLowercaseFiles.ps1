#Requires -Modules Logging

# Quake on Linux opens id1/pak0.pak, progs.dat, maps/ and so on by their lowercase names, but
# game data copied from a Windows or DOS install is often uppercase (Id1/PAK0.PAK). For id1 and
# QUAKE_GAME, link the game folder and the files and folders directly inside it to their
# lowercase names when those don't exist. The links are created through Merged/, so they land
# in Overlay/ and Server/ stays untouched.

function New-LowercaseLink([string] $Directory, [string] $Name) {
    $lower = $Name.ToLowerInvariant()
    if ($lower -ceq $Name) { return }

    $link = Join-Path $Directory $lower
    if (Test-Path -LiteralPath $link) { return }

    # Relative target, so the link also works when the folder is viewed from elsewhere
    ln -s -- $Name $link
    if ($LASTEXITCODE -ne 0) { throw "Could not link $link to $Name" }
    chown -h "$($Env:UID):$($Env:GID)" $link

    Write-Log "Linked $link -> $Name"
}

$games = @('id1')
if ($Env:QUAKE_GAME -and $Env:QUAKE_GAME -ne 'id1') { $games += $Env:QUAKE_GAME }

foreach ($game in $games) {
    $dir = Join-Path $Env:SERVER_ROOT $game

    if (-not (Test-Path -LiteralPath $dir)) {
        # Find the folder by any case, then link the requested name to it
        $match = Get-ChildItem -LiteralPath $Env:SERVER_ROOT -Directory | Where-Object { $_.Name -ieq $game } | Select-Object -First 1
        if (-not $match) { continue }

        ln -s -- $match.Name $dir
        if ($LASTEXITCODE -ne 0) { throw "Could not link $dir to $($match.Name)" }
        chown -h "$($Env:UID):$($Env:GID)" $dir
        Write-Log "Linked $dir -> $($match.Name)"
    }

    foreach ($item in Get-ChildItem -LiteralPath $dir) {
        New-LowercaseLink -Directory $dir -Name $item.Name
    }
}
