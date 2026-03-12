#requires -Version 5.0
Function Get-CDNetworkProtection
{
	<#
		.SYNOPSIS
		Returns the current Network Protection state.

		.OUTPUTS
		PSCustomObject with properties:
		  Value       - Raw integer value (0=Disabled, 1=Enabled, 2=Audit)
		  Description - Human-readable state string
	#>
	[CmdletBinding()]
	param()

	$Val = [int](Get-MpPreference).EnableNetworkProtection
	[PSCustomObject][Ordered]@{
		Value       = $Val
		Description = if ($script:NPOptions.Contains($Val)) { $script:NPOptions[$Val] } else { "Unknown ($Val)" }
	}
}
