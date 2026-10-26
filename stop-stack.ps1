#Requires -Version 5.1
param(
  [switch]$KeepSocks,
  [string]$Project = "artex"
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root
$PidFile = Join-Path $Root "docker\host-socks5.pid"

Write-Host "[stop-stack] docker compose -p $Project down"
& docker compose -p $Project down

if (-not $KeepSocks) {
  $stopped = $false
  if (Test-Path $PidFile) {
    $pid = (Get-Content $PidFile -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($pid) {
      Stop-Process -Id ([int]$pid) -Force -ErrorAction SilentlyContinue
      $stopped = $true
    }
    Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
  }
  Get-CimInstance Win32_Process -Filter "Name='python.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*host-socks5.py*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; $stopped = $true }
  if ($stopped) { Write-Host "[stop-stack] stopped host SOCKS" } else { Write-Host "[stop-stack] no host SOCKS pid found" }
} else {
  Write-Host "[stop-stack] kept SOCKS (-KeepSocks)"
}