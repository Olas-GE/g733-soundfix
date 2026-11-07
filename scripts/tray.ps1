# G733 SoundFix - tray icon (next to the clock)
# Shows the active preset, switches presets, changes volume, warns after a Windows update.
# Runs as the normal user (no admin); changes go through the "\G733 SoundFix\..." scheduled tasks.

$ErrorActionPreference = 'SilentlyContinue'

# only one copy at a time
$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\G733SoundFix-Tray', [ref]$created)
if (-not $created) { exit }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$cfgDir   = Join-Path $env:ProgramFiles 'EqualizerAPO\config'
$presets  = 'Krast597', 'Krast597-Clarity', 'Music', 'Game', 'Off'
$schtasks = Join-Path $env:SystemRoot 'System32\schtasks.exe'
$script:lastPreset = $null
$script:fixOnClick = $false

function Get-State {
    $preset = 'not active'; $vol = 0
    $cfg = Join-Path $cfgDir 'config.txt'
    if (Test-Path $cfg) {
        foreach ($line in Get-Content $cfg) {
            if ($line -match '^\s*Include:\s*G733-(.+)\.txt\s*$' -and $Matches[1] -ne 'Volume') { $preset = $Matches[1]; break }
        }
    }
    $vf = Join-Path $cfgDir 'G733-Volume.txt'
    if (Test-Path $vf) {
        foreach ($line in Get-Content $vf) {
            if ($line -match '^\s*Preamp:\s*([-+]?\d+(\.\d+)?)') { $vol = [double]$Matches[1]; break }
        }
    }
    return @{ Preset = $preset; Volume = $vol }
}

function Format-Vol($v) { if ($v -eq 0) { '0 dB' } elseif ($v -gt 0) { "+$v dB" } else { "$v dB" } }

function Run-Task($name) {
    Start-Process -FilePath $schtasks -ArgumentList @('/run', '/tn', "`"\G733 SoundFix\$name`"") -WindowStyle Hidden -Wait
    Start-Sleep -Milliseconds 700
    Update-Ui
}

function Open-DeviceSelector {
    foreach ($n in 'DeviceSelector.exe', 'Configurator.exe') {
        $p = Join-Path $env:ProgramFiles "EqualizerAPO\$n"
        if (Test-Path $p) { Start-Process $p -Verb RunAs; return }
    }
}

# --- icon and menu ---
$icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Join-Path $env:SystemRoot 'System32\mmsys.cpl'))
if (-not $icon) { $icon = [System.Drawing.SystemIcons]::Information }
$ni = New-Object System.Windows.Forms.NotifyIcon
$ni.Icon = $icon
$menu = New-Object System.Windows.Forms.ContextMenuStrip

$header = New-Object System.Windows.Forms.ToolStripMenuItem('G733 SoundFix')
$header.Enabled = $false
[void]$menu.Items.Add($header)
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

$items = @{}
foreach ($p in $presets) {
    $it = New-Object System.Windows.Forms.ToolStripMenuItem($p)
    $it.Tag = $p
    $it.Add_Click({ param($s, $e) Run-Task $s.Tag })
    [void]$menu.Items.Add($it)
    $items[$p] = $it
}
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

$volItem = New-Object System.Windows.Forms.ToolStripMenuItem('Volume offset: 0 dB')
$volItem.Enabled = $false
[void]$menu.Items.Add($volItem)
$up = New-Object System.Windows.Forms.ToolStripMenuItem('Louder (+2 dB)');  $up.Add_Click({ Run-Task 'Louder' });  [void]$menu.Items.Add($up)
$dn = New-Object System.Windows.Forms.ToolStripMenuItem('Quieter (-2 dB)'); $dn.Add_Click({ Run-Task 'Quieter' }); [void]$menu.Items.Add($dn)
$rs = New-Object System.Windows.Forms.ToolStripMenuItem('Reset volume');    $rs.Add_Click({ Run-Task 'Volume reset' }); [void]$menu.Items.Add($rs)
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

$fix = New-Object System.Windows.Forms.ToolStripMenuItem('Fix after Windows update (device window)')
$fix.Add_Click({ Open-DeviceSelector })
[void]$menu.Items.Add($fix)
$quit = New-Object System.Windows.Forms.ToolStripMenuItem('Hide this icon (EQ stays on)')
$quit.Add_Click({ $ni.Visible = $false; [System.Windows.Forms.Application]::Exit() })
[void]$menu.Items.Add($quit)

$ni.ContextMenuStrip = $menu
$ni.Add_MouseClick({ param($s, $e)
    # open the menu the same way Windows does for a right-click, so it closes when you click elsewhere
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $show = [System.Windows.Forms.NotifyIcon].GetMethod('ShowContextMenu', [System.Reflection.BindingFlags]'Instance,NonPublic')
        if ($show) { $show.Invoke($ni, $null) } else { $menu.Show([System.Windows.Forms.Cursor]::Position) }
    }
})
$ni.Add_BalloonTipClicked({ if ($script:fixOnClick) { $script:fixOnClick = $false; Open-DeviceSelector } })

function Update-Ui {
    $st = Get-State
    foreach ($p in $presets) { $items[$p].Checked = ($p -eq $st.Preset) }
    $v = Format-Vol $st.Volume
    $volItem.Text = "Volume offset: $v"
    $tip = "G733 SoundFix: $($st.Preset), $v"
    if ($tip.Length -gt 63) { $tip = $tip.Substring(0, 63) }
    $ni.Text = $tip
    if ($null -ne $script:lastPreset -and $script:lastPreset -ne $st.Preset) {
        $ni.ShowBalloonTip(2000, 'G733 SoundFix', "Preset: $($st.Preset)", [System.Windows.Forms.ToolTipIcon]::Info)
    }
    $script:lastPreset = $st.Preset
}

$ni.Visible = $true
Update-Ui

# --- notice after a Windows feature update (it can unhook Equalizer APO) ---
$key   = 'HKCU:\Software\G733 SoundFix'
$build = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild
if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
$prev = (Get-ItemProperty -Path $key -Name LastBuild).LastBuild
if ($prev -and $build -and $prev -ne $build) {
    $script:fixOnClick = $true
    $ni.ShowBalloonTip(15000, 'G733 SoundFix: Windows was updated',
        'If the EQ stopped working, click here and tick the G733 under Playback devices again.',
        [System.Windows.Forms.ToolTipIcon]::Warning)
}
if ($build) { Set-ItemProperty -Path $key -Name LastBuild -Value $build }

# refresh every 3 seconds (also catches changes made from the Start menu)
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({ Update-Ui })
$timer.Start()

[System.Windows.Forms.Application]::Run()
$ni.Dispose()
