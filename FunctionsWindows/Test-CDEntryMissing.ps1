#requires -Version 5.0
Function Test-CDEntryMissing
{
	<#
		.SYNOPSIS
		True only when a stored path entry points at something that is certainly no longer on disk.

		.DESCRIPTION
		Internal helper shared by Get-CDAllowedApplication -CheckMissing, Set-CDAllowedApplication -RemoveMissing and
		the Allowed Applications tab, so all three agree. The answer is deliberately cautious, because
		-RemoveMissing DELETES entries on the strength of it:
		- an entry with a wildcard (* or ?) cannot be tested and is never 'missing';
		- environment variables (%ProgramFiles%\App\app.exe) are expanded first; if one cannot be expanded the entry is
		  not 'missing';
		- the path is tested with -LiteralPath, so [ and ] in a folder name (C:\Apps\Tool[1]\tool.exe) are not read as a
		  wildcard set. With -Path such an entry looked missing and -RemoveMissing removed a working allow-list entry;
		- anything that goes wrong while testing counts as 'not missing' (doubt never deletes).

		.PARAMETER Entry
		The stored path.

		.OUTPUTS
		System.Boolean
	#>
	[CmdletBinding()]
	[OutputType([bool])]
	param([AllowEmptyString()][AllowNull()][string]$Entry)

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	try
	{
		if ([string]::IsNullOrWhiteSpace($Entry)) { return $false }
		if ($Entry -match '[*?]') { return $false }
		$Expanded = [Environment]::ExpandEnvironmentVariables($Entry.Trim())
		if ($Expanded -match '%[^%]+%') { return $false }
		return (-not (Test-Path -LiteralPath $Expanded))
	}
	catch
	{
		Write-MyCatchAudit -Source 'Test-CDEntryMissing: testing whether a stored path exists' -ErrorRecord $_
		return $false
	}
}
