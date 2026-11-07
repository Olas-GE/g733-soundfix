# G733 SoundFix - one-click installer
# Plain-text script: read it before running if you like. Nothing is hidden.
#
# What it does:
#   0. Shows a short instruction (messages\welcome.<language>.txt)
#   1. Looks for the Logitech G733 (warns if not plugged in)
#   2. Installs Equalizer APO if missing - downloaded ONLY from the official SourceForge
#      page and checked against the pinned SHA256 below
#   3. Asks you to tick the G733 in Equalizer APO's device window (one click)
#   4. Copies the presets and activates "Krast597"
#   5. Installs the tool to "C:\Program Files\G733 SoundFix", creates switch tasks, Start menu
#      shortcuts, the tray icon, the "Settings > Apps" entry, then restarts Windows audio

$ErrorActionPreference = 'Stop'
$ToolVersion = '2.1'

$ApoVersion = '1.4.2'
$ApoFile    = "EqualizerAPO-x64-$ApoVersion.exe"
$ApoUrl     = "https://sourceforge.net/projects/equalizerapo/files/$ApoVersion/$ApoFile/download"
# SHA256 of the official EqualizerAPO-x64-1.4.2.exe (checked on VirusTotal: 0/71, Nov 2026).
# Any other file is refused. If you change $ApoVersion, update this value too.
$ApoSha256  = '7403BE7427BBE1936A40DDED082829B6E217FC4F5990FEE5CBA501F0AE055AFA'

$root    = Split-Path $PSScriptRoot -Parent
$msgDir  = Join-Path $root 'messages'

# --- message boxes; text in messages\<name>.<language>.txt (UTF-8), English fallback ---
function Show-Message($name, $buttons, $iconType) {
    $lang = (Get-UICulture).TwoLetterISOLanguageName
    $file = Join-Path $msgDir "$name.$lang.txt"
    if (-not (Test-Path $file)) { $file = Join-Path $msgDir "$name.en.txt" }
    if (-not (Test-Path $file)) { return 'OK' }
    $text = Get-Content -Path $file -Raw -Encoding UTF8
    Add-Type -AssemblyName System.Windows.Forms
    return [string][System.Windows.Forms.MessageBox]::Show($text, 'G733 SoundFix',
        [System.Windows.Forms.MessageBoxButtons]$buttons, [System.Windows.Forms.MessageBoxIcon]$iconType)
}

# --- welcome, then run as administrator ---
$me = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $me.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if ((Show-Message 'welcome' 'OKCancel' 'Information') -ne 'OK') { exit }
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
$presets = 'Krast597', 'Krast597-Clarity', 'Music', 'Game', 'Off'

# files downloaded from the internet are "blocked" by Windows; unblock our own folder
Get-ChildItem $root -Recurse -File | Unblock-File -ErrorAction SilentlyContinue

function Get-Selector {
    foreach ($n in 'DeviceSelector.exe', 'Configurator.exe') {
        $p = Join-Path $apo $n
        if (Test-Path $p) { return $p }
    }
    return $null
}

Say "=== G733 SoundFix v$ToolVersion by Olas GEO ===" Cyan
if (-not [Environment]::Is64BitOperatingSystem) { Say 'Only 64-bit Windows is supported.' Red; Finish 1 }

# --- 1. headset present? ---
Say '[1/5] Looking for the G733...'
$dev = Get-PnpDevice -Class AudioEndpoint -ErrorAction SilentlyContinue |
       Where-Object { $_.FriendlyName -like '*G733*' }
if ($dev) { Say ('      Found: ' + $dev[0].FriendlyName) Green }
else      { Say '      Not found. Plug in the USB receiver and turn the headset on. Continuing anyway.' Yellow }

# --- 2. Equalizer APO ---
if (Get-Selector) {
    Say '[2/5] Equalizer APO is already installed.' Green
} else {
    Say '[2/5] Installing Equalizer APO...'
    $exe = Join-Path $root "installer\$ApoFile"
    if (-not (Test-Path $exe)) {
        $exe = Join-Path $env:TEMP $ApoFile
        Say '      Downloading from the official SourceForge page...'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $ApoUrl -OutFile $exe -UserAgent 'Wget/1.21' -UseBasicParsing
    }
    $fs = [IO.File]::OpenRead($exe); $b = New-Object byte[] 2; [void]$fs.Read($b, 0, 2); $fs.Close()
    if ($b[0] -ne 0x4D -or $b[1] -ne 0x5A) { throw 'The download is not an installer file. Check the internet connection and try again.' }
    $hash = (Get-FileHash $exe -Algorithm SHA256).Hash
    Say "      Installer SHA256: $hash"
    if ($ApoSha256 -and $hash -ne $ApoSha256.ToUpper()) { throw 'The downloaded Equalizer APO installer is not the verified official file (SHA256 mismatch). Installation stopped for safety.' }
    Say '      Verified: this is the official file.' Green

    Say '      A device window will open: tick the G733 under "Playback devices" ONLY (not under Capture) and click OK.' Cyan
    Say '      If a test window then shows a yellow warning under Pre-mix but a green tick under Post-mix, that is fine: click OK.' Cyan
    Start-Process $exe -ArgumentList '/S' -Wait
    if (-not (Get-Selector)) { throw 'Equalizer APO installation did not complete.' }
}

