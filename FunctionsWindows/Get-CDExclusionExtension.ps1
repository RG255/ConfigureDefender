#requires -Version 5.0
Function Get-CDExclusionExtension
{
	<#
		.SYNOPSIS
		Returns Defender file extension exclusions.

		.PARAMETER Like
		Optional wildcard filter applied to the returned list.
	#>
	[CmdletBinding()]
	param([string]$Like)

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	try
	{
		$List = (Get-MpPreference).ExclusionExtension
		if ($Like) { $List = $List | Where-Object { $_ -ilike "*$Like*" } }
		$List
	}
	catch
	{
		Write-MyCatchAudit -Source 'Get-CDExclusionExtension: querying extension exclusion list' -ErrorRecord $_
		throw
	}
}
