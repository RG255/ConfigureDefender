#requires -Version 5.0
Function Set-CDNetworkProtection
{
	<#
		.SYNOPSIS
		Enables, audits, or disables Network Protection.

		.DESCRIPTION
		Requires elevation - intended to run in the elevated NamedPipe server process.
		Values: 0=Disabled, 1=Enabled, 2=Audit.

		.PARAMETER Enable
		Enable Network Protection (value 1).

		.PARAMETER Audit
		Set Network Protection to Audit mode (value 2).

		.PARAMETER Disable
		Disable Network Protection (value 0).
	#>
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

	switch ($PSCmdlet.ParameterSetName)
	{
		'Enable'  { Set-MpPreference -EnableNetworkProtection 1 }
		'Audit'   { Set-MpPreference -EnableNetworkProtection 2 }
		'Disable' { Set-MpPreference -EnableNetworkProtection 0 }
	}
}
