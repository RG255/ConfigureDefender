#requires -Version 5.0
Function Get-CDSendRequestParam
{
	<#
		.SYNOPSIS
		Returns the NamedPipe SendRequestParams for the current elevated session.

		.DESCRIPTION
		Reads $script:CDSendRequestParams from within the ConfigureDefender module scope
		so that callers outside the module (e.g. the GUI script) can obtain the session
		handle without needing $Mod.Invoke(), which does not reliably resolve $script:
		variables from within a scriptblock defined in a different file.

		Returns $null if no session has been opened yet.
	#>
	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	$script:CDSendRequestParams
}
