#requires -Version 5.0
Function Set-CDNetworkProtection
{
	<#
		.SYNOPSIS
		Enables, audits, or disables Network Protection.

		.DESCRIPTION
		Requires elevation - intended to run in the elevated NamedPipe server process.
		Each successful change is recorded in the Application event log (source ConfigureDefender, event 4007 (mode changed)) with the names or paths involved, never a secret.
		Values: 0=Disabled, 1=Enabled, 2=Audit.

		.PARAMETER Enable
		Enable Network Protection (value 1).

		.PARAMETER Audit
		Set Network Protection to Audit mode (value 2).

		.PARAMETER Disable
		Disable Network Protection (value 0).
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
		Justification = 'Set-CDNetworkProtection toggles the Network Protection feature state - state change is the explicit purpose of this function.')]
	[CmdletBinding(DefaultParameterSetName = 'Enable')]
	param
	(
		[Parameter(ParameterSetName = 'Enable')]
		[switch]$Enable,

		[Parameter(ParameterSetName = 'Audit')]
		[switch]$Audit,

		[Parameter(ParameterSetName = 'Disable')]
		[switch]$Disable
	)

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	$Mode = $PSCmdlet.ParameterSetName
	try
	{
		switch ($Mode)
		{
			'Enable'  { Set-MpPreference -EnableNetworkProtection 1 }
			'Audit'   { Set-MpPreference -EnableNetworkProtection 2 }
			'Disable' { Set-MpPreference -EnableNetworkProtection 0 }
		}
	}
	catch
	{
		Write-MyCatchAudit -Source 'Set-CDNetworkProtection: writing Network Protection state' -ErrorRecord $_
		throw
	}

	Write-CDAuditEvent -EventId 4007 -Message ("Defender Network Protection set to {0}" -f $Mode)
}
