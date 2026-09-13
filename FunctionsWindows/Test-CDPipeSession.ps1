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

		2026-08-25/26: root-caused a "UAC prompt for every action" report, including on pure reads
		(the Exclusions tab's category switch requires elevation even to read - see
		GUI-Tab-Exclusions.ps1). $script:CDPipeInfo (set in Open-CDPipeSession.ps1) is actually the
		WHOLE ServerClientParams session wrapper (keys: Server, Client, PipeName, PipeInfo, PipeParams,
		InfoDisplay, ...), not the inner pipe-handle object Test-PipeSession needs (keys: Pipe, Reader,
		Writer, Name, ...) - that lives one level deeper, at $script:CDPipeInfo.PipeInfo. This function
		was passing the OUTER wrapper straight to Test-PipeSession -PipeInfo, whose Phase 1 check then
		read the wrapper's own (always-null) .Pipe property and reported "unhealthy" - deterministically,
		on every single call, regardless of whether the actual session was fine. Confirmed via a
		temporary diagnostic patch to NamedPipe's own Test-PipeSession.ps1 that dumped the real .NET type
		and keys of what it was being handed: `System.Collections.Specialized.OrderedDictionary` with the
		ServerClientParams key set, not the PipeInfo key set. Fixed by passing the correctly-nested
		object using the literal string key 'PipeInfo' (never $StrPipeInfo here - that variable resolves
		to $null in this consumer's scope, per the existing ModuleToLoad convention documented in
		Open-CDPipeSession.ps1).

		A SEPARATE, real issue was also found and ruled back out during this investigation: Microsoft
		Defender's own service (MsMpEng.exe) was, on one occasion, independently flipping the ASR rule
		being edited and killing the elevated server outright (confirmed via a vanished PID and Defender
		Operational log events attributed to MsMpEng). That is a genuine environmental failure mode this
		function cannot paper over - if it recurs, Test-PipeSession will correctly and truthfully report
		the session as gone. It was not, however, the cause of the deterministic "every single action"
		symptom - this consumer-side wrong-object bug was, and reproduced with MsMpEng verifiably quiet.

		See project_namedpipe_health_pipe_race memory for the full investigation trail.
	#>
	if (-not $script:CDPipeInfo) { return $false }
	Test-PipeSession -PipeInfo $script:CDPipeInfo.'PipeInfo'
}
