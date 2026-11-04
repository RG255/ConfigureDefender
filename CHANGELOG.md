# Changelog

All notable changes to this project will be documented in this file.

## [0.4] - 2026-09-12

### Changed (2026-11-04)

- Now requires NamedPipe 0.17 (was 0.16). No code change: 0.17 adds an integrity check to every pipe line (see the NamedPipe CHANGELOG) and
  the public functions are unchanged.

### Changed (2026-10-18)

- The Exclusions tab is built from one table. It carried five copies of the same view, refresh, add, edit and remove code (about
  600 lines); the five categories (ASR, Paths, Extensions, Processes, IPs) are now rows in a table and the logic is written
  once (about 250 lines plus shared helpers), so a fix or a new category is made in one place. Behaviour is unchanged apart from
  the fixes below. A runnable smoke test (`Tests\ConfigureDefender.ExclusionsTabSmokeTest.ps1`) drives the real tab script in an
  invisible form with the server calls stubbed.
- `Get-CDSetting` and `Get-CDThreatAction` are data-driven (one row per setting / severity level instead of 24 and 5 copies of
  an object literal). The objects they return were compared field by field with the previous version on real data and are
  identical.
- The GUI no longer hardcodes the module version. It imports the module that sits next to it and takes the window title from
  what it loaded, so a version branch needs nothing changed there.

- The busy-cursor code that nine load handlers each repeated (status text, busy flag, repaint; and the matching reset in a
  `finally`) is now two shared helpers, `Enter-GuiBusy` and `Exit-GuiBusy`. The handlers keep their own try/catch/finally.
  Tests fail if a handler enters without leaving, leaves outside a `finally`, or goes back to setting the flag itself.

### Fixed (2026-10-18)

- The Exclusions list, the History list and the events grid could stay frozen (no repainting) if any row raised an error while the
  list was being filled, because the update was never ended. The update is now always ended.
- Dialogs, file and folder pickers, the Help window and the main window were never disposed. They are now.
- A filter box that contained `[` raised a wildcard error, and `*` or `?` typed into one acted as a wildcard. Typed filters now
  match literally and ignore case.
- The Allowed Applications list tested every path on disk again on every keystroke in the filter box, which could freeze the
  window for a disconnected network drive. Existence is now worked out once per refresh.
- The ASR tab: a rule that is configured on the machine but is not in the module's list (set by policy, a newer Windows build or
  another tool) was invisible and could not be changed; it is now listed as an unknown rule. Rule lookup no longer rebuilds a
  list for every rule. Choosing an action with the "nothing configured" row selected no longer sends that row to the elevated
  server; the GUID is quoted like every other value, and `Set-CDASRRule` refuses anything that is not a GUID. Adding or removing
  all rules is one call instead of one per rule.
- A failed load of an empty exclusion list left the status bar on "Loading..."; it now says how many entries were loaded.
- Choosing "Custom Date..." on the History tab asked for the date again on every refresh, filter change and tab visit. It asks
  once and again only when the "since" choice is changed.
- When an operation failed the status bar said "Check logs" without saying where; it now names the log file.
- Two refresh handlers left the busy mouse cursor showing after they finished.
- The tab comments were numbered out of order; they now run 1 to 7.
- Module start-up: when a file failed to load, the report named the OLDEST error in the session (often unrelated) instead of the
  one that actually happened, and could itself fail while reporting. It now names the real file, line and statement. A function
  file that did not define its function is a visible warning instead of a message that does not show in non-interactive hosts, a
  variable that fails to create now stops the import instead of leaving a half-initialised module, and an unused routine that
  referred to variables that do not exist was removed.

### Added (2026-10-17)

- Vendored `Write-MyLog`. The vendored `Invoke-FileManagement` calls it when a log level above 0 is requested, and
  nothing in the module supplied it. Nothing passes a log level today, so this closes a latent gap rather than a live
  defect. Internal only; not exported.

### Fixed (2026-10-17)

- Values typed into the GUI (paths, process names, extensions, IP addresses) are now quoted safely before they are
  sent to the elevated server. Only the plain apostrophe was escaped before; PowerShell also treats the curly single
  quotes (U+2018, U+2019, U+201A, U+201B) as quotes, so a path containing one broke the command. A shared helper now
  escapes all of them and refuses control characters.
- Editing a Boolean setting from the Settings tab sent the text `` `$true `` / `` `$false `` and failed. It now sends a
  real `$true` / `$false`, and `Set-CDSetting` also accepts those words as text and converts them.
