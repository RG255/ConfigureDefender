#requires -Version 5.0
Function Set-CDAllowedApplication
{
	<#
		.SYNOPSIS
		Adds, removes, or cleans up Controlled Folder Access allowed applications.

		.DESCRIPTION
		Requires elevation - intended to run in the elevated NamedPipe server process.

		.PARAMETER Path
		The application path to add or remove.

		.PARAMETER Add
		Add the application to the allowed list.

		.PARAMETER Remove
		Remove the application from the allowed list.

		.PARAMETER RemoveMissing
		Scans the allowed list and removes any entries whose path no longer exists on disk.
	#>
	[CmdletBinding(DefaultParameterSetName = 'Add')]
	param
	(
		[Parameter(Mandatory, ParameterSetName = 'Add')]
		[Parameter(Mandatory, ParameterSetName = 'Remove')]
		[string]$Path,

		[Parameter(ParameterSetName = 'Add')]
		[switch]$Add,

		[Parameter(ParameterSetName = 'Remove')]
		[switch]$Remove,

		[Parameter(ParameterSetName = 'RemoveMissing')]
		[switch]$RemoveMissing
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		'Add'
		{ Add-MpPreference    -ControlledFolderAccessAllowedApplications $Path }
		'Remove'
		{ Remove-MpPreference -ControlledFolderAccessAllowedApplications $Path }
		'RemoveMissing'
		{
			$List = (Get-MpPreference).ControlledFolderAccessAllowedApplications
			foreach ($Item in $List)
			{
				if ($Item -and -not (Test-Path -Path $Item))
				{ Remove-MpPreference -ControlledFolderAccessAllowedApplications $Item }
			}
		}
	}
}
