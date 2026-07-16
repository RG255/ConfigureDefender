# ConfigureDefender Module v0.3 - User Guide

<!-- CONTRIBUTOR NOTE: Do NOT use em-dashes in this file. Use a regular hyphen (-) only.
     Em-dashes cause PowerShell parser errors in string literals and may be silently
     corrupted by some editors. -->

## Overview

The ConfigureDefender module provides a PowerShell interface for managing Microsoft Defender
Attack Surface Reduction (ASR) rules, exclusions, Controlled Folder Access (CFA), Network
Protection, and event inspection.

A WinForms GUI front-end (`Scripts\ConfigureDefenderGUI.ps1`) provides a visual interface.
Write operations that require elevation are routed through a NamedPipe elevated server process.

**Key features:**
- Read current ASR rule states (all 16 known rules)
- Read and modify ASR exclusions
- Read and modify Controlled Folder Access protected folders and allowed applications
- Read and modify Network Protection state
- Inspect Defender event log (ASR and CFA violations)
- GUI front-end with elevation via NamedPipe (no UAC prompt on each action)

**Dependencies:** NamedPipe module v0.6, PowerShell 5.1+, Windows only.

## Architecture

The module splits functions into two categories based on elevation requirements:

```
GUI Process (non-elevated)                  Elevated NamedPipe Server
==========================                  =========================

Get-CDASRRules          ------direct------> Get-MpPreference (no elevation needed)
Get-CDNetworkProtection ------direct------> Get-MpPreference
Get-CDControlledFolderAccess -direct------> Get-MpPreference
Get-CDControlledFolders ------direct------> Get-MpPreference
Get-CDEvents            ------direct------> Get-WinEvent

Get-CDASRExclusions     ----via pipe------> Get-MpPreference  [admin]
Get-CDAllowedApplications ---via pipe------> Get-MpPreference  [admin]

Set-CDASRRule           ----via pipe------> Add/Remove-MpPreference  [admin]
Set-CDASRExclusion      ----via pipe------> Add/Remove-MpPreference  [admin]
Set-CDControlledFolder  ----via pipe------> Add/Remove-MpPreference  [admin]
Set-CDAllowedApplication ----via pipe-----> Add/Remove-MpPreference  [admin]
Set-CDControlledFolderAccess -via pipe----> Set-MpPreference         [admin]
Set-CDNetworkProtection ----via pipe------> Set-MpPreference         [admin]
```

The elevated server is started once on the first admin operation and persists for the
lifetime of the GUI session. The GUI calls `Open-CDPipeSession` to start it and
`Close-CDPipeSession` (in the FormClosing event) to shut it down.

## Quick Start

```powershell
Import-Module ConfigureDefender -RequiredVersion 0.1

# Read ASR rule states (no elevation)
Get-CDASRRules

# Read Network Protection state (no elevation)
Get-CDNetworkProtection

# Open an elevated session for admin operations (triggers UAC once)
Open-CDPipeSession

# Send an admin command through the pipe
$SRP = Get-CDSendRequestParams
$SRP.'DataObject' = 'Set-CDNetworkProtection -Enable' | Send-Request @SRP -NoExitOnError
$SRP.'DataObject'.Result
$SRP.'DataObject'.Error

# Close the session when done
Close-CDPipeSession
```

## Pipe Session Management

### Open-CDPipeSession

Opens the elevated NamedPipe server. Idempotent - safe to call repeatedly. If a healthy
session already exists it returns immediately without starting a new one.

```powershell
Open-CDPipeSession                  # default: loads ConfigureDefender v0.1
Open-CDPipeSession -ModuleVersion '0.1'
```

The elevated server imports the ConfigureDefender module, making all `Set-CD*` and
`Get-CD*` functions available server-side.

Session state is stored in module-scope variables:
- `$script:CDPipeInfo` - pipe connection info (used by `Test-PipeSession`)
- `$script:CDSendRequestParams` - splatting hashtable for `Send-Request`

### Close-CDPipeSession

Sends ExitPipe and disposes the pipe connection. Call this from the GUI's FormClosing event.

```powershell
Close-CDPipeSession
```

### Sending Admin Commands from the GUI