- `Set-CDSetting` now stops on a Defender error (it could report success after a non-terminating failure) and writes
  its Application event log entry through the .NET EventLog class. `Write-EventLog` does not exist in PowerShell 7
  and the `ConfigureDefender` event source was never registered, so the entry was not being written on either host.
  The source is now registered on first use, from the elevated server.
- The "turn Smart App Control allow logging off when the GUI closes" step could never run, because the main window
  closed the elevated session first. The session is now closed after every other close handler has finished.
- Editing an exclusion, allowed application or protected entry now adds the new value before removing the old one, so
  a failed add leaves the original in place instead of losing it. The list is refreshed either way.
- A setting change that Defender silently ignored was reported as a success. With Tamper Protection on (or a policy in
  force) `Set-MpPreference` returns without an error and leaves the value alone, so `Set-CDSetting` wrote its audit entry
  and the Settings tab showed the value that had been typed. `Set-CDSetting` now reads the value back and fails with a
  clear message when it did not change, and the Settings tab re-reads every setting from Defender after each edit
  (success or failure) and says whether the change was confirmed or NOT applied.
- UNC paths (`\\server\share\...`) are now allowed as path exclusions. `Set-CDExclusionPath` used to refuse them while the
  GUI said they were valid, and its check ran on Remove as well, so a UNC entry already in the list could never be taken
  out. The path is now checked on Add only, and the rule that let `<` through whenever the path also contained `*` is
  gone. The Browse buttons use the same rule as typed input (they had a third, stricter rule and reported a rejection
  where nobody could see it).
- `-RemoveMissing`, `-CheckMissing` and the Allowed Applications tab now share one cautious "is this path really gone"
  rule. `Test-Path -Path` read `[` and `]` in a folder name as a wildcard, so a working entry such as
  `C:\Apps\Tool[1]\tool.exe` looked missing and `-RemoveMissing` removed it. The path is now tested literally,
  environment variables are expanded first, and wildcard entries, unexpandable variables and any error count as not
  missing, so doubt never deletes an entry.
- The setting edit dialog no longer preselects its first choice when the live value is not one of the choices. Controlled
  Folder Access can be 3 or 4 (Block / Audit Disk Modification), which the list does not offer, so pressing OK wrote 0
  (Disabled). It now selects nothing, says so, and OK with no choice changes nothing.
- Turning Smart App Control allow logging off by hand, or at the start-up prompt, said "OFF" without checking the result
  of the request, so a failed disable looked like success while the high-volume channel kept logging. Both now check the
  result, keep the toggle showing ON and warn when it failed (the auto-off timer already did).
- The Smart App Control auto-off timer outlived its window. A Windows Forms timer keeps running after the form that
  created it closes, so a timer left running from one GUI session fired later inside the NEXT session started from the same
  console and showed the "Unhandled exception - You cannot call a method on a null-valued expression" dialog. Closing the
  window now stops and disposes the timer, the tick handler can no longer throw into Windows Forms (any failure is shown on the
  status bar and written to the catch audit), and it now checks that the disable really worked. The status bar's text
  summariser is guarded the same way.
- Turning Smart App Control allow logging on or off wrote two entries to the catch audit every time. The CodeIntegrity
  Verbose channel only ever allows its default (Retain) mode and always refuses Circular ("The parameter is incorrect."),
  and the code deliberately tries that change anyway in case a future build allows it. That known refusal is no longer
  recorded; any other failure at those two steps still is.
- The Allowed Applications list failed with "The term 'Test-CDEntryMissing' is not recognized". The GUI removes and re-imports
  the module as its first step, after which it can see only the module's exported functions, but it called two internal ones:
  `Test-CDEntryMissing` and `Write-MyCatchAudit`. The latter was called from seven `catch` blocks in the GUI scripts (one old,
  six new), where a failing audit call would itself have raised the same error. The GUI now defines forwarders with the same
  names that call into the module, so the call sites are unchanged, and a test fails if any GUI script calls an internal
  function that has no forwarder.
- Event messages were mangled before they were parsed. `Get-CDEvent` turned each Defender event message into bytes and back with
  `[string]::New(bytes)`, which does not decode UTF-8, so any non-ASCII character in a path came out as the wrong characters
  (`José` became `JosÃ©`). The corrupted path then pre-filled the "Add as Exclusion" dialog, so the exclusion could have been
  created for a path that does not exist. A missing message also threw. The message is now used as the text it already is.
- `Get-CDEvent` read every event in a log and filtered afterwards, and hid read failures. The event IDs and start time now go
  into the query itself (ASR/CFA reads went from about 2.2 s to about 0.05 s on a real log; the CodeIntegrity Verbose channel,
  up to 128 MB, is no longer read end to end). "No events matched" and "that log does not exist" still give an empty list, but
  a real failure such as access denied is now an error, so the GUI's own error handling for a failed read can finally run
  instead of showing an empty list. Results were checked identical to the previous version on a real machine.
