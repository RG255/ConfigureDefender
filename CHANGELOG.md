# Changelog

All notable changes to this project will be documented in this file.

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
