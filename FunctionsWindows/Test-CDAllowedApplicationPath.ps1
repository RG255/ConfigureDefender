#requires -Version 5.0
Function Test-CDAllowedApplicationPath
{
	<#
		.SYNOPSIS
		Judges a path typed as a Controlled Folder Access allowed application: Ok, Reject or NeedsForce.

		.DESCRIPTION
		Internal helper behind Set-CDAllowedApplication -Add and the Allowed Applications tab. An allowed application should be
		one existing executable FILE. The answer is an object with Verdict and Reason:

		Reject      - never acceptable: an empty value; a wildcard (* or ?); a control character or one of < > " |; more than 32767
		              characters; a path that is not absolute; a drive root or a bare share (C:\, \\server\share); a path ending in a
		              separator; an existing folder; a file that is certainly absent (on a fixed local drive that is ready, see
		              Test-CDEntryMissing).
		NeedsForce  - plausible but not verifiable from this session: the file is not visible (a network path, a mapped drive or a
		              detached USB / VHD drive the elevated session cannot see), an environment variable cannot be expanded, the
		              check itself failed, or the file exists but is not .exe / .com / .scr (the types Controlled Folder Access acts on).
		Ok          - an existing file with one of those extensions.

		Environment variables are expanded for the check only; the caller sends the value as typed. Remove is never judged: any
		stored entry must stay removable.

		.PARAMETER Path
		The path as typed.

		.OUTPUTS
		System.Management.Automation.PSCustomObject with Verdict (Ok, Reject, NeedsForce) and Reason.
	#>
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	param([AllowEmptyString()][AllowNull()][string]$Path)

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	$Result = { param($V, $R) [PSCustomObject]@{ Verdict = $V; Reason = $R } }
	try
	{
		if ([string]::IsNullOrWhiteSpace($Path)) { return (& $Result 'Reject' 'The path is empty.') }
		$P = $Path.Trim()
		if ($P -match '[\x00-\x1F]') { return (& $Result 'Reject' 'The path contains a control character.') }
		if ($P -match '[<>"|]') { return (& $Result 'Reject' 'The path contains a character that is not allowed in a path (< > " |).') }
		if ($P -match '[*?]') { return (& $Result 'Reject' 'Wildcards are not allowed: an allowed application is one executable file.') }
		if ($P.Length -gt 32767) { return (& $Result 'Reject' 'The path is longer than the Windows maximum (32767 characters).') }

		$Expanded = [Environment]::ExpandEnvironmentVariables($P)
		if ($Expanded -match '%[^%]+%') { return (& $Result 'NeedsForce' 'An environment variable in the path could not be expanded here, so the file could not be checked.') }
		if ($Expanded -notmatch '^(?:[A-Za-z]:\\|\\\\[^\\])') { return (& $Result 'Reject' 'The path must be absolute: a drive letter (C:\...) or a network path (\\server\share\...).') }
		if ($Expanded -match '^[A-Za-z]:\\?$') { return (& $Result 'Reject' 'A drive root is not an application.') }
		if ($Expanded -match '^\\\\[^\\]+(?:\\[^\\]*)?\\?$') { return (& $Result 'Reject' 'A network share is not an application.') }
		if ($Expanded -match '[\\/]$') { return (& $Result 'Reject' 'The path ends with a separator, so it names a folder, not a file.') }

		if (Test-Path -LiteralPath $Expanded -PathType Container) { return (& $Result 'Reject' 'The path is a folder. An allowed application must be an executable file.') }
		if (Test-Path -LiteralPath $Expanded -PathType Leaf)
		{
			$Ext = [System.IO.Path]::GetExtension($Expanded)
			if ($Ext -in '.exe', '.com', '.scr') { return (& $Result 'Ok' 'An existing executable file.') }
			return (& $Result 'NeedsForce' "The file exists but is not an executable type (.exe, .com, .scr); Controlled Folder Access may ignore it.")
		}
		if (Test-CDEntryMissing $Expanded) { return (& $Result 'Reject' 'The file does not exist.') }
		return (& $Result 'NeedsForce' 'The file could not be found from this session. That is normal for a network path, a mapped drive or a USB / VHD drive that is not attached to this session; check the path before adding it.')
	}
	catch
	{
		Write-MyCatchAudit -Source 'Test-CDAllowedApplicationPath: judging an allowed-application path' -ErrorRecord $_
		return (& $Result 'NeedsForce' 'The path could not be checked.')
	}
}
