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
	$Private:CDMod = $ExecutionContext.SessionState.Module

	if ($ModuleVersion)
	{
		# Explicit override: load the requested version BY NAME + VERSION. Do NOT pin Path to the running
		# module's psd1 - NamedPipe imports by Path when one is set, which would load the RUNNING version's
		# code under the requested label (the override would be silently ignored). Leaving Path null makes
		# NamedPipe fall back to Import-Module -Name ConfigureDefender -RequiredVersion <override>.
		$Private:CDVer  = $ModuleVersion
		$Private:CDPsd1 = $null
	}
	elseif ($Private:CDMod)
	{
		# Default: derive the exact running version + psd1 path so the server loads the SAME code.
		$Private:CDVer  = [String]$Private:CDMod.Version
		$Private:CDPsd1 = Join-Path -Path $Private:CDMod.ModuleBase -ChildPath ($Private:CDMod.Name + '.psd1')
	}
	else
	{
		# Neither an override nor a resolvable running module (e.g. dot-sourced outside module scope): fail
		# LOUD rather than spawning a server with an unresolved version, which NamedPipe cannot import.
		throw 'Open-CDPipeSession: cannot determine the ConfigureDefender version to load on the elevated server. Call it as a module function, or pass -ModuleVersion explicitly.'
	}

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
