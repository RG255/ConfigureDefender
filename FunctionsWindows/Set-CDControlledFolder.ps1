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
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
		Justification = 'Set-CDControlledFolder writes a Controlled Folder Access folder entry - state change is the explicit purpose of this function.')]
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

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	try
	{
		switch ($PSCmdlet.ParameterSetName)
		{
			'Add'    { Add-MpPreference    -ControlledFolderAccessProtectedFolders $Folder }
			'Remove' { Remove-MpPreference -ControlledFolderAccessProtectedFolders $Folder }
		}
	}
	catch
	{
		Write-MyCatchAudit -Source 'Set-CDControlledFolder: writing protected-folder entry' -ErrorRecord $_
		throw
	}
}