```powershell
# Ensure session is open
Open-CDPipeSession

$SRP = Get-CDSendRequestParams

# Run any exported function on the elevated server
$SRP.'DataObject' = 'Set-CDASRRule -GUID "be9ba2d9-53ea-4cdc-84e5-9b1eeee46550" -Action Blocked' |
    Send-Request @SRP -NoExitOnError

# Check result
if ($SRP.'DataObject'.Error)
{
    Write-Warning "Command failed: $($SRP.'DataObject'.Error)"
}
else
{
    $SRP.'DataObject'.Result
}
```

## Function Reference

### Get-CDASRRules

Returns all 16 known ASR rules with their current states. No elevation required.

```powershell
Get-CDASRRules
```

**Output:** `PSCustomObject[]` with properties:

| Property | Type | Description |
|----------|------|-------------|
| `GUID` | String | ASR rule GUID |
| `Action` | String | Not Set / Disabled / Audit / Blocked / Warn |
| `Description` | String | Human-readable rule name |

**Example:**
```powershell
# Show only enabled/blocked rules
Get-CDASRRules | Where-Object { $_.Action -in 'Blocked', 'Audit' } | Format-Table

# Show all not-yet-configured rules
Get-CDASRRules | Where-Object { $_.Action -eq 'Not Set' }
```

---

### Get-CDNetworkProtection

Returns the current Network Protection state. No elevation required.

```powershell
Get-CDNetworkProtection
```

**Output:** `PSCustomObject` with:

| Property | Type | Description |
|----------|------|-------------|
| `Value` | Int | 0=Disabled, 1=Enabled, 2=Audit |
| `Description` | String | Disabled / Enabled / Audit |

---

### Get-CDControlledFolderAccess

Returns the current Controlled Folder Access state. No elevation required.

```powershell
Get-CDControlledFolderAccess
```

**Output:** `PSCustomObject` with:

| Property | Type | Description |
|----------|------|-------------|
| `Value` | Int | 0=Disabled, 1=Enabled, 2=Audit, 3=BlockDiskModification, 4=AuditDiskModification |
| `Enabled` | Bool | `$true` when Value is 1 or 3 |
| `Description` | String | Human-readable state |

---

### Get-CDControlledFolders

Returns the list of Controlled Folder Access protected folders. No elevation required.

```powershell
Get-CDControlledFolders
Get-CDControlledFolders -Like 'Documents'   # wildcard filter
```

**Output:** `String[]` of folder paths.

---

### Get-CDEvents

Returns Defender **and Smart App Control (SAC)** events from the Windows event log. No elevation
required (both logs grant read to interactive users).

