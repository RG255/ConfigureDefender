#requires -Version 5.0
Function Get-CDSetting
{
	<#
		.SYNOPSIS
		Returns Defender preference settings as structured objects for display and editing.

		.DESCRIPTION
		Returns an array of PSCustomObjects, each with:
		  Name        - MpPreference property name (used with Set-CDSetting)
		  FriendlyName- Display label
		  Value       - Current raw value
		  Type        - 'Bool', 'Enum', or 'Int'
		  Options     - For Enum: ordered hashtable of int -> string label
		  Min/Max     - For Int: range
		  Description - Tooltip/help text
	#>
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	param()

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	try
	{
		$Pref = Get-MpPreference

		$ModeOpts = [ordered]@{ 0 = 'Disabled'; 1 = 'Enabled'; 2 = 'Audit Mode' }
		$PUAOpts = [ordered]@{ 0 = 'Disabled'; 1 = 'Enabled'; 2 = 'Audit Mode' }
		$MAPSOpts = [ordered]@{ 0 = 'Disabled'; 1 = 'Basic'; 2 = 'Advanced' }
		$SampleOpts = [ordered]@{ 0 = 'Always Prompt'; 1 = 'Send Safe Samples'; 2 = 'Never Send'; 3 = 'Send All Samples' }
		$CloudLevelOpts = [ordered]@{ 0 = 'Default'; 1 = 'Moderate'; 2 = 'High'; 4 = 'High Plus'; 6 = 'Zero Tolerance' }

		# One row per setting instead of 24 near-identical 9-line object literals.
		#   N   = MpPreference property name (also the -Name that Set-CDSetting takes)
		#   F   = label shown in the GUI          T = 'Bool' | 'Enum' | 'Int'
		#   O   = option table for an Enum        Min / Max = range for an Int
		#   D   = help text
		# The objects returned are exactly the same as before: Name, FriendlyName, Value, Type, Options, Min, Max, Description.
		$Defs = @(
			@{ N = 'DisableRealtimeMonitoring'; F = 'Disable Real-Time Monitoring'; T = 'Bool'; D = 'Turns off real-time monitoring. Not recommended for production use.' }
			@{ N = 'DisableBehaviorMonitoring'; F = 'Disable Behavior Monitoring'; T = 'Bool'; D = 'Turns off behavior-based detection.' }
			@{ N = 'DisableArchiveScanning'; F = 'Disable Archive Scanning'; T = 'Bool'; D = 'Skips scanning inside archive files (zip, cab, etc.).' }
			@{ N = 'DisableEmailScanning'; F = 'Disable Email Scanning'; T = 'Bool'; D = 'Skips scanning email messages and mailbox files.' }
			@{ N = 'DisableScriptScanning'; F = 'Disable Script Scanning'; T = 'Bool'; D = 'Skips scanning scripts during malware scans.' }
			@{ N = 'DisableIOAVProtection'; F = 'Disable Downloaded File Scanning (IOAV)'; T = 'Bool'; D = 'Skips scanning all downloaded files and attachments.' }
			@{ N = 'DisableRemovableDriveScanning'; F = 'Disable Removable Drive Scanning'; T = 'Bool'; D = 'Skips scanning removable drives (USB sticks, etc.) during full scans.' }
			@{ N = 'DisableScanningNetworkFiles'; F = 'Disable Network File Scanning'; T = 'Bool'; D = 'Skips scanning network files on real-time scans.' }
			@{ N = 'DisableScanningMappedNetworkDrivesForFullScan'; F = 'Disable Mapped Drives for Full Scan'; T = 'Bool'; D = 'Skips mapped network drives during full scans.' }
			@{ N = 'CheckForSignaturesBeforeRunningScan'; F = 'Check Signatures Before Scan'; T = 'Bool'; D = 'Checks for updated signatures before starting a scheduled scan.' }
			@{ N = 'DisableBlockAtFirstSeen'; F = 'Disable Block at First Seen'; T = 'Bool'; D = 'Disables the cloud-based block-at-first-seen feature.' }
			@{ N = 'DisableTamperProtection'; F = 'Disable Tamper Protection'; T = 'Bool'; D = 'Disables tamper protection. May require additional permissions.' }
			@{ N = 'EnableFileHashComputation'; F = 'Enable File Hash Computation'; T = 'Bool'; D = 'Computes file hashes for all scanned files (increases CPU usage).' }
			@{ N = 'PUAProtection'; F = 'PUA Protection'; T = 'Enum'; O = $PUAOpts; D = 'Potentially Unwanted Application protection level.' }
			@{ N = 'MAPSReporting'; F = 'MAPS Reporting'; T = 'Enum'; O = $MAPSOpts; D = 'Microsoft Active Protection Service membership level.' }
			@{ N = 'SubmitSamplesConsent'; F = 'Sample Submission Consent'; T = 'Enum'; O = $SampleOpts; D = 'Controls whether samples are sent to Microsoft for analysis.' }
			@{ N = 'CloudBlockLevel'; F = 'Cloud Block Level'; T = 'Enum'; O = $CloudLevelOpts; D = 'Aggressiveness of cloud-delivered protection blocking.' }
			@{ N = 'CloudExtendedTimeout'; F = 'Cloud Extended Timeout (seconds)'; T = 'Int'; Min = 0; Max = 50; D = 'Extra seconds (0-50) to block a suspicious file while the cloud analyses it.' }
			@{ N = 'EnableLowCpuPriority'; F = 'Enable Low CPU Priority for Scans'; T = 'Bool'; D = 'Runs scheduled scans at low CPU priority to reduce impact.' }
			@{ N = 'DisableCpuThrottleOnIdleScans'; F = 'Disable CPU Throttle on Idle Scans'; T = 'Bool'; D = 'Allows scans to use full CPU when the machine is idle.' }
			@{ N = 'EnableNetworkProtection'; F = 'Network Protection'; T = 'Enum'; O = $ModeOpts; D = 'Blocks malicious websites and content. Disabled=0, Enabled=1, Audit=2.' }
			@{ N = 'EnableControlledFolderAccess'; F = 'Controlled Folder Access'; T = 'Enum'; O = $ModeOpts; D = 'Protects folders from unauthorized changes. Values 3/4 (Block/Audit Disk) are read-only when active.' }
			@{ N = 'HideExclusionsFromLocalUsers'; F = 'Hide Exclusions from Local Users'; T = 'Bool'; D = 'Prevents non-admin users from seeing the exclusions list.' }
			@{ N = 'UILockdown'; F = 'UI Lockdown'; T = 'Bool'; D = 'Disables the Defender UI for non-admin users.' }
		)

		foreach ($Def in $Defs)
		{
			[PSCustomObject]@{
				Name         = $Def.N
				FriendlyName = $Def.F
				Value        = $Pref.($Def.N)
				Type         = $Def.T
				Options      = $Def.O
				Min          = $Def.Min
				Max          = $Def.Max
				Description  = $Def.D
			}
		}	}
	catch
	{
		Write-MyCatchAudit -Source 'Get-CDSetting: querying Defender preference settings' -ErrorRecord $_
		throw
	}
}
