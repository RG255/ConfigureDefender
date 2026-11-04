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

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	# Teardown/cleanup helper - never throws (matches the Stop-PipeSession/Close-VHDPipeSession
	# convention for Finally-called teardown code), just catch-audits so a failure here is still
	# tracked instead of being silently swallowed.
	try
	{
		if ($script:CDPipeInfo)
		{
			# $script:CDPipeInfo is the whole ServerClientParams; the pipe object Test-PipeSession and
			# Stop-PipeSession want is the PipeInfo one level down (see Test-CDPipeSession). Passing the outer
			# object made Test-PipeSession return $false every time, so no ExitPipe was ever sent and the
			# hidden elevated server was left running after the GUI closed.
			$Private:PI = $script:CDPipeInfo.'PipeInfo'
			if (Test-PipeSession -PipeInfo $Private:PI)
			{
				Stop-PipeSession -SendRequestParams $script:CDSendRequestParams -PipeInfo $Private:PI
			}
			elseif ($Private:PI)
			{
				# The normal exit cannot be delivered (server wedged or the pipe already dropped): go straight
				# to KILL on the health pipe (NamedPipe 0.16) so a hidden elevated server is not left behind.
				# Best effort - an unreachable server is already gone.
				try { Stop-PipeSession -SendRequestParams $script:CDSendRequestParams -PipeInfo $Private:PI -Force }
				catch { Write-MyCatchAudit -Source 'Close-CDPipeSession: force-stopping unreachable server' -ErrorRecord $_ }
			}
			$script:CDPipeInfo          = $null
			$script:CDSendRequestParams = $null
		}
	}
	catch
	{
		Write-MyCatchAudit -Source 'Close-CDPipeSession: closing elevated NamedPipe session' -ErrorRecord $_
	}
}