# --- 3. make sure the G733 is selected in Equalizer APO ---
Say '[3/5] Device selection'
$ans = Read-Host '      Is the G733 ticked in Equalizer APO? Y = yes, N = open the device window now'
if ($ans -notmatch '^[Yy]') {
    Say '      Tick the G733 under "Playback devices" ONLY (not under Capture), click OK, then close the window.' Cyan
    Start-Process (Get-Selector) -Wait
}

# --- 4. presets ---
Say '[4/5] Installing presets (active: Krast597)...'
New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
if ((Test-Path $cfg) -and -not (Test-Path $backup) -and
    -not (Select-String -Path $cfg -Pattern 'G733-' -Quiet)) {
    Copy-Item $cfg $backup        # your previous settings, restored by the uninstaller
}
# drop presets/scripts from older versions, keep the volume offset
Get-ChildItem -Path $cfgDir -Filter 'G733-*' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne 'G733-Volume.txt' } | Remove-Item -Force
Copy-Item (Join-Path $root 'presets\G733-*.txt') $cfgDir -Force
$vol = Join-Path $cfgDir 'G733-Volume.txt'
if (-not (Test-Path $vol)) {
    Set-Content -Path $vol -Encoding ASCII -Value @(
        '# G733 SoundFix volume offset, added on top of the preset preamp. Range -12 to +4 dB.',
        'Preamp: 0 dB')
}
Set-Content -Path $cfg -Encoding ASCII -Value @('# Managed by G733 SoundFix', 'Include: G733-Krast597.txt', 'Include: G733-Volume.txt')
# undo the "Users can write" permission set by an early test version of this tool (if present)
& icacls.exe $cfgDir /remove:g '*S-1-5-32-545' | Out-Null

