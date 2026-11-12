#requires -Version 5.0
Function Set-CDControlledFolder
{
	<#
		.SYNOPSIS
		Adds or removes a Controlled Folder Access protected folder.

		.DESCRIPTION
		Requires elevation - intended to run in the elevated NamedPipe server process.
		Each successful change is recorded in the Application event log (source ConfigureDefender, event 4006 (protected folder added or removed)) with the names or paths involved, never a secret.

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

	$Verb = 'added'
	try
	{
		switch ($PSCmdlet.ParameterSetName)
		{
			'Add'    { Add-MpPreference    -ControlledFolderAccessProtectedFolders $Folder }
			'Remove' { $Verb = 'removed'; Remove-MpPreference -ControlledFolderAccessProtectedFolders $Folder }
		}
	}
	catch
	{
		Write-MyCatchAudit -Source 'Set-CDControlledFolder: writing protected-folder entry' -ErrorRecord $_
		throw
	}

	Write-CDAuditEvent -EventId 4006 -Message ("Defender Controlled Folder Access protected folder {0}: {1}" -f $Verb, $Folder)
}
