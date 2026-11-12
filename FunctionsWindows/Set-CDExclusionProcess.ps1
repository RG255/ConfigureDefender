#requires -Version 5.0
Function Set-CDExclusionProcess
{
	<#
		.SYNOPSIS
		Adds or removes a process exclusion from Defender scanning.

		.DESCRIPTION
		Requires elevation - intended to run in the elevated NamedPipe server process.
		Each successful change is recorded in the Application event log (source ConfigureDefender, event 4002 (process exclusion added or removed)) with the names or paths involved, never a secret.
		Process exclusions exempt a named process from all Defender real-time scanning.
		The value can be a process name (e.g. 'myapp.exe') or a full path.

		.PARAMETER Process
		The process name or full path to add or remove.

		.PARAMETER Add
		Add the process to the exclusion list.

		.PARAMETER Remove
		Remove the process from the exclusion list.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
		Justification = 'Set-CDExclusionProcess writes a process exclusion - state change is the explicit purpose of this function.')]
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

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	$Verb = 'added'
	try
	{
		switch ($PSCmdlet.ParameterSetName)
		{
			'Add'    { Add-MpPreference    -ExclusionProcess $Process }
			'Remove' { $Verb = 'removed'; Remove-MpPreference -ExclusionProcess $Process }
		}
	}
	catch
	{
		Write-MyCatchAudit -Source 'Set-CDExclusionProcess: writing process exclusion' -ErrorRecord $_
		throw
	}

	Write-CDAuditEvent -EventId 4002 -Message ("Defender process exclusion {0}: {1}" -f $Verb, $Process)
}
