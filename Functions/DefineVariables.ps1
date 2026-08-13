#requires -Version 5.0
#
# Bootstrap variables required by the Publish-Variables mechanism
# Must be processed first so subsequent calls can use $VSScript / $VOReadOnly etc.
#
$MyVars = [Ordered]@{
	N00ConstantVars = @{
		VOConstant = @{
			Value  = 'Constant'
			Scope  = 'Script'
			Option = 'ReadOnly'
		}
	}
}
Publish-Variables -Variables $MyVars

$MyVars = [Ordered]@{
	N01BootstrapVars = @{
		VInfoOn    = @{
			Value  = $False
			Scope  = 'Script'
			Option = 'ReadOnly'
		}
		FInfoOn    = @{
			Value  = $False
			Scope  = 'Script'
			Option = 'ReadOnly'
		}
		FWInfoOn   = @{
			Value  = $False
			Scope  = 'Script'
			Option = 'ReadOnly'
		}
		VSScript   = @{
			Value  = 'Script'
			Scope  = 'Script'
			Option = 'ReadOnly'
		}
		VOReadOnly = @{
			Value  = 'ReadOnly'
			Scope  = 'Script'
			Option = 'ReadOnly'
		}
		VONone     = @{
			Value  = 'None'
			Scope  = 'Script'
			Option = 'ReadOnly'
		}
	}
}
Publish-Variables -Variables $MyVars

#
# Function export table - controls which functions are exported from the module.
# Set $true to export (public), $false to keep internal (private).
#
$script:FunctionExportTable = @{
	# Read functions - can run non-elevated or via pipe
	'Get-CDASRRules'               = $true
	'Get-CDEvents'                 = $true
	'Get-CDControlledFolders'      = $true
	'Get-CDNetworkProtection'      = $true
	'Get-CDControlledFolderAccess' = $true
	'Get-CDASRExclusions'          = $true
	'Get-CDExclusionProcesses'     = $true
	'Get-CDExclusionPaths'         = $true
	'Get-CDExclusionExtensions'    = $true
	'Get-CDExclusionIpAddresses'   = $true
	'Get-CDAllowedApplications'    = $true
	'Get-CDSettings'               = $true
	'Get-CDThreatActions'          = $true
	'Get-CDThreatDetections'       = $true
	# Write functions - must run elevated via NamedPipe
	'Set-CDASRRule'                = $true
	'Set-CDASRExclusion'           = $true
	'Set-CDExclusionProcess'       = $true
	'Set-CDExclusionPath'          = $true
	'Set-CDExclusionExtension'     = $true
	'Set-CDExclusionIpAddress'     = $true
	'Set-CDSetting'                = $true
	'Set-CDThreatAction'           = $true
	'Set-CDControlledFolder'       = $true
	'Set-CDAllowedApplication'     = $true
	'Set-CDControlledFolderAccess' = $true
	'Set-CDNetworkProtection'      = $true
	'Set-CDCIVerbose'              = $true
	# Pipe session management - GUI process only
	'Open-CDPipeSession'           = $true
	'Close-CDPipeSession'          = $true
	'Get-CDSendRequestParams'      = $true
	# GUI launcher
	'Start-ConfigureDefenderGUI'   = $true
}

#
# ASR Rules - ordered hashtable of GUID -> Description
# Source: https://docs.microsoft.com/en-us/microsoft-365/security/defender-endpoint/attack-surface-reduction-rules-reference
#
$script:ASRRules = [ordered]@{
	'01443614-cd74-433a-b99e-2ecdc07bfc25' = 'Block executable files from running unless they meet a prevalence, age, or trusted list criterion'
	'26190899-1602-49e8-8b27-eb1d0a1ce869' = 'Block Office communication application from creating child processes'
	'3b576869-a4ec-4529-8536-b80a7769e899' = 'Block Office applications from creating executable content'
	'56a863a9-875e-4185-98a7-b882c64b5ce5' = 'Block abuse of exploited vulnerable signed drivers'
	'5beb7efe-fd9a-4556-801d-275e5ffc04cc' = 'Block execution of potentially obfuscated scripts'
	'75668c1f-73b5-4cf0-bb93-3ecf5cb7cc84' = 'Block Office applications from injecting code into other processes'
	'7674ba52-37eb-4a4f-a9a1-f0f9a1619a2c' = 'Block Adobe Reader from creating child processes'
	'92e97fa1-2edf-4476-bdd6-9dd0b4dddc7b' = 'Block Win32 API calls from Office macros'
	'9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2' = 'Block credential stealing from the Windows local security authority subsystem (lsass.exe)'
	'b2b3f03d-6a65-4f7b-a9c7-1c7ef74a9ba4' = 'Block untrusted and unsigned processes that run from USB'
	'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550' = 'Block executable content from email client and webmail'
	'c1db55ab-c21a-4637-bb3f-a12568109d35' = 'Use advanced protection against ransomware'
	'd1e49aac-8f56-4280-b9ba-993a6d77406c' = 'Block process creations originating from PSExec and WMI commands'
	'd3e037e1-3eb8-44c8-a917-57927947596d' = 'Block JavaScript or VBScript from launching downloaded executable content'
	'd4f940ab-401b-4efc-aadc-ad5f3c50688a' = 'Block all Office applications from creating child processes'
	'e6db77e5-3df2-4cf1-b95a-636979351e5b' = 'Block persistence through WMI event subscription'
	# Preview rules - not yet in stable Windows 10 release
	'c0033c00-d16d-4114-a5a0-5c8d8c0b966c' = 'Block use of copied or impersonated system tools (Preview)'
}

#
# ASR action bidirectional lookup: int <-> string
# Also includes Warn (6) which is a newer action type
#
$script:ASROptions = @{
	0        = 'Disabled'
	1        = 'Blocked'
	2        = 'Audit'
	6        = 'Warn'
	Disabled = 0
	Blocked  = 1
	Audit    = 2
	Warn     = 6
}

#
# Network Protection action bidirectional lookup
#
$script:NPOptions = @{
	0        = 'Disabled'
	1        = 'Enabled'
	2        = 'Audit'
	Disabled = 0
	Enabled  = 1
	Audit    = 2
}

# Event IDs used by Defender in the event log
$script:ASREventID = '1121'
$script:CFEventID  = '1123'

# Pipe session state - stored at module scope for GUI lifetime persistence
$script:CDPipeInfo          = $null
$script:CDSendRequestParams = $null
