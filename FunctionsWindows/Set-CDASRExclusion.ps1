#requires -Version 5.0
Function Set-CDASRExclusion
{
	<#
		.SYNOPSIS
		Adds or removes an ASR exclusion path.

		.DESCRIPTION
		Requires elevation - intended to run in the elevated NamedPipe server process.
		ASR exclusions exempt a path from all ASR rules.

		.PARAMETER Path
		The file or folder path to add or remove.

		.PARAMETER Add
		Add the path to the ASR exclusion list.

		.PARAMETER Remove
		Remove the path from the ASR exclusion list.
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
		'Add'    { Add-MpPreference    -AttackSurfaceReductionOnlyExclusions $Path }
		'Remove' { Remove-MpPreference -AttackSurfaceReductionOnlyExclusions $Path }
	}
}
