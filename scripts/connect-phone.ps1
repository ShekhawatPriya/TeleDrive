param(
  [string] $DeviceId,
  [switch] $Install
)
$ErrorActionPreference = 'Stop'
$frontend = Split-Path -Parent $PSScriptRoot
$backend = [IO.Path]::GetFullPath((Join-Path $frontend '..\VPS BSDK'))
$python = Join-Path $backend '.venv\Scripts\python.exe'
$adb = Join-Path $env:LOCALAPPDATA 'Android\sdk\platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $python)) { throw "Backend Python environment is missing: $python" }
if (-not (Test-Path -LiteralPath $adb)) { throw 'Android platform tools are missing.' }

# Read only connection settings. Do not print, rewrite or rotate credentials.
$port = 8000
$prefix = '/api'
foreach ($line in Get-Content -LiteralPath (Join-Path $backend '.env')) {
  if ($line -match '^APP_PORT=(\d+)\s*$') { $port = [int]$Matches[1] }
  if ($line -match '^API_PREFIX=(/[^\s]*)\s*$') { $prefix = $Matches[1].TrimEnd('/') }
}
$healthUrl = "http://127.0.0.1:$port$prefix/health"
function Test-Backend {
  try { return (Invoke-RestMethod -Uri $healthUrl -TimeoutSec 3).database_ok -eq $true }
  catch { return $false }
}

function Test-DockerReady {
  $probe = [Diagnostics.Process]::new()
  $probe.StartInfo.FileName = (Get-Command docker -ErrorAction Stop).Source
  $probe.StartInfo.Arguments = 'info --format {{.ServerVersion}}'
  $probe.StartInfo.UseShellExecute = $false
  $probe.StartInfo.CreateNoWindow = $true
  $probe.StartInfo.RedirectStandardOutput = $true
  $probe.StartInfo.RedirectStandardError = $true
  try {
    [void]$probe.Start()
    if (-not $probe.WaitForExit(5000)) { $probe.Kill(); return $false }
    return $probe.ExitCode -eq 0
  } finally { $probe.Dispose() }
}
if (-not (Test-Backend)) {
  if (-not (Test-DockerReady)) {
    Write-Host 'Starting Docker Desktop...'
    Start-Process -FilePath 'C:\Program Files\Docker\Docker\Docker Desktop.exe' -WindowStyle Hidden
    $deadline = (Get-Date).AddSeconds(120)
    while (-not (Test-DockerReady)) {
      if ((Get-Date) -gt $deadline) { throw 'Docker did not start. Check Docker Desktop for an error; do not reset its data.' }
      Start-Sleep -Seconds 2
    }
  }
  Push-Location $backend
  try {
    docker compose up -d --no-recreate postgres
    if ($LASTEXITCODE -ne 0) { throw 'Could not start PostgreSQL.' }
    $databaseContainer = (docker compose ps -q postgres).Trim()
    if (-not $databaseContainer) { throw 'PostgreSQL container was not found.' }
    $databaseReady = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
      docker exec $databaseContainer pg_isready -U user -d teledrive *> $null
      if ($LASTEXITCODE -eq 0) { $databaseReady = $true; break }
      Start-Sleep -Seconds 1
    }
    if (-not $databaseReady) { throw 'PostgreSQL did not become ready.' }
    if (-not (Test-Backend)) {
      if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) {
        throw "Port $port is already occupied by an unhealthy service; no process was stopped."
      }
      $logs = Join-Path $backend 'runtime\logs'
      New-Item -ItemType Directory -Path $logs -Force | Out-Null
      Start-Process -FilePath $python -ArgumentList @('-m','uvicorn','app.main:app','--app-dir','backend','--host','0.0.0.0','--port',"$port",'--no-access-log') -WorkingDirectory $backend -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logs 'phone-backend.out.log') -RedirectStandardError (Join-Path $logs 'phone-backend.err.log')
      $ready = $false
      for ($attempt = 0; $attempt -lt 30; $attempt++) {
        if (Test-Backend) { $ready = $true; break }
        Start-Sleep -Seconds 1
      }
      if (-not $ready) { throw "Backend did not start. See $logs\phone-backend.err.log" }
    }
  } finally { Pop-Location }
}
$devices = @(& $adb devices | Select-String "`tdevice$" | ForEach-Object { ($_.Line -split "`t")[0] })
if ($DeviceId) {
  if ($DeviceId -notin $devices) { throw 'The requested phone is not connected or USB debugging is not authorized.' }
  $devices = @($DeviceId)
}
if ($devices.Count -eq 0) { throw 'Connect your phone by USB and allow USB debugging.' }
foreach ($serial in $devices) {
  & $adb -s $serial reverse "tcp:$port" "tcp:$port"
  if ($LASTEXITCODE -ne 0) { throw "Could not connect device $serial to the backend." }
  if ($Install) {
    $apk = Join-Path $frontend 'build\app\outputs\flutter-apk\app-debug.apk'
    if (-not (Test-Path -LiteralPath $apk)) { throw 'Build the debug APK first: flutter build apk --debug' }
    & $adb -s $serial install -r $apk
    if ($LASTEXITCODE -ne 0) { throw 'Installation failed. Existing app data was not removed.' }
  }
  & $adb -s $serial shell am start -n com.example.flutter_m_fsdk/.MainActivity
  if ($LASTEXITCODE -ne 0) { throw 'Could not open TeleDrive on the phone.' }
}
Write-Host 'TeleDrive is ready. USB connects the phone to the backend without Wi-Fi or IP address changes.'
