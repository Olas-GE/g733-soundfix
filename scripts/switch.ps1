# G733 SoundFix - switch the active preset
# Normally started (already elevated) by the "\G733 SoundFix\<preset>" scheduled task, so no prompt.
param([ValidateSet('Krast597', 'Krast597-Clarity', 'Music', 'Game', 'Off')][string]$Preset = 'Krast597')

$me = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $me.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden',
        '-File', "`"$PSCommandPath`"", '-Preset', $Preset)
    exit
}

$cfgDir = Join-Path $env:ProgramFiles 'EqualizerAPO\config'
$vol    = Join-Path $cfgDir 'G733-Volume.txt'
if (-not (Test-Path $vol)) {
    Set-Content -Path $vol -Encoding ASCII -Value @(
        '# G733 SoundFix volume offset, added on top of the preset preamp. Range -12 to +4 dB.',
        'Preamp: 0 dB')
}
# Equalizer APO reloads config.txt automatically as soon as it changes
Set-Content -Path (Join-Path $cfgDir 'config.txt') -Encoding ASCII -Value @(
    '# Managed by G733 SoundFix',
    "Include: G733-$Preset.txt",
    'Include: G733-Volume.txt')
