#Requires -Modules Logging

# Start nginx in front of MHServerEmu's web front end (see /usr/local/share/mhserveremu-nginx.conf.template):
# the web files in Merged/htdocs/ on port 80, and /AuthServer, /Dashboard etc. passed on to
# 127.0.0.1:MH_WEB_PORT over HTTP (80) and HTTPS (443). MH_TLS_CERT/MH_TLS_KEY pick the
# certificate; the image's self-signed one is fine, the client doesn't check it.

if ($Env:HTTP_FILESERVER_ENABLED -in 'true', '1') {
    Write-Log -Level Warning "HTTP_FILESERVER_ENABLED is set, but this image runs its own nginx on port 80; the base image's file server will fail to start"
}

$webRoot = Join-Path $Env:SERVER_ROOT 'htdocs'
if (-not (Test-Path -Path (Join-Path $webRoot 'SiteConfig.xml'))) {
    Write-Log -Level Error "htdocs/SiteConfig.xml not found in $Env:SERVER_ROOT; clients can't connect"
}

foreach ($file in $Env:MH_TLS_CERT, $Env:MH_TLS_KEY) {
    if (-not $file -or -not (Test-Path -Path $file)) {
        throw "TLS certificate or key not found: '$file' (MH_TLS_CERT / MH_TLS_KEY)"
    }
}

$webPort = if ("$Env:MH_WEB_PORT" -match '^\d+$') { $Env:MH_WEB_PORT } else { '8080' }

$config = (Get-Content -Path '/usr/local/share/mhserveremu-nginx.conf.template' -Raw).
    Replace('{{WEB_ROOT}}', $webRoot).
    Replace('{{WEB_PORT}}', $webPort).
    Replace('{{TLS_CERT}}', $Env:MH_TLS_CERT).
    Replace('{{TLS_KEY}}', $Env:MH_TLS_KEY)
Set-Content -Path '/etc/nginx/nginx.conf' -Value $config -NoNewline

$test = & nginx -t 2>&1
if ($LASTEXITCODE -ne 0) { throw "nginx configuration test failed: $test" }

# A restarted container can keep a stale pid file
if (Test-Path -Path '/run/nginx.pid') {
    & nginx -s quit 2>$null
    Remove-Item -Force -Path '/run/nginx.pid' -ErrorAction SilentlyContinue
}

& nginx
if ($LASTEXITCODE -ne 0) { throw 'nginx failed to start' }
Write-Log "nginx serving $webRoot on ports 80 and 443, passing the web front end on to 127.0.0.1:$webPort"
