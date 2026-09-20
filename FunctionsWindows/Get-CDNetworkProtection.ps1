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

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	try
	{
		$Val = [int](Get-MpPreference).EnableNetworkProtection
		[PSCustomObject][Ordered]@{
			Value       = $Val
			Description = if ($script:NPOptions.Contains($Val)) { $script:NPOptions[$Val] } else { "Unknown ($Val)" }
		}
	}
	catch
	{
		Write-MyCatchAudit -Source 'Get-CDNetworkProtection: querying Network Protection state' -ErrorRecord $_
		throw
	}
}
