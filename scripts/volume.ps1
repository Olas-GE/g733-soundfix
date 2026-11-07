# G733 SoundFix - louder / quieter
# Changes a volume offset (preamp) that is applied on top of the active preset.
# Steps of 2 dB, limited to -12 ... +4 dB so the sound does not distort.
# Normally started (already elevated) by the "\G733 SoundFix\Louder|Quieter|Volume reset" tasks.
param([ValidateSet('Up', 'Down', 'Reset')][string]$Action = 'Up')

$me = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $me.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden',
        '-File', "`"$PSCommandPath`"", '-Action', $Action)
    exit
}

$Min = -12; $Max = 4; $Step = 2
$vol = Join-Path $env:ProgramFiles 'EqualizerAPO\config\G733-Volume.txt'

$current = 0
if (Test-Path $vol) {
    $m = Select-String -Path $vol -Pattern '^\s*Preamp:\s*([-+]?\d+(\.\d+)?)' | Select-Object -First 1
    if ($m) { $current = [double]$m.Matches[0].Groups[1].Value }
}
switch ($Action) {
    'Up'    { $current += $Step }
    'Down'  { $current -= $Step }
    'Reset' { $current = 0 }
}
$current = [Math]::Max($Min, [Math]::Min($Max, $current))

Set-Content -Path $vol -Encoding ASCII -Value @(
    '# G733 SoundFix volume offset, added on top of the preset preamp. Range -12 to +4 dB.',
    "Preamp: $current dB")