```powershell
Get-CDEvents                                # all events since last boot
Get-CDEvents -Filter ASR                    # ASR events only (1121 block / 1122 audit)
Get-CDEvents -Filter CFA                    # CFA events only (1123/1124/1127/1128)
Get-CDEvents -Filter SAC                    # Smart App Control events only
Get-CDEvents -Since (Get-Date).AddDays(-7) # last 7 days
Get-CDEvents -Like 'powershell'            # filter by process name
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `Filter` | String | All | `All`, `ASR`, `CFA`, `SAC` (blocks), or `SAC-Allow` (allows, from the Verbose channel) |
| `Since` | DateTime | Last boot | Only return events after this time |
| `Like` | String | - | Wildcard filter on ProcessName |

`SAC-Allow` reads Smart App Control **allow** decisions (event 3075, enriched by 3088) from
`Microsoft-Windows-CodeIntegrity/Verbose`. That channel is disabled by default, so this returns
nothing unless it was enabled during the load - use the Events tab **Log Allows** toggle (or
`Set-CDCIVerbose`) to capture, then read with this filter. Rows come back as EventType
`Smart App Control (allowed)`.

**Event sources / IDs:**

- ASR / CFA come from `Microsoft-Windows-Windows Defender/Operational` (ASR 1121/1122;
  CFA 1123/1124/1127/1128).
- SAC comes from a **different** log, `Microsoft-Windows-CodeIntegrity/Operational`: 3077 (blocked),
  3076 (audit), 3033/3034 (signing-level), with 3089 (signature details) and 3118 (Defender/ISG
  reputation) folded into the row by Correlation ActivityId. Policy-refresh events (3099) are
  intentionally excluded as noise. `\Device\HarddiskVolumeN` paths are converted to drive letters.

**Output:** `PSCustomObject[]` with `EventID`, `EventType`, `TimeCreated`, `ID`, `RuleInfo`, `Path`,
`ProcessName`, `User`. SAC rows additionally carry:

| Property | Description |
|----------|-------------|
| `Sha256` | Authenticode SHA256 of the blocked file (for allow-listing / VirusTotal) |
| `Details` | Ordered hashtable of forensic fields: Process, File, SHA256, Requested/Validated signing level, Signer/Issuer, chains-to-trusted-root, cert validity, Verification error, Reputation, **Defender cloud check** (requested / performed with HTTP code / satisfied from cache), Threat name (when named), Defender status, Signing scenario, File user-writeable, SAC policy + GUID, CI status |

`RuleInfo` for SAC gives the short reason, e.g. `Blocked - unsigned` or
`Blocked - signed by <Publisher>, untrusted`.

> **Note on "Since Boot":** SAC blocks fire when a blocked app is launched, not on every boot, so the
> default since-boot window often shows nothing. Widen `-Since` (e.g. last 7 days) to see recent blocks.

---

### Trace-SmartAppControl.ps1 (diagnostic) [admin]

`Scripts\Trace-SmartAppControl.ps1` answers "why was this app *allowed* to load, vs why did that one
fail?". Smart App Control only logs **blocks** to `Microsoft-Windows-CodeIntegrity/Operational`;
successful **allow** decisions are recorded only in `Microsoft-Windows-CodeIntegrity/Verbose`, which is
**disabled by default** and very high-volume. This helper enables that channel for a short window,
captures the decisions, then **always disables it again** (finally block). Run from an **elevated**
PowerShell.

```powershell
# Capture allow decisions while launching a known-good signed app
.\Trace-SmartAppControl.ps1 -Path 'C:\Windows\System32\notepad.exe' -Seconds 8

# Manual repro of a blocked app - launch it yourself during the capture, then diff the two
.\Trace-SmartAppControl.ps1 -Match 'Sunny Explorer' -Interactive
```

**Output:** objects with `TimeCreated, Id, Decision, Process, File, RequestedLevel, ValidatedLevel,
Publisher, Sha256, Message`. A genuine allow shows up as event **3075** with the validated signing
level / reputation that earned trust; a block is **3077/3033**. Note **3115** (in the Operational log,
always on) is a *third* case: a file that **failed** dynamic-code trust but was allowed **only because
an audit policy is active** - it reports file/process/hashes but no positive trust reason (it did not
pass on merit).

> The Verbose channel logs every image load system-wide, so keep `-Seconds` small and use `-Match`.

---

### Get-CDASRExclusions [admin]

Returns the list of paths excluded from all ASR rules. Intended to run on the elevated
server via pipe.

```powershell
# From GUI (via pipe):
'Get-CDASRExclusions' | Send-Request @SRP -NoExitOnError

# Direct (only works if already elevated):
Get-CDASRExclusions
Get-CDASRExclusions -Like 'MyApp'
```

**Output:** `String[]` of exclusion paths.

---

### Get-CDAllowedApplications [admin]

Returns the list of applications allowed to access Controlled Folders. Intended to run on
the elevated server via pipe.

```powershell
# Via pipe from GUI:
'Get-CDAllowedApplications' | Send-Request @SRP -NoExitOnError
'Get-CDAllowedApplications -CheckMissing' | Send-Request @SRP -NoExitOnError
```

**Parameters:**

| Parameter | Set | Description |
|-----------|-----|-------------|
| `Like` | List | Wildcard filter on path |
| `CheckMissing` | CheckMissing | Returns only entries whose path no longer exists on disk |

**Output:** `String[]` of application paths.

---

### Set-CDASRRule [admin]

Adds, removes, or changes ASR rule actions.

```powershell
# Change an existing rule's action
Set-CDASRRule -GUID 'be9ba2d9-...' -Action Blocked

# Add a rule (same as Change in practice)
Set-CDASRRule -GUID 'be9ba2d9-...' -Action Audit -Add

# Add all 16 known rules at once
Set-CDASRRule -AddAll -Action Audit

# Remove a specific rule
Set-CDASRRule -RemoveGUID 'be9ba2d9-...'

