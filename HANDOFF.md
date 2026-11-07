# HANDOFF: continue developing G733 SoundFix with an AI assistant

This file holds the full context of the project so you can keep improving it
on your own, for example with Claude (claude.ai or Claude Code) or any other
AI assistant, without asking the original author anything.

## How to use this file (step by step)

You don't need to be a programmer. Pick the option that fits you.

### Option A: claude.ai in the browser (easiest)

1. **Get the files.** On the GitHub page click **Code → Download ZIP** and
   extract it to a folder.
2. **Open Claude.** Go to https://claude.ai and sign in.
   - *Recommended:* create a **Project** (left menu → Projects → New project),
     call it "G733 SoundFix" and add the extracted files to the project's knowledge.
     Then every new chat in that project already knows the code.
   - *Quick way:* just start a new chat and attach the files there.
3. **Attach the files.** Attach the ZIP. If your chat can't open ZIP files,
   attach the extracted files instead, at least: `HANDOFF.md`, `README.md`,
   `scripts\install.ps1`, `scripts\switch.ps1`, `scripts\uninstall.ps1`
   and everything in `presets\`.
4. **Paste the prompt** from the "Prompt to paste" section below.
5. **Say what you want**, in plain words and in any language. For example:
   - "Add Louder and Quieter shortcuts that change the preamp by 2 dB."
   - "Install.bat stopped with this error: (paste the text). Fix it."
   - "Add a preset for the Logitech G735."
6. **Get the changed files.** Ask Claude to give you the complete updated files
   (not fragments), download them and replace the old ones in your folder.
   Ask it to list which files changed and why.
7. **Test on Windows.** Run `Uninstall.bat`, then `Install.bat`, and listen.
   If something goes wrong, copy the text from the black window and give it to
   Claude in the same chat.
8. **Share it (optional).** See "Sending your changes back" below.

### Option B: Claude Code (for people comfortable with a terminal)

1. Install Claude Code (see https://claude.com/claude-code).
2. Get the code: `git clone <repository URL>` (or extract the ZIP) and open a
   terminal in that folder.
3. Run `claude` and type: *"Read HANDOFF.md and follow it. Then: <your change>."*
   Claude Code edits the files in place; review the changes before committing.

### Option C: another AI assistant

The same steps as Option A work with any assistant that accepts file uploads:
attach the files, paste the prompt, describe the change.

### Tips for good results

- **One change at a time.** Test it, then ask for the next one.
- **Ask "explain what this does"** before running any script you don't
  understand. Never run code you can't explain.
- **Keep the design rules** in section 4. If the assistant suggests breaking one
  (adding an .exe, changing folder permissions, editing the audio registry),
  say no.
- **Ask for README.md (3 languages) and this HANDOFF.md to be updated** whenever
  the behaviour changes, so the next person has the same full context.
- **Start a fresh chat** if a conversation gets very long; attach the latest
  files and this HANDOFF.md again.

### Sending your changes back

- **On GitHub:** click **Fork** (your own copy), upload the changed files with
  **Add file → Upload files**, then open a **Pull request** to the original
  repository with a short description. Your AI assistant can write that
  description for you.
- **Without GitHub:** open an issue on the repository, or comment in the
  Reddit thread, and attach or describe your changes.
- You may also publish your own version under the MIT license. Please keep the
  credit to u/Krast597.

---

## Prompt to paste

> You are taking over an open-source Windows tool called **G733 SoundFix**. Read this
> whole handoff and the attached repository files before changing anything.
> Keep the design rules listed below. When you change something, update
> README.md in all three languages (Georgian, English, Russian) and this
> HANDOFF.md if the facts change. Ask me before changing preset values.

---

## 1. What the tool is

A one-click installer that applies the EQ settings from the Reddit post
**"Guide to fixing sound on the G733"** by **u/Krast597** on r/LogitechG
(https://www.reddit.com/r/LogitechG/comments/10owhnc/guide_to_fixing_sound_on_the_g733/)
to a Logitech G733 headset on Windows, using Equalizer APO.

Users run `Install.bat` once. The EQ is then active after every boot, because
Equalizer APO runs inside the Windows audio engine; nothing has to be launched.

Origin: built in November 2026 by Teimuras Japaridze, pseudonym **Olas GEO**
(not a programmer), together with Claude. Name: "G733 SoundFix by Olas GEO" (version 2.0
was called "G733 EQ"; the installer and uninstaller clean up its leftovers). License: MIT for this repository's files. Equalizer APO is a
separate GPL-2.0 program, downloaded at install time and never stored in the repo.

## 2. Files

**In the repository**

| File | Role |
|---|---|
| `Install.bat` / `Uninstall.bat` | Entry points; run `scripts\install.ps1` / `scripts\uninstall.ps1` with `-ExecutionPolicy Bypass`. |
| `scripts\install.ps1` | Installer, see "What install.ps1 does" below. Version in `$ToolVersion`. |
| `scripts\switch.ps1` | Writes `config.txt` = `Include: G733-<Preset>.txt` + `Include: G733-Volume.txt`. Self-elevates if needed (normally started elevated by a scheduled task). |
| `scripts\volume.ps1` | `-Action Up/Down/Reset`: changes `G733-Volume.txt` (`Preamp: <n> dB`) in 2 dB steps, clamped to -12...+4 dB. |
| `scripts\tray.ps1` | Tray icon (WinForms NotifyIcon), runs as the normal user, single instance (mutex). Shows active preset + volume in tooltip and menu (✓), switches via `schtasks /run`, refreshes every 3 s, balloon on change. Left-click opens the menu through NotifyIcon's internal ShowContextMenu (reflection), so it closes when the user clicks elsewhere (v2.2 fix; `ContextMenuStrip.Show()` alone stayed open). On start compares Windows `CurrentBuild` with `HKCU\Software\G733 SoundFix\LastBuild`; if different, shows a notice that opens the Device Selector when clicked. |
| `scripts\uninstall.ps1` | Removes everything (tray process, Start menu folder, startup shortcut, old desktop shortcuts, tasks, Settings entry, HKCU key, `G733-*` files, tool folder), restores `config.txt.g733-backup`, optionally runs Equalizer APO's `Uninstall.exe`. |
| `presets\*.txt` | The presets, in Equalizer APO syntax. |
| `messages\{welcome,ghub}.{en,ka,ru}.txt` | Text of the message boxes (UTF-8), chosen by Windows display language, English fallback. Kept outside the scripts so the scripts stay ASCII. |
| `README.md`, `HANDOFF.md`, `LICENSE`, `.gitattributes` | Docs (README in 3 languages), this file, MIT license, CRLF rules. |

**What install.ps1 does:** shows the welcome box before elevating → self-elevates →
checks for the G733 (`Get-PnpDevice -Class AudioEndpoint`, name contains "G733") →
installs Equalizer APO 1.4.2 silently (`/S`) if missing, from `installer\` if present,
otherwise from SourceForge; checks "MZ" header and the pinned SHA256 → asks Y/N whether
the G733 is ticked, opens `DeviceSelector.exe`/`Configurator.exe` if not → backs up
`config.txt` once as `config.txt.g733-backup`, deletes old `G733-*` files except
`G733-Volume.txt`, copies presets, creates `G733-Volume.txt` (0 dB) if missing, writes
`config.txt` → copies `switch/volume/tray/uninstall.ps1` to `C:\Program Files\G733 SoundFix\` →
registers scheduled tasks under `\G733 SoundFix\` (one per preset + `Louder`, `Quieter`,
`Volume reset`; principal = logged-on user, RunLevel Highest) → Start menu folder
`G733 SoundFix` (shortcuts run `schtasks /run /tn "\G733 SoundFix\<name>"`, plus tray and
uninstall shortcuts); falls back to UAC-prompting shortcuts if task creation fails →
tray shortcut in the common Startup folder → `HKLM\...\Uninstall\G733 SoundFix` entry
(Settings → Apps) → restarts `AudioEndpointBuilder` → starts the tray non-elevated via
`explorer.exe <shortcut>` → if G HUB is installed/running, shows the G HUB reminder
(Yes opens G HUB).

**Installed on the PC:** `C:\Program Files\EqualizerAPO\config\` (`config.txt`,
`G733-*.txt`, backup), `C:\Program Files\G733 SoundFix\` (scripts), Task Scheduler folder
`\G733 SoundFix\`, Start menu folder `G733 SoundFix`, Startup shortcut `G733 SoundFix tray icon.lnk`,
registry `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\G733 SoundFix` and
`HKCU\Software\G733 SoundFix`.

## 3. Presets and where every number comes from

**G733-Krast597.txt (default)**: the guide reproduced exactly.
- Part 1 is the Peace preset "Bass and High Boost 2" with preamp set to -11, as
  the guide instructs. These lines were copied verbatim from the `peace.txt`
  file that Peace 1.6.9.11 wrote on a real PC:
  ```
  Device: all
  Channel: all
  Preamp: -11 dB
  Filter 5: ON LSC Fc 166 Hz Gain 8 dB Q 0.4
  Filter 10: ON HSC Fc 4000 Hz Gain 7 dB Q 0.7
  ```
- Part 2 is the guide's 15-band graphic EQ, read from the screenshots in the post:
  `GraphicEQ: 25 0; 40 6.2; 63 6.2; 100 1; 160 0; 250 0; 400 0; 630 0; 1000 0; 1600 0; 2500 0; 4000 0.7; 6300 1.4; 10000 2.7; 16000 4.1`
- In the guide, both parts ran at the same time (Peace writes `peace.txt`, and the
  graphic EQ was added in Equalizer APO's editor), so the preset contains both.
- A comment in the thread ("change 166 Hz from 8 to 0") matches the +8 dB at 166 Hz.

**G733-Krast597-Clarity.txt**: the guide's "{EDIT}" variant ("favors clarity
and loudness over bass").
- Part 1 is the author's Peace preset "kz iems tune", **read from a screenshot**
  (not from a file): preamp -7.5; 2000 Hz +2 (Q 1.41, peaking); 4000 Hz +6
  (Q 0.7, high shelf); 8000 Hz +2 (Q 1.41); 16000 Hz +0.5 (Q 1.41); 20000 Hz
  +0.5 (Q 2.99). Peace's band numbering is kept (Filter 9 to 13).
- Part 2 is the same 15-band graphic EQ. **Assumption:** the author says he
  switches between the two Peace presets; we assume the graphic EQ stayed on in
  both cases.

**G733-Volume.txt** (created on the PC, not in the repo): the Louder/Quieter offset, a second `Preamp` line included after the preset. **Assumption to verify:** Equalizer APO adds up multiple `Preamp` commands.

**G733-Music.txt / G733-Game.txt**: mild presets written by Claude from published
measurements of the G733 (RTINGS, SoundGuys). They are NOT from the guide.
**G733-Off.txt**: preamp 0, for A/B comparison.

## 4. Design rules (keep these)

1. **Plain text only.** No .exe, no binaries, no obfuscation. Trust comes from
   people being able to read every file in Notepad.
2. **Equalizer APO comes only from its official SourceForge page** and must match the pinned SHA256.
3. **No permission changes.** Never grant normal users write access to the
   Equalizer APO config folder: the audio service loads files from there
   (e.g. VST plugins), so that would be a privilege-escalation risk. Prompt-free
   switching is done instead with scheduled tasks that run only the tool's own
   script from Program Files with a fixed argument. (An early test version did grant it;
   `install.ps1` removes that grant with `icacls /remove:g *S-1-5-32-545`.)
4. **Don't automate the device selection through the registry.** Equalizer APO
   has no official silent way to attach to a device; editing the audio registry
   keys by hand can break sound on other people's PCs. The one manual click stays.
5. **Peace is not required.** It is only a GUI that writes the same config lines.
6. **PowerShell 5.1 compatible, ASCII-only scripts, CRLF line endings.**
7. **Credit u/Krast597** in the presets and README. If he asks for his name to be
   removed or changed, do it.
8. Keep README in three languages in sync.

## 5. Known limitations / not yet verified

- **Not yet tested end-to-end on a clean Windows PC.** Especially unverified:
  that `EqualizerAPO-x64-1.4.2.exe /S` installs silently and whether it opens the
  Device Selector by itself (the script handles both cases with the Y/N question);
  that the SourceForge `/download` URL returns the installer with the `Wget`
  user agent; the exact name of the device window executable in 1.4.2
  (the script tries `DeviceSelector.exe`, then `Configurator.exe`); the name of
  Equalizer APO's uninstaller (`Uninstall.exe` assumed).
- `$ApoSha256` is pinned to `7403BE7427BBE1936A40DDED082829B6E217FC4F5990FEE5CBA501F0AE055AFA` (official EqualizerAPO-x64-1.4.2.exe, VirusTotal 0/71, Nov 2026).
  **To move to a newer Equalizer APO version:** change `$ApoVersion`, run the installer once,
  copy the SHA256 the script prints (it will refuse to install, that's expected), check that hash on
  virustotal.com, then put the new value in `$ApoSha256` and update README (3 languages) and this file.
  Changing the scripts or presets does NOT require touching the hash.
- Possible clipping on very bass-heavy content with the Krast597 preset: around
  40 to 63 Hz the low shelf (+8) and the graphic EQ (+6.2) add up to about +14 dB
  while the preamp is -11. This matches the original guide, so it was left as is.
- Tested on the author's PC (Nov 2026): Equalizer APO's check showed a yellow warning for the G733 under Pre-mix and a green tick under Post-mix. Post-mix is enough for the EQ. Users must tick the G733 under Playback only: the presets use `Device: all`, so if the microphone (Capture) is also ticked, the EQ is applied to the mic too.
- Scheduled tasks are registered for the logged-on user. On a PC where a standard (non-admin) user installs with someone else's admin password, the no-prompt shortcuts may not work for that user (not tested).
- 64-bit x86 Windows only (the ARM64 installer isn't handled).
- Windows feature updates can unhook Equalizer APO; re-running `Install.bat` fixes it.
- G HUB's own EQ and DTS surround must be turned off by the user; the tool can't change G HUB.

## 6. Ideas for next steps

- "Louder / Quieter" shortcuts that change the preamp in 2 dB steps, with a safe upper limit.
- Publish ZIPs on GitHub Releases.
- Support other headsets (e.g. let the user pick a model and use AutoEQ profiles).
- Detect directly (not only by Windows build change) whether Equalizer APO is still attached to the G733.
- G HUB: reading its EQ/DTS state isn't possible (settings live in an internal database without a public interface), so the tool only shows a reminder.
