#requires -Version 5.0
Function Get-CDASRRules
{
	<#
		.SYNOPSIS
		Returns the current state of all known ASR rules.

		.DESCRIPTION
		Queries Get-MpPreference for the currently configured ASR rule IDs and their
		actions, then maps them against the full known rule table ($script:ASRRules).
		Rules that are not configured at all are reported with Action 'Not Set'.

		.OUTPUTS
		An array of PSCustomObjects with properties:
		  GUID        - The ASR rule GUID
		  Action      - Current action: Not Set | Disabled | Audit | Blocked | Warn
		  Description - Human-readable rule description
	#>
	[CmdletBinding()]
	param()

	$Pref    = Get-MpPreference
	$Ids     = $Pref.AttackSurfaceReductionRules_Ids
	$Actions = $Pref.AttackSurfaceReductionRules_Actions

	foreach ($GUID in $script:ASRRules.Keys)
	{
		$Action = 'Not Set'
		if ($Ids)
		{
			$Idx = [array]::IndexOf([string[]]($Ids | ForEach-Object { $_.ToLower() }), $GUID.ToLower())
			if ($Idx -ge 0)
			{
				$ActionVal = [int]$Actions[$Idx]
				$Action    = if ($script:ASROptions.Contains($ActionVal)) { $script:ASROptions[$ActionVal] } else { "Unknown ($ActionVal)" }
			}
		}
		[PSCustomObject][Ordered]@{
			GUID        = $GUID
			Action      = $Action
			Description = $script:ASRRules[$GUID]
		}
	}
}