# Remove all configured rules
Set-CDASRRule -RemoveAll
```

**Valid Action values:** `Disabled`, `Audit`, `Blocked`, `Warn`

**Parameter sets:**

| Set | Required Params | Description |
|-----|----------------|-------------|
| Change | GUID, Action | Change an existing rule (default) |
| Add | GUID, Action, -Add | Add a rule |
| AddAll | Action, -AddAll | Add all 16 rules with the same action |
| Remove | -RemoveGUID | Remove one rule by GUID |
| RemoveAll | -RemoveAll | Remove all currently configured rules |

---

### Set-CDASRExclusion [admin]

Adds or removes an ASR exclusion path.

```powershell
Set-CDASRExclusion -Path 'C:\MyApp\'           # Add (default)
Set-CDASRExclusion -Path 'C:\MyApp\' -Remove
```

---

### Set-CDControlledFolder [admin]

Adds or removes a Controlled Folder Access protected folder.

```powershell
Set-CDControlledFolder -Folder 'C:\MyData'         # Add (default)
Set-CDControlledFolder -Folder 'C:\MyData' -Remove
```

---

### Set-CDAllowedApplication [admin]

Adds, removes, or cleans up allowed applications for Controlled Folder Access.

```powershell
Set-CDAllowedApplication -Path 'C:\MyApp\app.exe'         # Add (default)
Set-CDAllowedApplication -Path 'C:\MyApp\app.exe' -Remove
Set-CDAllowedApplication -RemoveMissing                    # Remove all entries whose paths no longer exist
```

---

### Set-CDControlledFolderAccess [admin]

Enables, audits, or disables Controlled Folder Access.

```powershell
Set-CDControlledFolderAccess -Enable   # value 1
Set-CDControlledFolderAccess -Audit    # value 2
Set-CDControlledFolderAccess -Disable  # value 0
```

---

### Set-CDNetworkProtection [admin]

Enables, audits, or disables Network Protection.

```powershell
Set-CDNetworkProtection -Enable   # value 1
Set-CDNetworkProtection -Audit    # value 2
Set-CDNetworkProtection -Disable  # value 0
```

---

## Data Structures

### ASRRules (16 entries)

Ordered hashtable mapping GUID -> description. Used internally by `Get-CDASRRules` and
`Set-CDASRRule -AddAll`. All GUIDs are lowercase.

```powershell
# Access from within the module scope:
$script:ASRRules    # ordered hashtable, 16 entries
```

### ASROptions (bidirectional)

Ordered hashtable providing int <-> string lookup for ASR action values.

```powershell
$script:ASROptions[0]          # 'Disabled'
$script:ASROptions[1]          # 'Blocked'
$script:ASROptions[2]          # 'Audit'
$script:ASROptions[6]          # 'Warn'
$script:ASROptions['Blocked']  # 1
```

### NPOptions (bidirectional)

Ordered hashtable for Network Protection state values.

```powershell
$script:NPOptions[0]         # 'Disabled'
$script:NPOptions[1]         # 'Enabled'
$script:NPOptions[2]         # 'Audit'
```

### Event IDs

```powershell
$script:ASREventID  # '1121'  - Attack Surface Reduction events
$script:CFEventID   # '1123'  - Controlled Folder Access events
```

## GUI Integration

The GUI entry point is `Scripts\ConfigureDefenderGUI.ps1`, which dot-sources 5 tab files:

| File | Contents |
|------|----------|
| `GUI-Tab-ASR.ps1` | Tab 1: ASR Rules + collapsible ASR Exclusions panel |
| `GUI-Tab-Exclusions.ps1` | Tab 2: unified Exclusions tab |
| `GUI-Tab-CFA.ps1` | Tab 3: Controlled Folders + collapsible Allowed Apps panel |
| `GUI-Tab-Settings.ps1` | Tab 4: Settings (Bool, Int, Enum) |
| `GUI-Tab-ThreatEvents.ps1` | Tabs 5-6: Threat Actions, Events |

### Tabs

| Tab | Toolbar controls | Notes |
|-----|-----------------|-------|
| 1. ASR Rules | Refresh, Select All, Set Action dropdown, Exclusions [+/-] toggle | Toggle reveals ASR Exclusions in a SplitContainer bottom panel |
| 2. Exclusions | `ASR` `Processes` `Paths` `Extensions` `IPs` category buttons, Refresh, Add, Remove, Filter | Single panel; category buttons switch which ListView is visible |
| 3. Controlled Folders | Refresh, Add, Remove, Allowed Apps [+/-] toggle | Toggle reveals Allowed Apps in a SplitContainer bottom panel |
| 4. Settings | Refresh | Double-click to edit Bool/Enum/Int settings |
| 5. Threat Actions | Refresh | Double-click to edit action per severity |
| 6. Events | Refresh, Add Exclusion, Details, Filter (type/since/date) | Read-only ASR/CFA/SAC event view. Type filter includes `SAC` (blocks, red) and `SAC-Allow` (allows, green). For a SAC row, click **Details** (or double-click) to open the block-details dialog: a selectable read-only text box showing reason, SHA256, requested/validated signing level, signer, reputation and SAC policy, with **Copy All** and **Copy SHA256**. To view *allow* decisions, first capture them with `Scripts\Trace-SmartAppControl.ps1` (elevated) or `Set-CDCIVerbose`, then pick the `SAC-Allow` filter and Refresh |
| 7. History | Refresh, Filter (status/since/date) | Threat detection history |

### Exclusions tab - category switching

The Exclusions tab uses a single toolbar and a shared Panel. All 5 ListViews exist simultaneously;
only the active category's ListView has `Visible = $true`. The `Switch-ExclCategory` function
manages visibility, checked state of category buttons, and lazy-loading.

```powershell
Switch-ExclCategory 'ASR'    # show ASR Exclusions ListView, load if cache empty
Switch-ExclCategory 'Proc'   # show Processes ListView
Switch-ExclCategory 'Path'   # show Paths ListView
Switch-ExclCategory 'Ext'    # show Extensions ListView
Switch-ExclCategory 'IP'     # show IPs ListView
```

### Auto-refresh and loading indicator

Tabs lazy-load on first visit. `TabControl.Add_SelectedIndexChanged` fires the appropriate
Refresh button for the newly selected tab. Each Refresh handler shows the hourglass cursor and
sets `StatusLabel.Text = 'Loading...'` before the blocking call, then restores in `finally`.

```powershell
$Form.UseWaitCursor = $true
[System.Windows.Forms.Application]::DoEvents()   # flush UI before blocking
try { ... }
finally { $Form.UseWaitCursor = $false }
```

### Empty list placeholder

Every ListView calls `Add-EmptyPlaceholder` after populating. If the list is empty a gray
`(nothing configured)` item is added with `Tag = '$placeholder'`. All Remove/DoubleClick
handlers check `$Li.Tag -ne '$placeholder'` before acting.

### GUI Elevation Pattern

```powershell
# On first admin button click (Get-CDSRP opens session automatically):
$SRP = Get-CDSRP    # opens pipe if not already open; UAC prompt appears once

