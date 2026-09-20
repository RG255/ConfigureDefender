#requires -Version 5.0
Function Get-CDExclusionProcess
{
	<#
		.SYNOPSIS
		Returns the list of processes excluded from Defender scanning.

		.DESCRIPTION
		Requires elevation - intended to be called in the elevated NamedPipe server process.
		Process exclusions exempt a named process from all Defender real-time scanning.

		.PARAMETER Like
		Optional wildcard filter on process name or path.

		.OUTPUTS
		String array of excluded process names or paths.
	#>
	[CmdletBinding()]
	param
	(
		[string]$Like
	)

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	try
	{
		$List = (Get-MpPreference).ExclusionProcess

		if ($Like)
		{ $List = $List | Where-Object { $_ -ilike "*$Like*" } }

		$List
	}
	catch
	{
		Write-MyCatchAudit -Source 'Get-CDExclusionProcess: querying process exclusion list' -ErrorRecord $_
		throw
	}
}
