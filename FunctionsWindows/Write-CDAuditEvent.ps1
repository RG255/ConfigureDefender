#requires -Version 5.0
Function Write-CDAuditEvent
{
	<#
		.SYNOPSIS
		Writes an Information entry to the Application event log under the ConfigureDefender source.

		.DESCRIPTION
		Internal helper. Uses the .NET EventLog class, which exists in both Windows PowerShell 5.1 and
		PowerShell 7 (Write-EventLog is not available in PowerShell 7). The source is registered on first
		use, which needs elevation - this module only calls it from the elevated NamedPipe server. A failure
		is catch-audited and never thrown, so a missing audit entry cannot undo the change it describes.

		.PARAMETER Message
		The text of the event.

		.PARAMETER EventId
		The event ID. Default 4001 (Defender setting updated).
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[string]$Message,

		[int]$EventId = 4001
	)

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	try
	{
		$Source = 'ConfigureDefender'
		if (-not [System.Diagnostics.EventLog]::SourceExists($Source))
		{ [System.Diagnostics.EventLog]::CreateEventSource($Source, 'Application') }
		[System.Diagnostics.EventLog]::WriteEntry($Source, $Message, [System.Diagnostics.EventLogEntryType]::Information, $EventId)
	}
	catch
	{
		Write-MyCatchAudit -Source 'Write-CDAuditEvent: writing the Application event log entry' -ErrorRecord $_
	}
}
