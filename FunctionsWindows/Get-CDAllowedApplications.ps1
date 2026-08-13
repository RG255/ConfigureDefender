#requires -Version 5.0
Function Get-CDAllowedApplications
{
	<#
		.SYNOPSIS
		Returns the list of applications allowed to access Controlled Folders.

		.DESCRIPTION
		Requires elevation - intended to be called in the elevated NamedPipe server process.

		.PARAMETER Like
		Optional wildcard filter on path.

		.PARAMETER CheckMissing
		When specified, only returns entries whose path no longer exists on disk.

		.OUTPUTS
		String array of application paths.
	#>
	[CmdletBinding(DefaultParameterSetName = 'List')]
	param
	(
		[Parameter(ParameterSetName = 'List')]
		[string]$Like,

		[Parameter(ParameterSetName = 'CheckMissing')]
		[switch]$CheckMissing
	)

	$List = (Get-MpPreference).ControlledFolderAccessAllowedApplications

	if ($CheckMissing)
	{
		$List = $List | Where-Object { $_ -and -not (Test-Path -Path $_) }
	}
	elseif ($Like)
	{
		$List = $List | Where-Object { $_ -ilike "*$Like*" }
	}

	$List
}
