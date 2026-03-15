#requires -Version 5.0
Function Get-CDSettings
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
	param()

	$Pref = Get-MpPreference

	$ModeOpts = [ordered]@{ 0 = 'Disabled'; 1 = 'Enabled'; 2 = 'Audit Mode' }
	$PUAOpts = [ordered]@{ 0 = 'Disabled'; 1 = 'Enabled'; 2 = 'Audit Mode' }
	$MAPSOpts = [ordered]@{ 0 = 'Disabled'; 1 = 'Basic'; 2 = 'Advanced' }
	$SampleOpts = [ordered]@{ 0 = 'Always Prompt'; 1 = 'Send Safe Samples'; 2 = 'Never Send'; 3 = 'Send All Samples' }
	$CloudLevelOpts = [ordered]@{ 0 = 'Default'; 1 = 'Moderate'; 2 = 'High'; 4 = 'High Plus'; 6 = 'Zero Tolerance' }

	@(
		# --- Scanning ---
		[PSCustomObject]@{
			Name         = 'DisableRealtimeMonitoring'
			FriendlyName = 'Disable Real-Time Monitoring'
			Value        = $Pref.DisableRealtimeMonitoring
			Type         = 'Bool'
			Options      = $null
			Min          = $null; Max = $null
			Description  = 'Turns off real-time monitoring. Not recommended for production use.'
		}
		[PSCustomObject]@{
			Name         = 'DisableBehaviorMonitoring'
			FriendlyName = 'Disable Behavior Monitoring'
			Value        = $Pref.DisableBehaviorMonitoring
			Type         = 'Bool'
			Options      = $null
			Min          = $null; Max = $null
			Description  = 'Turns off behavior-based detection.'
		}
		[PSCustomObject]@{
			Name         = 'DisableArchiveScanning'
			FriendlyName = 'Disable Archive Scanning'
			Value        = $Pref.DisableArchiveScanning
			Type         = 'Bool'
			Options      = $null
			Min          = $null; Max = $null
			Description  = 'Skips scanning inside archive files (zip, cab, etc.).'
		}
		[PSCustomObject]@{
			Name         = 'DisableEmailScanning'
			FriendlyName = 'Disable Email Scanning'
			Value        = $Pref.DisableEmailScanning
			Type         = 'Bool'
			Options      = $null
			Min          = $null; Max = $null
			Description  = 'Skips scanning email messages and mailbox files.'
		}
		[PSCustomObject]@{
			Name         = 'DisableScriptScanning'
			FriendlyName = 'Disable Script Scanning'
			Value        = $Pref.DisableScriptScanning
			Type         = 'Bool'
			Options      = $null
			Min          = $null; Max = $null
			Description  = 'Skips scanning scripts during malware scans.'
		}
		[PSCustomObject]@{
			Name         = 'DisableIOAVProtection'
			FriendlyName = 'Disable Downloaded File Scanning (IOAV)'
			Value        = $Pref.DisableIOAVProtection
			Type         = 'Bool'
			Options      = $null
			Min          = $null; Max = $null
			Description  = 'Skips scanning all downloaded files and attachments.'
		}
		[PSCustomObject]@{
			Name         = 'DisableRemovableDriveScanning'
			FriendlyName = 'Disable Removable Drive Scanning'
			Value        = $Pref.DisableRemovableDriveScanning
			Type         = 'Bool'
			Options      = $null
			Min          = $null; Max = $null
			Description  = 'Skips scanning removable drives (USB sticks, etc.) during full scans.'
		}
		[PSCustomObject]@{
			Name         = 'DisableScanningNetworkFiles'
			FriendlyName = 'Disable Network File Scanning'
			Value        = $Pref.DisableScanningNetworkFiles
			Type         = 'Bool'
			Options      = $null
			Min          = $null; Max = $null
			Description  = 'Skips scanning network files on real-time scans.'
		}
		[PSCustomObject]@{
			Name         = 'DisableScanningMappedNetworkDrivesForFullScan'
			FriendlyName = 'Disable Mapped Drives for Full Scan'
			Value        = $Pref.DisableScanningMappedNetworkDrivesForFullScan
			Type         = 'Bool'
			Options      = $null
			Min          = $null; Max = $null
			Description  = 'Skips mapped network drives during full scans.'
		}
		[PSCustomObject]@{
			Name         = 'CheckForSignaturesBeforeRunningScan'
			FriendlyName = 'Check Signatures Before Scan'
			Value        = $Pref.CheckForSignaturesBeforeRunningScan
			Type         = 'Bool'
			Options      = $null
			Min          = $null; Max = $null
			Description  = 'Checks for updated signatures before starting a scheduled scan.'
		}
		# --- Protection ---
		[PSCustomObject]@{
			Name         = 'DisableBlockAtFirstSeen'
			FriendlyName = 'Disable Block at First Seen'
			Value        = $Pref.DisableBlockAtFirstSeen
			Type         = 'Bool'
			Options      = $null
			Min          = $null; Max = $null
			Description  = 'Disables the cloud-based block-at-first-seen feature.'
		}
		[PSCustomObject]@{
			Name         = 'DisableTamperProtection'
			FriendlyName = 'Disable Tamper Protection'
			Value        = $Pref.DisableTamperProtection
			Type         = 'Bool'
			Options      = $null
			Min          = $null; Max = $null
			Description  = 'Disables tamper protection. May require additional permissions.'
		}
		[PSCustomObject]@{
			Name         = 'EnableFileHashComputation'
			FriendlyName = 'Enable File Hash Computation'
			Value        = $Pref.EnableFileHashComputation
			Type         = 'Bool'
			Options      = $null
			Min          = $null; Max = $null
			Description  = 'Computes file hashes for all scanned files (increases CPU usage).'
		}
		[PSCustomObject]@{
			Name         = 'PUAProtection'
			FriendlyName = 'PUA Protection'
			Value        = $Pref.PUAProtection
			Type         = 'Enum'
			Options      = $PUAOpts
			Min          = $null; Max = $null
			Description  = 'Potentially Unwanted Application protection level.'
		}
		# --- Cloud / MAPS ---
		[PSCustomObject]@{
			Name         = 'MAPSReporting'
			FriendlyName = 'MAPS Reporting'
			Value        = $Pref.MAPSReporting
			Type         = 'Enum'
			Options      = $MAPSOpts
			Min          = $null; Max = $null
			Description  = 'Microsoft Active Protection Service membership level.'
		}
		[PSCustomObject]@{
			Name         = 'SubmitSamplesConsent'
			FriendlyName = 'Sample Submission Consent'
			Value        = $Pref.SubmitSamplesConsent
			Type         = 'Enum'
			Options      = $SampleOpts
			Min          = $null; Max = $null
			Description  = 'Controls whether samples are sent to Microsoft for analysis.'
		}
		[PSCustomObject]@{
			Name         = 'CloudBlockLevel'
			FriendlyName = 'Cloud Block Level'
			Value        = $Pref.CloudBlockLevel
			Type         = 'Enum'
			Options      = $CloudLevelOpts
			Min          = $null; Max = $null
			Description  = 'Aggressiveness of cloud-delivered protection blocking.'
		}
		[PSCustomObject]@{
			Name         = 'CloudExtendedTimeout'
			FriendlyName = 'Cloud Extended Timeout (seconds)'
			Value        = $Pref.CloudExtendedTimeout
			Type         = 'Int'
			Options      = $null
			Min          = 0; Max = 50
			Description  = 'Extra seconds (0-50) to block a suspicious file while the cloud analyses it.'
		}
		# --- Performance ---
		[PSCustomObject]@{
			Name         = 'EnableLowCpuPriority'
			FriendlyName = 'Enable Low CPU Priority for Scans'
			Value        = $Pref.EnableLowCpuPriority
			Type         = 'Bool'
			Options      = $null
			Min          = $null; Max = $null
			Description  = 'Runs scheduled scans at low CPU priority to reduce impact.'
		}
		[PSCustomObject]@{
			Name         = 'DisableCpuThrottleOnIdleScans'
			FriendlyName = 'Disable CPU Throttle on Idle Scans'
			Value        = $Pref.DisableCpuThrottleOnIdleScans
			Type         = 'Bool'
			Options      = $null
			Min          = $null; Max = $null
			Description  = 'Allows scans to use full CPU when the machine is idle.'
		}
		# --- Network & CFA State ---
		[PSCustomObject]@{
			Name         = 'EnableNetworkProtection'
			FriendlyName = 'Network Protection'
			Value        = $Pref.EnableNetworkProtection
			Type         = 'Enum'
			Options      = $ModeOpts
			Min          = $null; Max = $null
			Description  = 'Blocks malicious websites and content. Disabled=0, Enabled=1, Audit=2.'
		}
		[PSCustomObject]@{
			Name         = 'EnableControlledFolderAccess'
			FriendlyName = 'Controlled Folder Access'
			Value        = $Pref.EnableControlledFolderAccess
			Type         = 'Enum'
			Options      = $ModeOpts
			Min          = $null; Max = $null
			Description  = 'Protects folders from unauthorized changes. Values 3/4 (Block/Audit Disk) are read-only when active.'
		}
		# --- UI / Access ---
		[PSCustomObject]@{
			Name         = 'HideExclusionsFromLocalUsers'
			FriendlyName = 'Hide Exclusions from Local Users'
			Value        = $Pref.HideExclusionsFromLocalUsers
			Type         = 'Bool'
			Options      = $null
			Min          = $null; Max = $null
			Description  = 'Prevents non-admin users from seeing the exclusions list.'
		}
		[PSCustomObject]@{
			Name         = 'UILockdown'
			FriendlyName = 'UI Lockdown'
			Value        = $Pref.UILockdown
			Type         = 'Bool'
			Options      = $null
			Min          = $null; Max = $null
			Description  = 'Disables the Defender UI for non-admin users.'
		}
	)
}
