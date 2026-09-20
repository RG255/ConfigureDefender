#requires -Version 5.0
Function Get-CDExclusionIpAddress
{
	<#
		.SYNOPSIS
		Returns Defender IP address exclusions.

		.PARAMETER Like
		Optional wildcard filter applied to the returned list.
	#>
	[CmdletBinding()]
	param([string]$Like)

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	try
	{
		$List = (Get-MpPreference).ExclusionIpAddress
		if ($Like) { $List = $List | Where-Object { $_ -ilike "*$Like*" } }
		$List
	}
	catch
	{
		Write-MyCatchAudit -Source 'Get-CDExclusionIpAddress: querying IP-address exclusion list' -ErrorRecord $_
		throw
	}
}
