#requires -Version 5.0
Function Set-CDExclusionExtension
{
	<#
		.SYNOPSIS
		Adds or removes a file extension exclusion from Defender scanning.

		.DESCRIPTION
		Requires elevation - intended to run in the elevated NamedPipe server process.
		Each successful change is recorded in the Application event log (source ConfigureDefender, event 4002 (extension exclusion added or removed)) with the names or paths involved, never a secret.
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

	$Verb = 'added'
	try
	{
		switch ($PSCmdlet.ParameterSetName)
		{
			'Add'    { Add-MpPreference    -ExclusionExtension $Extension }
			'Remove' { $Verb = 'removed'; Remove-MpPreference -ExclusionExtension $Extension }
		}
	}
	catch
	{
		Write-MyCatchAudit -Source 'Set-CDExclusionExtension: writing extension exclusion' -ErrorRecord $_
		throw
	}

	Write-CDAuditEvent -EventId 4002 -Message ("Defender extension exclusion {0}: {1}" -f $Verb, $Extension)
}
