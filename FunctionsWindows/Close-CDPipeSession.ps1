#requires -Version 5.0
Function Close-CDPipeSession
{
	<#
		.SYNOPSIS
		Closes the elevated NamedPipe session opened by Open-CDPipeSession.

		.DESCRIPTION
		Sends an ExitPipe signal to the elevated server and disposes the pipe
		resources.  Should be called when the GUI exits.
		Safe to call when no session is open.

		.EXAMPLE
		Close-CDPipeSession
	#>
	[CmdletBinding()]
	param()

	if ($script:CDPipeInfo)
	{
		if (Test-PipeSession -PipeInfo $script:CDPipeInfo)
		{
			Stop-PipeSession -SendRequestParams $script:CDSendRequestParams `
				-PipeInfo $script:CDPipeInfo
		}
		$script:CDPipeInfo          = $null
		$script:CDSendRequestParams = $null
	}
}
