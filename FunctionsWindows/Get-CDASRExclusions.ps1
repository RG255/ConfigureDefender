#requires -Version 5.0
Function Get-CDASRExclusions
{
	<#
		.SYNOPSIS
		Returns the list of ASR exclusions (paths excluded from all ASR rules).

		.DESCRIPTION
		Requires elevation - intended to be called in the elevated NamedPipe server process.

		.PARAMETER Like
		Optional wildcard filter on path.

		.OUTPUTS
		String array of exclusion paths.
	#>
	[CmdletBinding()]
	param
	(
		[string]$Like
	)

	$List = (Get-MpPreference).AttackSurfaceReductionOnlyExclusions

	if ($Like)
	{ $List = $List | Where-Object { $_ -ilike "*$Like*" } }

	$List
}
