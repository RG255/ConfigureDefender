#requires -Version 5.0
Function Set-CDExclusionExtension
{
	<#
		.SYNOPSIS
		Adds or removes a file extension exclusion from Defender scanning.

		.DESCRIPTION
		Requires elevation - intended to run in the elevated NamedPipe server process.
		Specify the extension with or without a leading dot (e.g. 'tmp' or '.tmp').

		.PARAMETER Extension
		The file extension to add or remove.

		.PARAMETER Add
		Add the extension to the exclusion list.

		.PARAMETER Remove
		Remove the extension from the exclusion list.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
		Justification = 'Set-CDExclusionExtension writes a file-extension exclusion - state change is the explicit purpose of this function.')]
	[CmdletBinding(DefaultParameterSetName = 'Add')]
	param
	(
		[Parameter(Mandatory)]
		[string]$Extension,

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
			'Add'    { Add-MpPreference    -ExclusionExtension $Extension }
			'Remove' { Remove-MpPreference -ExclusionExtension $Extension }
		}
	}
	catch
	{
		Write-MyCatchAudit -Source 'Set-CDExclusionExtension: writing extension exclusion' -ErrorRecord $_
		throw
	}
}
