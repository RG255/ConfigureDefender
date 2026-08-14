#requires -Version 5.0
Function Test-CDPipeSession
{
	<#
		.SYNOPSIS
		Reports whether the elevated NamedPipe session opened by Open-CDPipeSession is
		currently healthy.

		.DESCRIPTION
		Lets a caller outside the module (e.g. the GUI script) check session health
		WITHOUT paying the cost of reopening it - Open-CDPipeSession itself only
		re-validates health as a side effect of being called, so a caller that wants to
		decide "do I need to show a wait dialog" first has to ask separately.

		Returns $false if no session has been opened yet.
	#>
	if (-not $script:CDPipeInfo) { return $false }
	Test-PipeSession -PipeInfo $script:CDPipeInfo
}
