#requires -Version 5.0
Function Get-CDControlledFolder
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

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	try
	{
		$List = (Get-MpPreference).ControlledFolderAccessProtectedFolders

		if ($Like)
		{ $List = $List | Where-Object { $_ -ilike "*$Like*" } }

		$List
	}
	catch
	{
		Write-MyCatchAudit -Source 'Get-CDControlledFolder: querying protected folder list' -ErrorRecord $_
		throw
	}
}
