#requires -Version 5.0
Function Get-CDExclusionIpAddresses
{
	<#
		.SYNOPSIS
		Returns Defender IP address exclusions.

		.PARAMETER Like
		Optional wildcard filter applied to the returned list.
	#>
	[CmdletBinding()]
	param([string]$Like)

	$List = (Get-MpPreference).ExclusionIpAddress
	if ($Like) { $List = $List | Where-Object { $_ -ilike "*$Like*" } }
	$List
}
