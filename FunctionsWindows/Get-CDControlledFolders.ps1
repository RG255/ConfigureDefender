#requires -Version 5.0
Function Get-CDControlledFolders
{
	<#
		.SYNOPSIS
		Returns the list of Controlled Folder Access protected folders.

		.PARAMETER Like
		Optional wildcard filter on folder path.

		.OUTPUTS
		String array of folder paths.
	#>
	[CmdletBinding()]
	param
	(
		[string]$Like
	)

	$List = (Get-MpPreference).ControlledFolderAccessProtectedFolders

	if ($Like)
	{ $List = $List | Where-Object { $_ -ilike "*$Like*" } }

	$List
}
