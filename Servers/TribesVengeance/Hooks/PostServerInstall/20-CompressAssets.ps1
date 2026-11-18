#Requires -Modules Logging
#Requires -Modules Hooks

$UccDir = Join-Path $Env:SERVER_ROOT "Program\Bin"
$UccExe = Join-Path $UccDir "ucc.exe"

if (-not (Test-Path -LiteralPath $UccExe)) {
    throw "ucc.exe not found at expected path: $UccExe"
}

# Cache file stores the last known *post-compression* hash of each file.
$CachePath = Join-Path $Env:SERVER_ROOT ".ucc-compress-cache.json"

function Get-Cache {
    if (-not (Test-Path -LiteralPath $CachePath)) {
        return @{}
    }

    $raw = Get-Content -LiteralPath $CachePath -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @{}
    }

    $obj = $raw | ConvertFrom-Json
    $ht = @{}
    foreach ($p in $obj.PSObject.Properties) {
        $ht[$p.Name] = [string]$p.Value
    }
    return $ht
}

function Save-Cache([hashtable] $Cache) {
    $Cache | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $CachePath -Encoding UTF8
}

function Get-Sha256([string] $Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Get-RelativePath([string] $FromDir, [string] $ToPath) {
    $from = [System.IO.Path]::GetFullPath($FromDir)
    $to   = [System.IO.Path]::GetFullPath($ToPath)
    [System.IO.Path]::GetRelativePath($from, $to)
}

function Compress-IfChanged {
    param(
        [Parameter(Mandatory)]
        [string] $FullPath,

        [Parameter(Mandatory)]
        [hashtable] $Cache
    )

    # Use full path as cache key (stable across runs on same machine/container)
    $key = [System.IO.Path]::GetFullPath($FullPath)

    $currentHash = Get-Sha256 $key
    $cachedHash  = $Cache[$key]

    if ($cachedHash -and ($cachedHash -eq $currentHash)) {
        Write-Host "Skip (unchanged): $key"
        return
    }

    $rel = Get-RelativePath -FromDir $UccDir -ToPath $key
    Write-Host "Compress: $rel"

    Push-Location $UccDir
    try {
        & $UccExe compress $rel
        if ($LASTEXITCODE -ne 0) {
            throw "ucc compress failed for '$rel' with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }

    # Update cache to the *new* file contents (post-compression)
    $newHash = Get-Sha256 $key
    $Cache[$key] = $newHash
}

# ----------------------------
# Main
# ----------------------------

$cache = Get-Cache

$targets = @(
    Join-Path $Env:SERVER_ROOT "Content\Maps\*.tvm"
    Join-Path $Env:SERVER_ROOT "Content\Maps\*.pkg"
    Join-Path $Env:SERVER_ROOT "Content\Maps\*.mopp"
    Join-Path $Env:SERVER_ROOT "Content\Art\Environments\*.pkg"
)

Write-Log "Compressing assets with ucc.exe. This may take a while on first run..."

$allFiles = foreach ($pattern in $targets) {
    Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue
}

if (-not $allFiles) {
    Write-Log "No matching files found. Nothing to do."
    exit 0
}

foreach ($f in $allFiles) {
    Compress-IfChanged -FullPath $f.FullName -Cache $cache
}

Save-Cache $cache
Write-Host "Done."