#requires -Version 5.0
Function Set-CDControlledFolderAccess
{
	<#
		.SYNOPSIS
		Enables, audits, or disables Controlled Folder Access.

		.DESCRIPTION
		Requires elevation - intended to run in the elevated NamedPipe server process.
		Each successful change is recorded in the Application event log (source ConfigureDefender, event 4004 (mode changed)) with the names or paths involved, never a secret.
		Values: 0=Disabled, 1=Enabled, 2=Audit, 3=BlockDiskModification, 4=AuditDiskModification.

		.PARAMETER Enable
		Enable Controlled Folder Access (value 1).

		.PARAMETER Audit
		Set Controlled Folder Access to Audit mode (value 2).

		.PARAMETER Disable
		Disable Controlled Folder Access (value 0).
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
		Justification = 'Set-CDControlledFolderAccess toggles the CFA feature state - state change is the explicit purpose of this function.')]
	[CmdletBinding(DefaultParameterSetName = 'Enable')]
	param
	(
		[Parameter(ParameterSetName = 'Enable')]
		[switch]$Enable,

		[Parameter(ParameterSetName = 'Audit')]
		[switch]$Audit,

		[Parameter(ParameterSetName = 'Disable')]
		[switch]$Disable
	)

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	$Mode = $PSCmdlet.ParameterSetName
	try
	{
		switch ($Mode)
		{
			'Enable'  { Set-MpPreference -EnableControlledFolderAccess 1 }
			'Audit'   { Set-MpPreference -EnableControlledFolderAccess 2 }
			'Disable' { Set-MpPreference -EnableControlledFolderAccess 0 }
		}
	}
	catch
	{
		Write-MyCatchAudit -Source 'Set-CDControlledFolderAccess: writing Controlled Folder Access state' -ErrorRecord $_
		throw
	}

	Write-CDAuditEvent -EventId 4004 -Message ("Defender Controlled Folder Access set to {0}" -f $Mode)
}
