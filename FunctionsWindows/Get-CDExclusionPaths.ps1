#requires -Version 5.0
Function Get-CDExclusionPaths
{
	<#
		.SYNOPSIS
		Returns Defender file/folder/wildcard path exclusions.

		.PARAMETER Like
		Optional wildcard filter applied to the returned list.
	#>
	[CmdletBinding()]
	param([string]$Like)

	$List = (Get-MpPreference).ExclusionPath
	if ($Like) { $List = $List | Where-Object { $_ -ilike "*$Like*" } }
	$List
}
