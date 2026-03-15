#requires -Version 5.0
Function Set-CDExclusionProcess
{
	<#
		.SYNOPSIS
		Adds or removes a process exclusion from Defender scanning.

		.DESCRIPTION
		Requires elevation - intended to run in the elevated NamedPipe server process.
		Process exclusions exempt a named process from all Defender real-time scanning.
		The value can be a process name (e.g. 'myapp.exe') or a full path.

		.PARAMETER Process
		The process name or full path to add or remove.

		.PARAMETER Add
		Add the process to the exclusion list.

		.PARAMETER Remove
		Remove the process from the exclusion list.
	#>
	[CmdletBinding(DefaultParameterSetName = 'Add')]
	param
	(
		[Parameter(Mandatory)]
		[string]$Process,

		[Parameter(ParameterSetName = 'Add')]
		[switch]$Add,

		[Parameter(ParameterSetName = 'Remove')]
		[switch]$Remove
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		'Add'    { Add-MpPreference    -ExclusionProcess $Process }
		'Remove' { Remove-MpPreference -ExclusionProcess $Process }
	}
}
