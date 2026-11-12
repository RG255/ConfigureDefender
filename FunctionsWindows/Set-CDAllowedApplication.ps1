#requires -Version 5.0
Function Set-CDAllowedApplication
{
	<#
		.SYNOPSIS
		Adds, removes, or cleans up Controlled Folder Access allowed applications.

		.DESCRIPTION
		Requires elevation - intended to run in the elevated NamedPipe server process.
		Each successful change is recorded in the Application event log (source ConfigureDefender, event 4005 (allowed application added or removed)) with the names or paths involved, never a secret.

		.PARAMETER Path
		The application path to add or remove. On add it must be one existing executable file (see Test-CDAllowedApplicationPath):
		an empty value, a wildcard, a control character, a drive root or share root, a folder and a file that is certainly
		absent are refused with a terminating error. A path the elevated session cannot verify (a network path, a mapped or
		detached drive, an unexpandable variable) or an existing file that is not .exe / .com / .scr is refused unless -Force
		is given. Remove is never validated, so a stale, odd or folder entry can always be taken out.

		.PARAMETER Force
		With -Add: accept a path that could not be verified or is not an executable type. It never overrides a refusal
		(empty, wildcard, folder, drive root, certainly absent).

		.PARAMETER Add
		Add the application to the allowed list.

		.PARAMETER Remove
		Remove the application from the allowed list.

		.PARAMETER RemoveMissing
		Scans the allowed list and removes any entries whose path no longer exists on disk. Only an entry on a fixed local
		drive that is ready can count as missing (see Test-CDEntryMissing), so entries on mapped network drives, UNC shares and
		detached drives are kept. The GUI does not use this switch: it lists the missing entries, asks, and removes the
		confirmed ones one by one.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
		Justification = 'Set-CDAllowedApplication writes a single allowed-application entry - state change is the explicit purpose of this function.')]
	[CmdletBinding(DefaultParameterSetName = 'Add')]
	param
	(
		[Parameter(Mandatory, ParameterSetName = 'Add')]
		[Parameter(Mandatory, ParameterSetName = 'Remove')]
		[string]$Path,

		[Parameter(ParameterSetName = 'Add')]
		[switch]$Add,

		[Parameter(ParameterSetName = 'Add')]
		[switch]$Force,

		[Parameter(ParameterSetName = 'Remove')]
		[switch]$Remove,

		[Parameter(ParameterSetName = 'RemoveMissing')]
		[switch]$RemoveMissing
	)

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	$Audit = [System.Collections.Generic.List[string]]::new()
	try
	{
		switch ($PSCmdlet.ParameterSetName)
		{
			'Add'
			{
				$Verdict = Test-CDAllowedApplicationPath $Path
				if ($Verdict.Verdict -eq 'Reject') { throw "Not added: '$Path' - $($Verdict.Reason)" }
				if ($Verdict.Verdict -eq 'NeedsForce' -and -not $Force) { throw "Not added: '$Path' - $($Verdict.Reason) Use -Force to add it anyway." }
				Add-MpPreference -ControlledFolderAccessAllowedApplications $Path
				$Audit.Add("Defender Controlled Folder Access allowed application added: $Path")
			}
			'Remove'
			{
				Remove-MpPreference -ControlledFolderAccessAllowedApplications $Path
				$Audit.Add("Defender Controlled Folder Access allowed application removed: $Path")
			}
			'RemoveMissing'
			{
				$List = (Get-MpPreference).ControlledFolderAccessAllowedApplications
				foreach ($Item in $List)
				{
					# Test-CDEntryMissing is cautious on purpose (wildcards, unexpandable variables, [ ] in names, anything that is
					# not on a ready fixed drive, and any doubt all count as NOT missing) because this REMOVES entries
					if (Test-CDEntryMissing $Item)
					{
						Remove-MpPreference -ControlledFolderAccessAllowedApplications $Item
						$Audit.Add("Defender Controlled Folder Access allowed application removed (missing): $Item")
					}
				}
			}
		}
	}
	catch
	{
		# Entries removed before a failure were still removed: record them as well
		foreach ($Line in $Audit) { Write-CDAuditEvent -EventId 4005 -Message $Line }
		If ($_.Exception.Message -notlike 'Not added:*') { Write-MyCatchAudit -Source 'Set-CDAllowedApplication: writing allowed-application entry' -ErrorRecord $_ }   # a refused path is the caller's mistake, not a fault
		throw
	}

	foreach ($Line in $Audit) { Write-CDAuditEvent -EventId 4005 -Message $Line }
}