# --- 5. tool folder, tasks, shortcuts, tray, Settings entry ---
# remove leftovers of version 2.0, which was still called "G733 EQ"
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*G733 EQ*tray.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
try { Get-ScheduledTask -TaskPath '\G733 EQ\' -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
      $svc = New-Object -ComObject Schedule.Service; $svc.Connect(); $svc.GetFolder('\').DeleteFolder('G733 EQ', 0) } catch { }
foreach ($old in (Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'G733 EQ'),
                 (Join-Path ([Environment]::GetFolderPath('CommonStartup')) 'G733 EQ tray icon.lnk'),
                 (Join-Path $env:ProgramFiles 'G733 EQ'),
                 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\G733 EQ', 'HKCU:\Software\G733 EQ') {
    if (Test-Path $old) { Remove-Item $old -Recurse -Force -ErrorAction SilentlyContinue }
}

Say '[5/5] Installing the tool, shortcuts and tray icon...'
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*G733 SoundFix*tray.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $toolDir | Out-Null
foreach ($f in 'switch.ps1', 'volume.ps1', 'tray.ps1', 'uninstall.ps1') {
    Copy-Item (Join-Path $PSScriptRoot $f) (Join-Path $toolDir $f) -Force
}
$switch = Join-Path $toolDir 'switch.ps1'
$volume = Join-Path $toolDir 'volume.ps1'
$tray   = Join-Path $toolDir 'tray.ps1'
$psArgs = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File'

# Scheduled tasks let the tray and the Start menu change settings without a UAC prompt
# each time. They only run the tool's own scripts from Program Files (writable by
# administrators only), with fixed arguments.
$taskPath = '\G733 SoundFix\'
$jobs = [ordered]@{}
foreach ($p in $presets) { $jobs[$p] = "$psArgs `"$switch`" -Preset $p" }
$jobs['Louder']       = "$psArgs `"$volume`" -Action Up"
$jobs['Quieter']      = "$psArgs `"$volume`" -Action Down"
$jobs['Volume reset'] = "$psArgs `"$volume`" -Action Reset"
$useTasks = $true
try {
    $user = (Get-CimInstance Win32_ComputerSystem).UserName
    if (-not $user) { $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name }
    Get-ScheduledTask -TaskPath $taskPath -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 1)
    foreach ($name in $jobs.Keys) {
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $jobs[$name]
        Register-ScheduledTask -TaskPath $taskPath -TaskName $name -Action $action -Principal $principal -Settings $settings -Force | Out-Null
    }
} catch {
    $useTasks = $false
    Say '      Could not create the no-prompt tasks; shortcuts will ask for permission instead.' Yellow
}

# remove desktop shortcuts from older versions
foreach ($d in [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktopDirectory')) {
    Get-ChildItem -Path $d -Filter 'G733 * - *.lnk' -ErrorAction SilentlyContinue | Remove-Item -Force
}

# Start menu folder
$shell = New-Object -ComObject WScript.Shell
$startDir = Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'G733 SoundFix'
if (Test-Path $startDir) { Remove-Item $startDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $startDir | Out-Null
function New-Shortcut($path, $target, $arguments, $desc, $style = 1) {
    $lnk = $shell.CreateShortcut($path)
    $lnk.TargetPath = $target; $lnk.Arguments = $arguments; $lnk.Description = $desc
    $lnk.IconLocation = 'mmsys.cpl,0'; $lnk.WindowStyle = $style
    $lnk.Save()
}
$schtasks = Join-Path $env:SystemRoot 'System32\schtasks.exe'
foreach ($name in $jobs.Keys) {
    $lnkName = if ($presets -contains $name) { "Preset - $name" } else { $name }
    if ($useTasks) {
        New-Shortcut (Join-Path $startDir "$lnkName.lnk") $schtasks "/run /tn `"$taskPath$name`"" "G733 SoundFix: $name" 7
    } else {
        New-Shortcut (Join-Path $startDir "$lnkName.lnk") 'powershell.exe' $jobs[$name] "G733 SoundFix: $name" 7
    }
}
New-Shortcut (Join-Path $startDir 'G733 SoundFix tray icon.lnk') 'powershell.exe' "$psArgs `"$tray`"" 'Show the G733 SoundFix icon next to the clock' 7
New-Shortcut (Join-Path $startDir 'Uninstall G733 SoundFix.lnk') 'powershell.exe' "-NoProfile -ExecutionPolicy Bypass -File `"$toolDir\uninstall.ps1`"" 'Uninstall G733 SoundFix'

# tray icon starts with Windows
$startup = Join-Path ([Environment]::GetFolderPath('CommonStartup')) 'G733 SoundFix tray icon.lnk'
New-Shortcut $startup 'powershell.exe' "$psArgs `"$tray`"" 'G733 SoundFix tray icon' 7

# "Settings > Apps" entry
$reg = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\G733 SoundFix'
New-Item -Path $reg -Force | Out-Null
$values = @{
    DisplayName     = 'G733 SoundFix (Krast597 EQ)'
    DisplayVersion  = $ToolVersion
    Publisher       = 'Olas GEO'
    DisplayIcon     = "$env:SystemRoot\System32\mmsys.cpl,0"
    InstallLocation = $toolDir
    UninstallString = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$toolDir\uninstall.ps1`""
}
foreach ($k in $values.Keys) { Set-ItemProperty -Path $reg -Name $k -Value $values[$k] }
Set-ItemProperty -Path $reg -Name NoModify -Value 1 -Type DWord
Set-ItemProperty -Path $reg -Name NoRepair -Value 1 -Type DWord

try {
    Restart-Service -Name AudioEndpointBuilder -Force -ErrorAction Stop   # also restarts Windows Audio
    Start-Service -Name Audiosrv -ErrorAction SilentlyContinue
} catch {
    Say '      Could not restart audio automatically. Restart the PC once.' Yellow
}

# start the tray icon as the normal user (not as admin)
Start-Process explorer.exe -ArgumentList "`"$startup`""

# reminder about Logitech G HUB (its EQ and DTS must be off, the tool can't change them)
$ghub = Join-Path $env:ProgramFiles 'LGHUB\lghub.exe'
if ((Test-Path $ghub) -or (Get-Process -Name 'lghub*' -ErrorAction SilentlyContinue)) {
    if ((Show-Message 'ghub' 'YesNo' 'Warning') -eq 'Yes' -and (Test-Path $ghub)) {
        # open it as the normal user through Explorer: not as admin, and without G HUB writing into this window
        Start-Process explorer.exe -ArgumentList "`"$ghub`""
    }
}

Say ''
Say 'Done. Preset "Krast597" is active and stays active after every restart.' Green
Say 'Use the speaker icon next to the clock, or Start menu > G733 SoundFix, to switch presets and volume.'
Finish 0
