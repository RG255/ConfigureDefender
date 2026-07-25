# ConfigureDefender

A PowerShell module for managing Microsoft Defender configuration on Windows 10/11.

## Features

- View and toggle all 16 Attack Surface Reduction (ASR) rules
- Manage ASR, path, process, extension, and IP exclusions
- Manage Controlled Folder Access protected folders and allowed applications
- Configure Network Protection, cloud protection, and scanning settings
- Set default remediation actions per threat severity level
- View recent ASR, CFA, and Smart App Control (SAC) events from the Windows event logs, with a
  per-event block-details view (reason, SHA256, signing level, signer, reputation, SAC policy)
- View threat detection history
- WinForms GUI front-end - no PowerShell experience required
- Write operations routed through a persistent elevated NamedPipe server (single UAC prompt per session)

## Requirements

- Windows 10 / Windows 11
- Windows PowerShell 5.1
- [NamedPipe module v0.12](https://github.com/RG255/NamedPipe)

## Installation

1. Install the NamedPipe module (required dependency).
2. Copy the `ConfigureDefender\0.3` folder to a path in `$env:PSModulePath`, e.g.:
   ```
   %USERPROFILE%\Documents\WindowsPowerShell\Modules\ConfigureDefender\0.3\
   ```
3. Import and launch:
   ```powershell
   Import-Module ConfigureDefender
   Start-ConfigureDefenderGUI
   ```

## Usage

### GUI

```powershell
Import-Module ConfigureDefender
Start-ConfigureDefenderGUI
```

The GUI opens a tabbed window. The first admin operation triggers a single UAC prompt to start the elevated service; all subsequent operations in the same session reuse that connection.

### Command line

```powershell
Import-Module ConfigureDefender

# Read operations - no elevation needed
Get-CDASRRules
Get-CDNetworkProtection
Get-CDSettings
Get-CDEvents -Filter ASR -Since (Get-Date).AddDays(-7)

# Write operations - elevation required (triggers UAC once)
Open-CDPipeSession
$SRP = Get-CDSendRequestParams
$SRP.'DataObject' = 'Set-CDNetworkProtection -Enable' | Send-Request @SRP -NoExitOnError
Close-CDPipeSession
```

## Documentation

See [Docs/USERGUIDE.md](Docs/USERGUIDE.md) for the full function reference, architecture notes, GUI integration details, and troubleshooting guide.

## License

MIT - see [LICENSE](LICENSE).
