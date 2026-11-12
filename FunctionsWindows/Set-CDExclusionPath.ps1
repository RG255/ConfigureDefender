#requires -Version 5.0
Function Set-CDExclusionPath
{
	<#
		.SYNOPSIS
		Adds or removes a file/folder path exclusion from Defender scanning.

		.DESCRIPTION
		Requires elevation - intended to run in the elevated NamedPipe server process.
		Wildcards are supported (e.g. C:\Temp\*.tmp). UNC paths (\\server\share\...) are allowed.
		The path is validated when it is ADDED only: Remove must always work, so an entry that is already in the list
		(a UNC path, or something another tool added) can still be taken out. The length limit is the Windows extended-path
		maximum (32767 characters), so a long entry that is already in the list can be added again.

		A BROAD path (a drive root, the Windows folder, Program Files, a bare wildcard - see Test-CDBroadExclusionPath) is
		still added, with a warning, and the Application event log entry says so.

		Every successful add or remove writes an Application event log entry (source ConfigureDefender, event 4002) with the path.

		.PARAMETER Path
		The file, folder, or wildcard path to add or remove.

		.PARAMETER Add
		Add the path to the exclusion list.

		.PARAMETER Remove
		Remove the path from the exclusion list.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
		Justification = 'Set-CDExclusionPath writes a path exclusion - state change is the explicit purpose of this function.')]
	[CmdletBinding(DefaultParameterSetName = 'Add')]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Path,

		[Parameter(ParameterSetName = 'Add')]
		[switch]$Add,

		[Parameter(ParameterSetName = 'Remove')]
		[switch]$Remove
	)

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	$Verb  = 'added'
	$Broad = $false
	try
	{
		switch ($PSCmdlet.ParameterSetName)
		{
			'Add'
			{
				if ([string]::IsNullOrWhiteSpace($Path)) { throw 'Path cannot be empty' }
				if ($Path -match '[<>"|\x00-\x1F]') { throw 'Invalid characters in path' }
				if ($Path.Length -gt 32767) { throw 'Path exceeds the Windows extended-path maximum length (32767 characters)' }
				$Broad = Test-CDBroadExclusionPath $Path
				if ($Broad) { Write-Warning "Broad exclusion: '$Path' covers a whole drive or a core system folder." }
				Add-MpPreference -ExclusionPath $Path
			}
			'Remove'
			{
				$Verb = 'removed'
				Remove-MpPreference -ExclusionPath $Path
			}
		}
	}
	catch
	{
		Write-MyCatchAudit -Source 'Set-CDExclusionPath: writing path exclusion' -ErrorRecord $_
		throw
	}

	Write-CDAuditEvent -EventId 4002 -Message ("Defender path exclusion {0}: {1}{2}" -f $Verb, $Path, $(if ($Broad) { ' (BROAD path)' } else { '' }))
}
