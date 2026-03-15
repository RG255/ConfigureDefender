#requires -Version 5.0
Function Open-CDPipeSession
{
	<#
		.SYNOPSIS
		Opens an elevated NamedPipe server for ConfigureDefender admin operations.

		.DESCRIPTION
		Called from the GUI on the first operation that requires elevation.
		If a session is already open and healthy it returns immediately.
		The session is stored in module-scope variables and remains open
		until Close-CDPipeSession is called (e.g. when the GUI exits).

		The elevated server imports the ConfigureDefender module so all
		Set-CD* and Get-CD* functions are available on the server side.

		.PARAMETER ModuleVersion
		Version of the ConfigureDefender module to load in the elevated server.
		Defaults to the version recorded in the module manifest.

		.EXAMPLE
		Open-CDPipeSession
		Open-CDPipeSession -ModuleVersion '0.2'
	#>
	[CmdletBinding()]
	param
	(
		[string]$ModuleVersion = '0.2'
	)

	# Return immediately if a healthy session already exists
	if ($script:CDPipeInfo -and (Test-PipeSession -PipeInfo $script:CDPipeInfo))
	{ return }

	$PipeOptions = @{
		AdminRequired = $true
		WindowStyle   = 'Hidden'
		InfoDisplay   = 1
		ModuleToLoad  = @{
			Name    = 'ConfigureDefender'
			Version = $ModuleVersion
		}
	}

	$Session = Start-PipeSession -MyParameters @{ Action = 'Invoke' } -Options $PipeOptions

	$script:CDPipeInfo          = $Session.'ServerClientParams'
	$script:CDSendRequestParams = $Session.'SendRequestParams'
}
