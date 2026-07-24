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
		Version of the ConfigureDefender module to load in the elevated server. Leave empty (the default) to
		use the version of the ConfigureDefender module actually running this function, derived at runtime so the
		server always loads the SAME code. A hardcoded version silently skews when the module is bumped (the
		0.2->0.3 migration hit exactly that); deriving it - like CommonScripts and VHDTools do - cannot skew.

		.EXAMPLE
		Open-CDPipeSession
		Open-CDPipeSession -ModuleVersion '0.2'
	#>
	[CmdletBinding()]
	param
	(
		[string]$ModuleVersion = ''
	)

	# Return immediately if a healthy session already exists
	if ($script:CDPipeInfo -and (Test-PipeSession -PipeInfo $script:CDPipeInfo))
	{ return }

	# Identify the running ConfigureDefender module so the elevated server loads that exact version + path.
	# $ExecutionContext.SessionState.Module is the module that owns this function (ConfigureDefender).
	$Private:CDMod  = $ExecutionContext.SessionState.Module
	$Private:CDVer  = if ($ModuleVersion) { $ModuleVersion } elseif ($Private:CDMod) { [String]$Private:CDMod.Version } else { '' }
	$Private:CDPsd1 = if ($Private:CDMod) { Join-Path -Path $Private:CDMod.ModuleBase -ChildPath ($Private:CDMod.Name + '.psd1') } else { $null }

	$PipeOptions = @{
		AdminRequired        = $true
		WindowStyle          = 'Hidden'
		InfoDisplay          = 1
		ClientConnectTimeout = 30000   # ms; default 10000 is too short when UAC + module load are in the path
		ModuleToLoad         = @{
			Name    = 'ConfigureDefender'
			Version = $Private:CDVer
			Path    = $Private:CDPsd1
		}
	}

	$Session = Start-PipeSession -MyParameters @{ Action = 'Invoke' } -Options $PipeOptions

	$script:CDPipeInfo          = $Session.'ServerClientParams'
	$script:CDSendRequestParams = $Session.'SendRequestParams'
}
