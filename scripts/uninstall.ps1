# G733 SoundFix - uninstaller
# Removes everything the installer added and restores your previous Equalizer APO
# settings; optionally uninstalls Equalizer APO itself.

$ErrorActionPreference = 'Stop'

$me = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $me.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    exit
}

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }
function Finish($code) { Write-Host ''; Read-Host 'Press Enter to close' | Out-Null; exit $code }
trap { Say ('ERROR: ' + $_.Exception.Message) Red; Finish 1 }

$apo     = Join-Path $env:ProgramFiles 'EqualizerAPO'
$cfgDir  = Join-Path $apo 'config'
$cfg     = Join-Path $cfgDir 'config.txt'
$backup  = Join-Path $cfgDir 'config.txt.g733-backup'
$toolDir = Join-Path $env:ProgramFiles 'G733 SoundFix'

Say '=== G733 SoundFix uninstaller ===' Cyan

Say '[1/3] Removing tray icon, shortcuts, tasks and the Settings entry...'
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*G733 SoundFix*tray.ps1*' -or $_.CommandLine -like '*G733 EQ*tray.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
foreach ($d in [Environment]::GetFolderPath('CommonDesktopDirectory'), [Environment]::GetFolderPath('Desktop')) {
    Get-ChildItem -Path $d -Filter 'G733 * - *.lnk' -ErrorAction SilentlyContinue | Remove-Item -Force
}
$startDir = Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'G733 SoundFix'
if (Test-Path $startDir) { Remove-Item $startDir -Recurse -Force }
$startup = Join-Path ([Environment]::GetFolderPath('CommonStartup')) 'G733 SoundFix tray icon.lnk'
if (Test-Path $startup) { Remove-Item $startup -Force }
try {
    Get-ScheduledTask -TaskPath '\G733 SoundFix\' -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
    $svc = New-Object -ComObject Schedule.Service; $svc.Connect(); $svc.GetFolder('\').DeleteFolder('G733 SoundFix', 0)
} catch { }
Remove-Item 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\G733 SoundFix' -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item 'HKCU:\Software\G733 SoundFix' -Recurse -Force -ErrorAction SilentlyContinue

# leftovers of version 2.0 ("G733 EQ")
try { Get-ScheduledTask -TaskPath '\G733 EQ\' -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
      $svc2 = New-Object -ComObject Schedule.Service; $svc2.Connect(); $svc2.GetFolder('\').DeleteFolder('G733 EQ', 0) } catch { }
foreach ($old in (Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'G733 EQ'),
                 (Join-Path ([Environment]::GetFolderPath('CommonStartup')) 'G733 EQ tray icon.lnk'),
                 (Join-Path $env:ProgramFiles 'G733 EQ'),
                 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\G733 EQ', 'HKCU:\Software\G733 EQ') {
    if (Test-Path $old) { Remove-Item $old -Recurse -Force -ErrorAction SilentlyContinue }
}
Say '[2/3] Removing presets and restoring previous settings...'
if (Test-Path $cfgDir) {
    if (Test-Path $backup) { Move-Item $backup $cfg -Force }
    elseif (Test-Path $cfg) { Set-Content -Path $cfg -Value '# empty - no processing' -Encoding ASCII }
    Get-ChildItem -Path $cfgDir -Filter 'G733-*' -ErrorAction SilentlyContinue | Remove-Item -Force
}

Say '[3/3] Equalizer APO itself'
$ans = Read-Host '      Also uninstall Equalizer APO? Y = yes, N = keep it'
if ($ans -match '^[Yy]') {
    $un = Join-Path $apo 'Uninstall.exe'
    if (Test-Path $un) { Start-Process $un -Wait }
    else { Say '      Uninstaller not found. Remove it from Settings > Apps.' Yellow }
}

try { Restart-Service -Name AudioEndpointBuilder -Force -ErrorAction Stop; Start-Service Audiosrv -ErrorAction SilentlyContinue } catch { }

# remove the tool folder last (this script may be running from it)
Set-Location $env:TEMP
if (Test-Path $toolDir) { Remove-Item $toolDir -Recurse -Force -ErrorAction SilentlyContinue }

Say 'Done.' Green
Finish 0
