# ConfigureDefender Module v0.1 - User Guide

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
$SRP = $script:CDSendRequestParams
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

$SRP = $script:CDSendRequestParams

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

Returns Defender events from the Windows event log. No elevation required.

```powershell
Get-CDEvents                                # all events since last boot
Get-CDEvents -Filter ASR                    # ASR events only (ID 1121)
Get-CDEvents -Filter CFA                    # CFA events only (ID 1123)
Get-CDEvents -Since (Get-Date).AddDays(-7) # last 7 days
Get-CDEvents -Like 'powershell'            # filter by process name
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `Filter` | String | All | `All`, `ASR`, or `CFA` |
| `Since` | DateTime | Last boot | Only return events after this time |
| `Like` | String | - | Wildcard filter on ProcessName |

**Output:** `PSCustomObject[]` with EventID, EventType, TimeCreated, ID, RuleInfo, Path,
ProcessName, User.

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

The GUI (`Scripts\ConfigureDefenderGUI.ps1`) uses 7 tabs. Current status:

| Tab | Controls | Status |
|-----|----------|--------|
| 1. ASR Rules | ListView + context menu | ListView populated on load; context menu TODO |
| 2. ASR Exclusions | ListBox + Add/Remove | Stub |
| 3. Controlled Folders | ListBox + Add/Remove | Stub |
| 4. Allowed Apps | ListBox + Add/Remove/RemoveMissing | Stub |
| 5. Network Protection | RadioButtons + Apply | Stub |
| 6. CFA State | RadioButtons + Apply | Stub |
| 7. Events | ListView + Filter/Refresh | ListView defined; populate TODO |

### GUI Elevation Pattern

```powershell
# On first admin button click:
Open-CDPipeSession    # UAC prompt appears once here

# On each admin operation:
$SRP = $script:CDSendRequestParams
$SRP.'DataObject' = 'Set-CDASRRule -GUID "..." -Action Blocked' |
    Send-Request @SRP -NoExitOnError
if ($SRP.'DataObject'.Error) { [System.Windows.Forms.MessageBox]::Show($SRP.'DataObject'.Error) }

# In Form.Add_FormClosing event:
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

### Get-CDEvents returns nothing
The event log query defaults to events since the last boot. Use `-Since` with an earlier
date or ensure Defender events are enabled in the local Group Policy.
