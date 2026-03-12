#requires -Version 5.0
Function Set-CDControlledFolder
{
	<#
		.SYNOPSIS
		Adds or removes a Controlled Folder Access protected folder.

		.DESCRIPTION
		Requires elevation - intended to run in the elevated NamedPipe server process.

		.PARAMETER Folder
		The folder path to add or remove.

		.PARAMETER Add
		Add the folder to the protected list.

		.PARAMETER Remove
		Remove the folder from the protected list.
	#>
	[CmdletBinding(DefaultParameterSetName = 'Add')]
	param
	(
		[Parameter(Mandatory)]
		[string]$Folder,

		[Parameter(ParameterSetName = 'Add')]
		[switch]$Add,

		[Parameter(ParameterSetName = 'Remove')]
		[switch]$Remove
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		'Add'    { Add-MpPreference    -ControlledFolderAccessProtectedFolders $Folder }
		'Remove' { Remove-MpPreference -ControlledFolderAccessProtectedFolders $Folder }
	}
}
