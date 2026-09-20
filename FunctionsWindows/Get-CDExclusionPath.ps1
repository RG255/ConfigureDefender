#requires -Version 5.0
Function Get-CDExclusionPath
{
	<#
		.SYNOPSIS
		Returns Defender file/folder/wildcard path exclusions.

		.PARAMETER Like
		Optional wildcard filter applied to the returned list.
	#>
	[CmdletBinding()]
	param([string]$Like)

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	try
	{
		$List = (Get-MpPreference).ExclusionPath
		if ($Like) { $List = $List | Where-Object { $_ -ilike "*$Like*" } }
		$List
	}
	catch
	{
		Write-MyCatchAudit -Source 'Get-CDExclusionPath: querying path exclusion list' -ErrorRecord $_
		throw
	}
}