# On each admin operation:
$SRP.DataObject = 'Set-CDASRRule -GUID "..." -Action Blocked' |
    Send-Request @SRP -NoExitOnError
if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" }

# In Form.Add_FormClosing event (already wired in main file):
Close-CDPipeSession
```

## Running the Tests

```powershell
# From the module directory:
Invoke-Pester -Path .\Tests\ConfigureDefender.Tests.ps1 -Output Detailed
```

Tests do not require elevation and do not modify Defender configuration.
All Defender cmdlets (`Get-MpPreference`, `Set-MpPreference`, `Add-MpPreference`,
`Remove-MpPreference`) are mocked.

## MpPreference Properties Not Implemented

The following `Get-MpPreference` properties are intentionally not exposed in this module.
The decision was made after reviewing all properties available on Windows 10 Pro.

### Handled elsewhere in the module (not duplicated in Settings tab)

| Property | Handled by |
|----------|-----------|
| `AttackSurfaceReductionRules_Ids` / `_Actions` | ASR Rules tab |
| `AttackSurfaceReductionOnlyExclusions` | ASR Exclusions panel (ASR tab) |
| `ExclusionPath`, `ExclusionProcess`, `ExclusionExtension`, `ExclusionIpAddress` | Exclusions tab |
| `ControlledFolderAccessProtectedFolders` | Controlled Folders tab |
| `ControlledFolderAccessAllowedApplications` | Allowed Apps panel (CFA tab) |
| `EnableControlledFolderAccess`, `EnableNetworkProtection` | Settings tab (also CFA/Network tabs) |
| `HighThreatDefaultAction`, `LowThreatDefaultAction`, `ModerateThreatDefaultAction`, `SevereThreatDefaultAction`, `UnknownThreatDefaultAction` | Threat Actions tab |
| `ThreatIDDefaultAction_Ids` / `_Actions` | Threat Actions tab (per-threat-ID) |

### Scan scheduling - not implemented (complexity vs. benefit)

Scheduling is better managed via Task Scheduler. These properties control scan day/time,
catchup behaviour, and CPU limits during scheduled runs - useful but low priority for a
security-focused tool.

`ScanScheduleDay`, `ScanScheduleTime`, `ScanScheduleOffset`, `ScanScheduleQuickScanTime`,
`RandomizeScheduleTaskTimes`, `SchedulerRandomizationTime`, `ScanOnlyIfIdleEnabled`,
`ScanAvgCPULoadFactor`, `EnableFullScanOnBatteryPower`, `ThrottleForScheduledScanOnly`,
`DisableCatchupFullScan`, `DisableCatchupQuickScan`, `RemediationScheduleDay`,
`RemediationScheduleTime`, `ScanPurgeItemsAfterDelay`, `QuarantinePurgeItemsAfterDelay`

### Signature / update settings - not implemented (leave at defaults)

Signature update settings are rarely changed outside enterprise environments and are best
left at defaults or managed via WSUS/Intune.

`SignatureUpdateInterval`, `SignatureUpdateCatchupInterval`, `SignatureScheduleDay`,
`SignatureScheduleTime`, `SignatureFallbackOrder`, `SignatureAuGracePeriod`,
`SignatureFirstAuGracePeriod`, `SignatureDisableUpdateOnStartupWithoutEngine`,
`SignatureBlobUpdateInterval`, `SignatureBlobFileSharesSources`,
`SignatureDefinitionUpdateFileSharesSources`, `SharedSignaturesPath`,
`SharedSignaturesPathUpdateAtScheduledTimeOnly`, `DefinitionUpdatesChannel`,
`EngineUpdatesChannel`, `PlatformUpdatesChannel`, `DisableGradualRelease`,
`MeteredConnectionUpdates`

### Network protocol parsers - not implemented (too specialised)

These disable Defender's deep-packet inspection for specific protocols. Relevant only in
specific enterprise/server scenarios where Defender interferes with application traffic.
Disabling them weakens protection.

`DisableDnsParsing`, `DisableDnsOverTcpParsing`, `DisableFtpParsing`, `DisableHttpParsing`,
`DisableSmtpParsing`, `DisableSshParsing`, `DisableTlsParsing`, `DisableRdpParsing`,
`DisableQuicParsing`, `DisableDatagramProcessing`, `DisableInboundConnectionFiltering`,
`ApplyDisableNetworkScanningToIOAV`, `AllowSwitchToAsyncInspection`

### Server-specific - not applicable on Windows 10 workstation

`AllowNetworkProtectionOnWinServer`, `AllowNetworkProtectionDownLevel`,
`AllowDatagramProcessingOnWinServer`

### Proxy settings - not implemented (separate concern)

Proxy configuration is a network/OS-level setting, not Defender-specific.
`ProxyServer`, `ProxyBypass`, `ForceUseProxyOnly`, `ProxyPacUrl`

### Newer/specialist features - not implemented yet (potential future work)

These were added in later Windows 10/11 builds and cover newer attack surface scenarios.
Could be added in a future version if needed.

| Property group | Description |
|----------------|-------------|
| `BruteForceProtectionConfiguredState`, `BruteForceProtectionAggressiveness`, `BruteForceProtectionMaxBlockTime`, `BruteForceProtectionLocalNetworkBlocking`, `BruteForceProtectionSkipLearningPeriod`, `BruteForceProtectionExclusions` | Brute-force attack blocking (requires supported Windows build) |
| `RemoteEncryptionProtectionConfiguredState`, `RemoteEncryptionProtectionAggressiveness`, `RemoteEncryptionProtectionMaxBlockTime`, `RemoteEncryptionProtectionExclusions` | Ransomware/remote encryption protection |
| `NetworkProtectionReputationMode` | Granular reputation-based network protection mode |
| `AttackSurfaceReductionRules_RuleSpecificExclusions`, `AttackSurfaceReductionRules_RuleSpecificExclusions_Id` | Per-rule ASR exclusions (as opposed to global ASR exclusions) |
| `EnableConvertWarnToBlock` | Converts all ASR Warn-mode rules to Block automatically |
| `EnableDnsSinkhole` | DNS sinkhole for Network Protection |
| `IntelTDTEnabled` | Intel Threat Detection Technology integration |

### Internal / telemetry / read-only - not implemented (no user value)

`ComputerID`, `PSComputerName`, `DisableCacheMaintenance`, `DisableCoreServiceECSIntegration`,
`DisableCoreServiceTelemetry`, `DisableNetworkProtectionPerfTelemetry`, `DisablePrivacyMode`,
`ReportDynamicSignatureDroppedEvent`, `ReportingAdditionalActionTimeOut`,
`ReportingCriticalFailureTimeOut`, `ReportingNonCriticalTimeOut`, `ServiceHealthReportInterval`,
`RemoveScanningThreadPoolCap`, `EnableUdpReceiveOffload`, `EnableUdpSegmentationOffload`,
`OobeEnableRtpAndSigUpdate`, `ControlledFolderAccessDefaultProtectedFolders` (read-only Windows defaults)

### Implemented but worth noting

`DisableAutoExclusions` (not in Settings tab) - disables the automatic exclusions Defender
adds for server roles. Relevant only on Windows Server; omitted on workstation.
`DisableRestorePoint` - disables creation of a restore point before remediation. Omitted
as restore point behaviour is better controlled via System Protection settings.
`QuickScanIncludeExclusions`, `RealTimeScanDirection`, `ScanParameters`,
`PerformanceModeStatus`, `TrustLabelProtectionStatus` - these were reviewed and considered
either redundant, read-only in practice, or applicable only to specific scenarios.

---

### Get-CDExclusionProcesses [admin]

Returns the list of processes excluded from Defender scanning. Intended to run on the elevated server via pipe.

```powershell
Get-CDExclusionProcesses
Get-CDExclusionProcesses -Like 'myapp'
```

**Output:** `String[]` of process names or paths.

---

### Get-CDExclusionPaths [admin]

Returns the list of file/folder paths excluded from Defender scanning.

```powershell
Get-CDExclusionPaths
Get-CDExclusionPaths -Like 'C:\MyApp'
```

**Output:** `String[]` of excluded paths.

---

### Get-CDExclusionExtensions [admin]

Returns the list of file extensions excluded from Defender scanning.

```powershell
Get-CDExclusionExtensions
Get-CDExclusionExtensions -Like 'log'
```

**Output:** `String[]` of excluded extensions (e.g. `.log`, `.tmp`).

---

### Get-CDExclusionIpAddresses [admin]

Returns the list of IP addresses excluded from Network Protection.

```powershell
Get-CDExclusionIpAddresses
Get-CDExclusionIpAddresses -Like '192.168'
```

**Output:** `String[]` of excluded IP addresses.

---

### Get-CDSettings

Returns all configurable Defender settings as structured objects for display and editing. No elevation required for reading.

```powershell
Get-CDSettings
Get-CDSettings | Where-Object Type -eq 'Bool' | Format-Table Name, FriendlyName, Value
```

**Output:** `PSCustomObject[]` with properties:

| Property | Type | Description |
|----------|------|-------------|
| `Name` | String | MpPreference property name (used with `Set-CDSetting`) |
| `FriendlyName` | String | Human-readable label |
| `Value` | varies | Current raw value |
| `Type` | String | `Bool`, `Enum`, or `Int` |
| `Options` | OrderedDictionary | For Enum: int -> string label mapping |
| `Min` / `Max` | Int | For Int: valid range |
| `Description` | String | Tooltip/help text |

Covers scanning, protection, cloud/MAPS, performance, network, and UI settings.

---

### Get-CDThreatActions

Returns the default remediation action for each threat severity level. No elevation required.

```powershell
Get-CDThreatActions
```

**Output:** `PSCustomObject[]` with Level, Property, Value (int), Action (string) for Severe, High, Moderate, Low, Unknown.

Valid Action strings: `Clean`, `Quarantine`, `Remove`, `Allow`, `UserDefined`, `NoAction`, `Block`.

---

### Get-CDSendRequestParams

Returns the `SendRequestParams` hashtable for the current elevated session, or `$null` if no session has been opened. Use this instead of `$Mod.Invoke({ $script:CDSendRequestParams })`.

```powershell
$SRP = Get-CDSendRequestParams
```

---

### Set-CDExclusionProcess [admin]

Adds or removes a process exclusion.

```powershell
Set-CDExclusionProcess -Process 'myapp.exe'          # Add (default)
Set-CDExclusionProcess -Process 'myapp.exe' -Remove
```

---

### Set-CDExclusionPath [admin]

Adds or removes a file/folder path exclusion.

```powershell
Set-CDExclusionPath -Path 'C:\MyApp\'          # Add (default)
Set-CDExclusionPath -Path 'C:\MyApp\' -Remove
```

---

### Set-CDExclusionExtension [admin]

Adds or removes a file extension exclusion.

```powershell
Set-CDExclusionExtension -Extension '.log'          # Add (default)
Set-CDExclusionExtension -Extension '.log' -Remove
```

---

### Set-CDExclusionIpAddress [admin]

Adds or removes an IP address exclusion from Network Protection.

```powershell
Set-CDExclusionIpAddress -IpAddress '192.168.1.100'          # Add (default)
Set-CDExclusionIpAddress -IpAddress '192.168.1.100' -Remove
```

---

### Set-CDSetting [admin]

Sets a single Defender preference setting by its MpPreference property name.

```powershell
Set-CDSetting -Name 'DisableRealtimeMonitoring' -Value $false
Set-CDSetting -Name 'CloudBlockLevel'           -Value 2
Set-CDSetting -Name 'CloudExtendedTimeout'      -Value 10
```

Use `Get-CDSettings` to discover valid property names and their types.

---

### Set-CDThreatAction [admin]

Sets the default remediation action for a threat severity level.

```powershell
Set-CDThreatAction -Level Severe   -Action Quarantine
Set-CDThreatAction -Level High     -Action Quarantine
Set-CDThreatAction -Level Moderate -Action Quarantine
Set-CDThreatAction -Level Low      -Action Clean
Set-CDThreatAction -Level Unknown  -Action Quarantine
```

**Valid Level values:** `Severe`, `High`, `Moderate`, `Low`, `Unknown`

**Valid Action values:** `Clean`, `Quarantine`, `Remove`, `Allow`, `UserDefined`, `NoAction`, `Block`

---

### Start-ConfigureDefenderGUI

Launches the ConfigureDefender WinForms GUI.

```powershell
Import-Module ConfigureDefender
Start-ConfigureDefenderGUI
```

Resolves the GUI entry point from the module's installed location. The GUI provides a tabbed interface for all read and write operations without needing to use the functions directly.

---

## Troubleshooting

### "Start-PipeSession: Access is denied"
Elevation failed. Ensure the account has admin rights and UAC is not blocked by policy.

### Set-CD* commands return errors but do not throw
When using `Send-Request @SRP -NoExitOnError`, errors are returned in
`$SRP.'DataObject'.Error` rather than thrown. Always check `.Error` after pipe commands.

### Pipe session drops mid-session
Call `Open-CDPipeSession` before each admin operation - it is idempotent and will reopen
a dropped session transparently.

### "Module not found" in elevated server
Ensure ConfigureDefender is deployed to a path in `$env:PSModulePath` (e.g.
`L:\OneDrive\Documents\WindowsPowerShell\Modules\ConfigureDefender\0.1\`).

### Get-CDEvents returns nothing (or the Events tab / SAC filter is empty)
The event log query defaults to events since the last boot. Use `-Since` with an earlier
date or ensure Defender events are enabled in the local Group Policy. This bites the **SAC**
filter especially: SAC blocks only fire when a blocked app is launched, not on every boot, so
"Since Boot" is frequently empty even when there are many recent blocks. Select **Last 7 Days**
or **Last 30 Days** in the Since dropdown.
