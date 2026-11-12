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
		- only a path on a FIXED local drive that is ready can be 'missing'. A mapped network drive, a UNC path, a detached USB
		  drive or VHD, an empty optical drive and a path with no drive letter are all 'not missing': from the elevated server
		  they look absent whether or not they are, so their absence proves nothing;
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
		# Why: absence only counts on a drive that is really there (CHANGELOG 0.6, "Rm Missing").
		if ($Expanded -notmatch '^[A-Za-z]:\\') { return $false }
		$Drive = New-Object System.IO.DriveInfo($Expanded.Substring(0, 1))
		if ($Drive.DriveType -ne [System.IO.DriveType]::Fixed -or -not $Drive.IsReady) { return $false }
		return (-not (Test-Path -LiteralPath $Expanded))
	}
	catch
	{
		Write-MyCatchAudit -Source 'Test-CDEntryMissing: testing whether a stored path exists' -ErrorRecord $_
		return $false
	}
}