- A failed request could make the GUI unusable. The server returns its whole error history as text (thousands of
  characters over a hundred lines or more); 34 places put that straight into the status bar, and the auto-sizing
  status strip grew taller than the window and covered everything. The status bar now always shows a one-line summary
  (the caller's message plus the real cause) followed by "[hover here for the full error list]", and the hover tooltip
  lists every error message in the dump, numbered, without the stack traces (the full dump stays in the console).
- `Open-CDPipeSession` now closes a stale or wedged session (force-stopping its server) before it starts a
  replacement, instead of leaving the old elevated server running with no way to reach it.

### Changed (2026-10-12)

- Now requires NamedPipe 0.16 (was 0.15). 0.16 can start the hidden elevated server from Windows PowerShell 5.1
  (0.15 could not, because `Start-Process -WhatIf` does not exist there) and lets a hung request be cancelled from
  the non-elevated client.

### Fixed (2026-10-12)

- Closing the GUI (or `Close-CDPipeSession`) left the hidden elevated NamedPipe server running. The session health
  check was given the wrong object (the whole server/client parameter set instead of its `PipeInfo`), so it always
  reported "not connected" and no exit request was ever sent. `Close-CDPipeSession` now passes the right object and,
  when the normal exit cannot be delivered, force-stops the server (NamedPipe 0.16 `Stop-PipeSession -Force`).
- `Open-CDPipeSession` had the same wrong object in its "healthy session already exists" check, so it never reused a
  session and started a new elevated server on every call. It now reuses a healthy session.
- The GUI window title showed v0.3; it now shows v0.4.

### Added (2026-09-20 follow-up)

- Function-trace facility (`Enable-MyFunctionTrace -Option 1-3`, `Disable-MyFunctionTrace`,
  `Clear-MyFunctionTraceLog`, `Clear-MyFunctionTraceArchive`), vendored. Per-window trace files under
  `C:\ProgramData\FunctionTrace`; `-Option` is required.
- Catch-audit housekeeping (`Clear-MyCatchAuditArchive`).
- Now requires NamedPipe 0.15 (was 0.14).
- `Protect-MyFunctionTraceFolder` (2026-09-21): locks the trace-log folder so other local users cannot read your
  logs (`-Check` reports without elevation). `Enable-MyFunctionTrace` warns once when the folder is not locked
  down; `$env:MyFunctionTraceNoAclWarning = '1'` silences it.

### Fixed (2026-09-21)

- `Get-CDThreatDetection` threw for any Defender threat ID above 2,147,483,647 (for example 2147725502), because it
  cast the ID to a 32-bit `[int]`. The whole detection list was lost and the failure only showed up in the catch
  audit. It now uses `[Int64]`. Regression tests added.

### Removed (2026-09-21)

- The "ConfigureDefender loaded. To use run: Start-ConfigureDefenderGUI" banner printed on import. Several
  modules export the same trace commands, so typing e.g. `Enable-MyFunctionTrace` could auto-load this
  module as a side effect and show an unrelated message. Run `Start-ConfigureDefenderGUI` to use the module.

### Changed (BREAKING)

- 13 exported `Get-CD*` accessors renamed to singular nouns, matching their existing `Set-CD*`
  siblings' naming exactly (PSScriptAnalyzer `PSUseSingularNouns` cleanup):
  `Get-CDASRRules` -> `Get-CDASRRule`, `Get-CDEvents` -> `Get-CDEvent`,
  `Get-CDControlledFolders` -> `Get-CDControlledFolder`, `Get-CDASRExclusions` -> `Get-CDASRExclusion`,
  `Get-CDExclusionProcesses` -> `Get-CDExclusionProcess`, `Get-CDExclusionPaths` -> `Get-CDExclusionPath`,
  `Get-CDExclusionExtensions` -> `Get-CDExclusionExtension`,
  `Get-CDExclusionIpAddresses` -> `Get-CDExclusionIpAddress`,
  `Get-CDAllowedApplications` -> `Get-CDAllowedApplication`, `Get-CDSettings` -> `Get-CDSetting`,
  `Get-CDThreatActions` -> `Get-CDThreatAction`, `Get-CDThreatDetections` -> `Get-CDThreatDetection`,
  `Get-CDSendRequestParams` -> `Get-CDSendRequestParam`. No compatibility aliases are provided for
  the old names - there is no known external usage of this module (confirmed via GitHub: 0 stars, 0
  forks, 0 subscribers, 0 releases as of this version).

### Fixed

- PSScriptAnalyzer cleanup: trailing whitespace stripped repo-tooling-wide (not module-specific);
  added a `PSScriptAnalyzerSettings.psd1` so a fresh clone's own `Invoke-ScriptAnalyzer -Recurse` run
  no longer reports parser noise (`TypeNotFound` et al) or the deliberate `Write-Host` console-output
  style as findings; added inline `SuppressMessageAttribute` justifications for the deliberate
  `PSAvoidGlobalVars` (process-wide catch-audit log / module-load-banner flag) and
  `PSUseShouldProcessForStateChangingFunctions` (the verb IS the purpose, for every `Set-CD*` function
  and the GUI's own view-refresh helpers) findings; added missing `[OutputType(...)]` declarations to
  `Get-CDSetting`, `Get-CDThreatAction`, and `Get-Psd1Data`.

## [0.3] - 2026-07-14

### Added

- Get-CDEvent: Smart App Control / App Control event support. Reads the Microsoft-Windows-CodeIntegrity/Operational log (event IDs 3077 block, 3076 audit, 3033/3034 signing-level, 3089 signature details, 3118 Defender/ISG reputation) in addition to the Defender ASR/CFA events. Events describing one load attempt are grouped by Correlation ActivityId into a single row; \Device\HarddiskVolumeN paths are converted to drive letters. New 'SAC' value for the -Filter parameter.
- Get-CDEvent: SAC rows now carry a Sha256 property (authenticode hash) and a Details ordered hashtable with the full forensic record - Process, File, SHA256, requested/validated signing level, signer/issuer, chains-to-trusted-root, cert validity, verification error, ISG reputation, the Defender cloud-reputation check outcome (requested / performed with HTTP code / satisfied from cache), threat name (when Defender named one), Defender status code, signing scenario, file user-writeable flag, SAC policy + GUID, and CI status. RuleInfo gives the short reason (e.g. "Blocked - unsigned", "Blocked - signed by <Publisher>, untrusted").
- GUI Tab 6 (Events): 'SAC' filter option and dark-red row coloring for Smart App Control events. New Details button (and row double-click) opens a SAC block-details dialog - a selectable, read-only text box with Copy All and Copy SHA256 buttons.
- Scripts\Trace-SmartAppControl.ps1: elevated diagnostic that briefly enables the (default-off) Microsoft-Windows-CodeIntegrity/Verbose channel, captures Code Integrity image-load decisions - ALLOWS as well as blocks - for a launched app or a manual repro window, then always disables the channel again in a finally block. Lets you compare why an app is allowed (validated signing level / reputation, event 3075) against why one fails (3077/3033). The Operational log only records blocks; allows live in the Verbose channel.
- Set-CDCIVerbose [admin]: enable/disable the CodeIntegrity/Verbose channel (SAC allow logging) via the elevated pipe.
- Get-CDEvent: new -Filter SAC-Allow value that reads SAC ALLOW decisions (event 3075 "...validated <Level> signing level", enriched by 3088 per-module policy test for Smartlocker / Defender-trust / policy) from the CodeIntegrity/Verbose channel (no elevation needed to read; works even after the channel is disabled again). Rows come back as EventType 'Smart App Control (allowed)', RuleInfo 'Allowed - validated <Level>'.
- GUI Tab 6 (Events): "Log SAC Allows" toggle enables the Verbose channel (single UAC via Set-CDCIVerbose over the pipe), runs a single-shot 60s timer, and auto-disables. Then the SAC-Allow filter shows the captured allows as green rows with full Details, so you can compare in the same grid why one app was allowed against why another was blocked. (The toggle went through a couple of iterations: the first wevtutil-based enable deadlocked the elevated pipe server - fixed by switching Set-CDCIVerbose to the in-process EventLogConfiguration API - and the auto-off is a plain single-shot timer with no per-second countdown / DoEvents / FormClosing hook, which had caused an earlier loop/hang.) Scripts\Trace-SmartAppControl.ps1 does the same standalone from an elevated console.

### Changed

- Dependency: bumped the required NamedPipe module from v0.9 to v0.12 (RequiredVersion in the manifest); all current active modules track NamedPipe 0.12.
- Open-CDPipeSession: the elevated server now loads the SAME ConfigureDefender version that is running (version + module path derived at runtime from the calling module) instead of a hardcoded version, so a module bump can no longer skew the server to older code. An explicit -ModuleVersion override loads that version by name (resolved from PSModulePath, Path left null); if the running version cannot be determined and no override is given it now throws a clear error rather than spawning a server with an unresolved version.

### Security

- Set-CDExclusionPath: path validation (ValidateScript) rejecting empty input, UNC paths, invalid characters, and paths over 260 chars.
- GUI: Test-ExclusionPath validates paths chosen via the Browse file/folder dialogs before they populate the exclusion field.
- Set-CDSetting: writes an Application event-log entry (source ConfigureDefender, event 4001) on every Defender setting change for auditing.
- GUI: Write-OperationError logs full error detail to a per-day temp log and shows only a sanitized "Operation failed" message on the status bar.
- Manifest: explicit FunctionsToExport / CmdletsToExport / AliasesToExport, with VariablesToExport = '*', so the module autoloads on first command use.

### Fixed

- GUI: the entry point (ConfigureDefenderGUI.ps1) still force-imported the module with -RequiredVersion 0.2, so the 0.3 tab scripts loaded but every function call resolved to the 0.2 module. Selecting the SAC event filter called the 0.2 Get-CDEvent, whose ValidateSet is All,ASR,CFA, throwing a parameter-validation error that surfaced as an empty Events list. Pinned to 0.3.
- GUI: the exclusion-dialog Browse buttons called a non-existent Validate-ExclusionPath function; corrected to Test-ExclusionPath (browsing for an exclusion file/folder no longer throws).
- GUI: main window title showed "v0.2"; corrected to "v0.3". Replaced em/en-dash mojibake left over from the 0.2 port with ASCII hyphens in the Help window title and two comments.

## [0.2] - 2026-06-28

### Added

- ASR rule table: added C0033C00 - Block use of copied or impersonated system tools (Preview rule, not yet in stable Windows 10 release)
- Get-CDThreatDetection - returns threat detection history with human-readable fields (joins Get-MpThreatDetection + Get-MpThreat); supports Filter (All/Active/Remediated/Failed) and Since (DateTime) parameters
- GUI Tab 7: History - view detection history with filter, date range, and collapsible Resources panel; color-coded by status (active/failed/remediated/allowed)

## [0.1] - 2026-03-15

### Initial public release

**Module**
- Get-CDASRRule - returns all 16 ASR rules with current action state
- Get-CDASRExclusion - returns ASR global exclusion paths
- Get-CDExclusionProcess - returns process exclusions
- Get-CDExclusionPath - returns path exclusions
- Get-CDExclusionExtension - returns extension exclusions
- Get-CDExclusionIpAddress - returns IP address exclusions
- Get-CDControlledFolder - returns CFA protected folders
- Get-CDAllowedApplication - returns CFA allowed applications
- Get-CDControlledFolderAccess - returns CFA enable state
- Get-CDNetworkProtection - returns Network Protection state
- Get-CDSetting - returns all configurable Defender settings as structured objects
- Get-CDThreatAction - returns default action per threat severity level
- Get-CDEvent - returns ASR and CFA events from the Windows event log
- Set-CDASRRule - add, change, or remove ASR rule actions
- Set-CDASRExclusion - add or remove ASR exclusion paths
- Set-CDExclusionProcess - add or remove process exclusions
- Set-CDExclusionPath - add or remove path exclusions
- Set-CDExclusionExtension - add or remove extension exclusions
- Set-CDExclusionIpAddress - add or remove IP exclusions
- Set-CDControlledFolder - add or remove CFA protected folders
- Set-CDAllowedApplication - add, remove, or clean up CFA allowed apps
- Set-CDControlledFolderAccess - enable, audit, or disable CFA
- Set-CDNetworkProtection - enable, audit, or disable Network Protection
- Set-CDSetting - set any Defender preference setting by name
- Set-CDThreatAction - set default action per threat severity level
- Open-CDPipeSession / Close-CDPipeSession - manage the elevated NamedPipe server
- Get-CDSendRequestParam - exported accessor for the pipe session handle
- Start-ConfigureDefenderGUI - launch the WinForms GUI

**GUI**
- Tab 1: ASR Rules - view/toggle all 16 rules; collapsible ASR Exclusions panel
- Tab 2: Exclusions - unified tab with ASR / Processes / Paths / Extensions / IPs categories
- Tab 3: Controlled Folders - manage protected folders; collapsible Allowed Apps panel
- Tab 4: Settings - view and double-click edit all configurable settings
- Tab 5: Threat Actions - set default action per severity level
- Tab 6: Events - view recent ASR and CFA events with filter and date range controls; Add as Exclusion button
- Single UAC prompt per session via persistent NamedPipe elevated server
- Help window accessible from status bar
