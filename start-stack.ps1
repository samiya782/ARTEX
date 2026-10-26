#Requires -Version 5.1
# Start host SOCKS5 (if needed) then ARTEX compose stack with loopback bridge.
param(
  [switch]$Build,
  [switch]$NoSocks,
  [string]$Project = "artex"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

$SocksScript = Join-Path $Root "docker\host-socks5.py"
$SocksPort = 11080
$SocksLog = Join-Path $Root "docker\host-socks5.log"
$SocksErr = Join-Path $Root "docker\host-socks5.err.log"
$PidFile = Join-Path $Root "docker\host-socks5.pid"

function Test-SocksListening {
  $listeners = Get-NetTCPConnection -LocalPort $SocksPort -State Listen -ErrorAction SilentlyContinue
  return $null -ne $listeners
}

function Start-HostSocks {
  if ($NoSocks) {
    Write-Host "[start-stack] skip SOCKS (-NoSocks)"
    return
  }
  if (-not (Test-Path $SocksScript)) {
    throw "missing $SocksScript"
  }
  if (Test-SocksListening) {
    Write-Host "[start-stack] SOCKS already on :$SocksPort"
    return
  }
  Write-Host "[start-stack] starting host SOCKS5 on 0.0.0.0:$SocksPort"
  $p = Start-Process -FilePath "python" -ArgumentList "`"$SocksScript`"" -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput $SocksLog -RedirectStandardError $SocksErr
  $p.Id | Set-Content -Path $PidFile -Encoding ascii
  $ok = $false
  for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 250
    if (Test-SocksListening) { $ok = $true; break }
    if ($p.HasExited) { break }
  }
  if (-not $ok) {
    $err = ""
    if (Test-Path $SocksErr) { $err = Get-Content $SocksErr -Raw -ErrorAction SilentlyContinue }
    throw "SOCKS failed to listen on :$SocksPort. $err"
  }
  Write-Host "[start-stack] SOCKS pid=$($p.Id)"
}

Start-HostSocks

$composeArgs = @("-p", $Project, "up", "-d")
if ($Build) { $composeArgs += "--build" }
Write-Host "[start-stack] docker compose $($composeArgs -join ' ')"
& docker compose @composeArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& docker compose -p $Project ps
Write-Host "[start-stack] UI http://localhost:8787  |  SOCKS host:11080"