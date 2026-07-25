# Changelog

All notable changes to this project will be documented in this file.

## [0.3] - 2026-07-14

### Added

- Get-CDEvents: Smart App Control / App Control event support. Reads the Microsoft-Windows-CodeIntegrity/Operational log (event IDs 3077 block, 3076 audit, 3033/3034 signing-level, 3089 signature details, 3118 Defender/ISG reputation) in addition to the Defender ASR/CFA events. Events describing one load attempt are grouped by Correlation ActivityId into a single row; \Device\HarddiskVolumeN paths are converted to drive letters. New 'SAC' value for the -Filter parameter.
- Get-CDEvents: SAC rows now carry a Sha256 property (authenticode hash) and a Details ordered hashtable with the full forensic record - Process, File, SHA256, requested/validated signing level, signer/issuer, chains-to-trusted-root, cert validity, verification error, ISG reputation, the Defender cloud-reputation check outcome (requested / performed with HTTP code / satisfied from cache), threat name (when Defender named one), Defender status code, signing scenario, file user-writeable flag, SAC policy + GUID, and CI status. RuleInfo gives the short reason (e.g. "Blocked - unsigned", "Blocked - signed by <Publisher>, untrusted").
- GUI Tab 6 (Events): 'SAC' filter option and dark-red row coloring for Smart App Control events. New Details button (and row double-click) opens a SAC block-details dialog - a selectable, read-only text box with Copy All and Copy SHA256 buttons.
- Scripts\Trace-SmartAppControl.ps1: elevated diagnostic that briefly enables the (default-off) Microsoft-Windows-CodeIntegrity/Verbose channel, captures Code Integrity image-load decisions - ALLOWS as well as blocks - for a launched app or a manual repro window, then always disables the channel again in a finally block. Lets you compare why an app is allowed (validated signing level / reputation, event 3075) against why one fails (3077/3033). The Operational log only records blocks; allows live in the Verbose channel.
- Set-CDCIVerbose [admin]: enable/disable the CodeIntegrity/Verbose channel (SAC allow logging) via the elevated pipe.
- Get-CDEvents: new -Filter SAC-Allow value that reads SAC ALLOW decisions (event 3075 "...validated <Level> signing level", enriched by 3088 per-module policy test for Smartlocker / Defender-trust / policy) from the CodeIntegrity/Verbose channel (no elevation needed to read; works even after the channel is disabled again). Rows come back as EventType 'Smart App Control (allowed)', RuleInfo 'Allowed - validated <Level>'.
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

- GUI: the entry point (ConfigureDefenderGUI.ps1) still force-imported the module with -RequiredVersion 0.2, so the 0.3 tab scripts loaded but every function call resolved to the 0.2 module. Selecting the SAC event filter called the 0.2 Get-CDEvents, whose ValidateSet is All,ASR,CFA, throwing a parameter-validation error that surfaced as an empty Events list. Pinned to 0.3.
- GUI: the exclusion-dialog Browse buttons called a non-existent Validate-ExclusionPath function; corrected to Test-ExclusionPath (browsing for an exclusion file/folder no longer throws).
- GUI: main window title showed "v0.2"; corrected to "v0.3". Replaced em/en-dash mojibake left over from the 0.2 port with ASCII hyphens in the Help window title and two comments.

## [0.2] - 2026-06-28

### Added

- ASR rule table: added C0033C00 - Block use of copied or impersonated system tools (Preview rule, not yet in stable Windows 10 release)
- Get-CDThreatDetections - returns threat detection history with human-readable fields (joins Get-MpThreatDetection + Get-MpThreat); supports Filter (All/Active/Remediated/Failed) and Since (DateTime) parameters
- GUI Tab 7: History - view detection history with filter, date range, and collapsible Resources panel; color-coded by status (active/failed/remediated/allowed)

## [0.1] - 2026-03-15

### Initial public release

**Module**
- Get-CDASRRules - returns all 16 ASR rules with current action state
- Get-CDASRExclusions - returns ASR global exclusion paths
- Get-CDExclusionProcesses - returns process exclusions
- Get-CDExclusionPaths - returns path exclusions
- Get-CDExclusionExtensions - returns extension exclusions
- Get-CDExclusionIpAddresses - returns IP address exclusions
- Get-CDControlledFolders - returns CFA protected folders
- Get-CDAllowedApplications - returns CFA allowed applications
- Get-CDControlledFolderAccess - returns CFA enable state
- Get-CDNetworkProtection - returns Network Protection state
- Get-CDSettings - returns all configurable Defender settings as structured objects
- Get-CDThreatActions - returns default action per threat severity level
- Get-CDEvents - returns ASR and CFA events from the Windows event log
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
- Get-CDSendRequestParams - exported accessor for the pipe session handle
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
