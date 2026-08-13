#requires -Version 5.0
Function Get-CDExclusionExtensions
{
	<#
		.SYNOPSIS
		Returns Defender file extension exclusions.

		.PARAMETER Like
		Optional wildcard filter applied to the returned list.
	#>
	[CmdletBinding()]
	param([string]$Like)

	$List = (Get-MpPreference).ExclusionExtension
	if ($Like) { $List = $List | Where-Object { $_ -ilike "*$Like*" } }
	$List
}
