#requires -Version 5.0
Function Test-CDBroadExclusionPath
{
	<#
		.SYNOPSIS
		True when an exclusion path covers a whole drive or a core system or profile folder.

		.DESCRIPTION
		Internal helper behind the broad-exclusion warning. Used by Set-CDExclusionPath and Set-CDASRExclusion (when adding)
		and by the Exclusions tab, which asks for confirmation before sending such a path.

		A path is broad when, after environment variables are expanded and trailing wildcards and separators are removed, it is
		- empty (a bare wildcard such as * or *.*);
		- a drive root (C:\, C:\*, D:);
		- the Windows folder, its System32 folder, Program Files, Program Files (x86), ProgramData, the Users folder or the
		  current user's profile folder.
		Folders below those (C:\Windows\Temp, C:\Users\Name\Downloads) are not broad. The answer only drives a warning and a
		confirmation; it never blocks anything.

		.PARAMETER Path
		The exclusion path as typed.

		.OUTPUTS
		System.Boolean
	#>
	[CmdletBinding()]
	[OutputType([bool])]
	param([AllowEmptyString()][AllowNull()][string]$Path)

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	try
	{
		if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
		$P = [Environment]::ExpandEnvironmentVariables($Path.Trim())
		do
		{
			$Prev = $P
			$P    = ($P -replace '(?:\.\*|\*)$', '').TrimEnd('\', '/')
		}
		while ($P -ne $Prev)

		if ($P -eq '') { return $true }
		if ($P -match '^[A-Za-z]:$') { return $true }

		$Broad = [System.Collections.Generic.List[string]]::new()
		foreach ($Name in 'SystemRoot', 'ProgramFiles', 'ProgramFiles(x86)', 'ProgramData', 'USERPROFILE')
		{
			$Value = [Environment]::GetEnvironmentVariable($Name)
			if ($Value) { $Broad.Add($Value.TrimEnd('\')) }
		}
		if ($env:SystemRoot) { $Broad.Add((Join-Path -Path $env:SystemRoot -ChildPath 'System32')) }
		if ($env:SystemDrive) { $Broad.Add(($env:SystemDrive + '\Users')) }
		return ($P -in $Broad)
	}
	catch
	{
		Write-MyCatchAudit -Source 'Test-CDBroadExclusionPath: judging how broad an exclusion path is' -ErrorRecord $_
		return $false
	}
}
