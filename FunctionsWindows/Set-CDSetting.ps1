#requires -Version 5.0
Function Set-CDSetting
{
	<#
		.SYNOPSIS
		Sets a single Defender preference setting by name.

		.DESCRIPTION
		Requires elevation - intended to run in the elevated NamedPipe server process.
		Uses Set-MpPreference with a dynamic parameter name so all settings can be
		changed via a single function.

		.PARAMETER Name
		The MpPreference property name (e.g. 'DisableRealtimeMonitoring'). Only the settings Get-CDSetting offers (and the
		Settings tab shows) are accepted; any other name is rejected before anything is sent to Defender. Keep this list in
		step with Get-CDSetting (a test compares them).

		.PARAMETER Value
		The value to set. Pass $true/$false for Bool settings, an integer for Enum
		or Int settings.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
		Justification = 'Set-CDSetting writes a single Defender preference - state change is the explicit purpose of this function.')]
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateSet(
			'DisableRealtimeMonitoring', 'DisableBehaviorMonitoring', 'DisableArchiveScanning', 'DisableEmailScanning',
			'DisableScriptScanning', 'DisableIOAVProtection', 'DisableRemovableDriveScanning', 'DisableScanningNetworkFiles',
			'DisableScanningMappedNetworkDrivesForFullScan', 'CheckForSignaturesBeforeRunningScan', 'DisableBlockAtFirstSeen',
			'DisableTamperProtection', 'EnableFileHashComputation', 'PUAProtection', 'MAPSReporting', 'SubmitSamplesConsent',
			'CloudBlockLevel', 'CloudExtendedTimeout', 'EnableLowCpuPriority', 'DisableCpuThrottleOnIdleScans',
			'EnableNetworkProtection', 'EnableControlledFolderAccess', 'HideExclusionsFromLocalUsers', 'UILockdown')]
		[string]$Name,

		[Parameter(Mandatory)]
		$Value
	)

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	try
	{
		# A request string reaches this function as text, and a [bool] Set-MpPreference parameter rejects the
		# strings '$true' / 'true' - turn them into real booleans. Other values (integers, enums) pass through.
		if ($Value -is [string] -and $Value -match '^\s*\$?(true|false)\s*$')
		{ $Value = ($Matches[1] -eq 'true') }
		$Params = @{ $Name = $Value }
		# -ErrorAction Stop: Set-MpPreference failures can be non-terminating, which the catch would never
		# see, and the audit entry below would then report a change that never happened.
		Set-MpPreference @Params -ErrorAction Stop

		# Read it back. With Tamper Protection on (or a policy in force) Set-MpPreference returns with NO error and
		# changes nothing - a direct elevated Set-MpPreference does exactly that - so a call that did not throw proves
		# nothing. If the value did not stick, say so instead of reporting success. A property that is absent from the
		# preference object cannot be checked and stays quiet; a value that is present but cannot be COMPARED is reported
		# as unconfirmed, never assumed to match.
		$Pref = Get-MpPreference -ErrorAction Stop
		if ($Pref.PSObject.Properties[$Name])
		{
			$After        = $Pref.$Name
			$Same         = $false
			$CompareError = $null
			try
			{
				if ($Value -is [bool])      { $Same = ([bool]$After -eq $Value) }
				elseif ($Value -is [ValueType]) { $Same = ([int64]$After -eq [int64]$Value) }   # integers and enums
				else                        { $Same = ([string]$After -eq [string]$Value) }
			}
			catch { $CompareError = $_.Exception.Message }
			if ($CompareError)
			{ throw ("Defender accepted the command but {0} could not be confirmed: its value ('{1}') could not be compared with '{2}' ({3})." -f $Name, $After, $Value, $CompareError) }
			if (-not $Same)
			{ throw ("Defender accepted the command but {0} is still '{1}' (wanted '{2}'). Tamper Protection or a policy is probably blocking the change." -f $Name, $After, $Value) }
		}
	}
	catch
	{
		Write-MyCatchAudit -Source 'Set-CDSetting: writing Defender preference' -ErrorRecord $_
		throw
	}

	try
	{
		# Write-EventLog does not exist in PowerShell 7, and the ConfigureDefender source was never registered, so
		# this audit entry has not been written on either host. Write-CDAuditEvent works on both.
		Write-CDAuditEvent -EventId 4001 -Message "Defender setting updated: $Name = $Value"
	}
	catch
	{
		Write-MyCatchAudit -Source 'Set-CDSetting: audit EventLog write' -ErrorRecord $_
	}
}
