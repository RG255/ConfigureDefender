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
		(a UNC path, or something another tool added) can still be taken out.

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

	try
	{
		switch ($PSCmdlet.ParameterSetName)
		{
			'Add'
			{
				if ([string]::IsNullOrWhiteSpace($Path)) { throw 'Path cannot be empty' }
				if ($Path -match '[<>"|\x00-\x1F]') { throw 'Invalid characters in path' }
				if ($Path.Length -gt 260) { throw 'Path exceeds Windows maximum length (260 characters)' }
				Add-MpPreference -ExclusionPath $Path
			}
			'Remove' { Remove-MpPreference -ExclusionPath $Path }
		}
	}
	catch
	{
		Write-MyCatchAudit -Source 'Set-CDExclusionPath: writing path exclusion' -ErrorRecord $_
		throw
	}
}
