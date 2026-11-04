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
		The MpPreference property name (e.g. 'DisableRealtimeMonitoring').

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
		# nothing. If the value did not stick, say so instead of reporting success. When the value cannot be compared
		# (property absent, odd type) this stays quiet rather than raise a false alarm.
		$Pref = Get-MpPreference -ErrorAction Stop
		if ($Pref.PSObject.Properties[$Name])
		{
			$After = $Pref.$Name
			$Same  = $true
			try
			{
				if ($Value -is [bool])      { $Same = ([bool]$After -eq $Value) }
				elseif ($Value -is [ValueType]) { $Same = ([int64]$After -eq [int64]$Value) }   # integers and enums
				else                        { $Same = ([string]$After -eq [string]$Value) }
			}
			catch { $Same = $true }
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
