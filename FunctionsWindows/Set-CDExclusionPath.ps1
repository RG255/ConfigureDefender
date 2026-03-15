#requires -Version 5.0
Function Set-CDExclusionPath
{
	<#
		.SYNOPSIS
		Adds or removes a file/folder path exclusion from Defender scanning.

		.DESCRIPTION
		Requires elevation - intended to run in the elevated NamedPipe server process.
		Wildcards are supported (e.g. C:\Temp\*.tmp).

		.PARAMETER Path
		The file, folder, or wildcard path to add or remove.

		.PARAMETER Add
		Add the path to the exclusion list.

		.PARAMETER Remove
		Remove the path from the exclusion list.
	#>
	[CmdletBinding(DefaultParameterSetName = 'Add')]
	param
	(
		[Parameter(Mandatory)]
		[string]$Path,

		[Parameter(ParameterSetName = 'Add')]
		[switch]$Add,

		[Parameter(ParameterSetName = 'Remove')]
		[switch]$Remove
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		'Add'    { Add-MpPreference    -ExclusionPath $Path }
		'Remove' { Remove-MpPreference -ExclusionPath $Path }
	}
}
