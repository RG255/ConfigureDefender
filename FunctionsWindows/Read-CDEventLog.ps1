#requires -Version 5.0
Function Read-CDEventLog
{
	<#
		.SYNOPSIS
		Reads events from a Windows event log: no match is an empty result, a real failure is an error.

		.DESCRIPTION
		Internal helper for Get-CDEvent. Two things the old code got wrong:
		- It pulled EVERY event in the log and filtered afterwards with Where-Object (the CodeIntegrity Verbose channel can
		  hold 128 MB). The event IDs and start time now go into the filter, so the log service does the filtering.
		- It used -ErrorAction SilentlyContinue, which turned "access denied" or a damaged log into "no events", so the
		  GUI's own handling of a failed read (which assumes Get-CDEvent throws) could never run.
		"No events matched" and "that log does not exist" are answers, not failures, and return nothing. Anything else is
		recorded in the catch audit and thrown.

		.PARAMETER FilterHashtable
		The Get-WinEvent filter (LogName, Id, StartTime ...).

		.PARAMETER Oldest
		Read oldest first. The CodeIntegrity Verbose channel is read this way.
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[hashtable]$FilterHashtable,

		[switch]$Oldest
	)

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	try
	{
		if ($Oldest) { Get-WinEvent -FilterHashtable $FilterHashtable -Oldest -ErrorAction Stop }
		else         { Get-WinEvent -FilterHashtable $FilterHashtable -ErrorAction Stop }
	}
	catch
	{
		if ($_.FullyQualifiedErrorId -match '^(NoMatchingEventsFound|NoMatchingLogsFound)') { return }
		Write-MyCatchAudit -Source 'Read-CDEventLog: reading the event log' -ErrorRecord $_
		throw
	}
}
