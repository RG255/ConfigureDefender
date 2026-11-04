#requires -Version 5.0
Function Get-CDASRRule
{
	<#
		.SYNOPSIS
		Returns the current state of all known ASR rules, plus any configured rule this module does not know.

		.DESCRIPTION
		Queries Get-MpPreference for the currently configured ASR rule IDs and their
		actions, then maps them against the full known rule table ($script:ASRRules).
		Rules that are not configured at all are reported with Action 'Not Set'.
		A rule that IS configured on this machine but is not in the table (set by policy, added by a newer
		Windows build, or by another tool) is listed after the known ones with the description
		'Unknown rule', so it can be seen and changed instead of being invisible.

		.OUTPUTS
		An array of PSCustomObjects with properties:
		  GUID        - The ASR rule GUID
		  Action      - Current action: Not Set | Disabled | Audit | Blocked | Warn
		  Description - Human-readable rule description
	#>
	[CmdletBinding()]
	param()

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	try
	{
		$Pref    = Get-MpPreference
		$Ids     = @($Pref.AttackSurfaceReductionRules_Ids)
		$Actions = @($Pref.AttackSurfaceReductionRules_Actions)

		# One lookup table, built once (the old code rebuilt a lower-cased copy of the list for every rule)
		$Configured = @{}
		for ($i = 0; $i -lt $Ids.Count; $i++)
		{
			if ($Ids[$i]) { $Configured[([string]$Ids[$i]).ToLower()] = [int]$Actions[$i] }
		}

		foreach ($GUID in $script:ASRRules.Keys)
		{
			$Action = 'Not Set'
			$Key    = $GUID.ToLower()
			if ($Configured.ContainsKey($Key))
			{
				$ActionVal = $Configured[$Key]
				$Action    = if ($script:ASROptions.Contains($ActionVal)) { $script:ASROptions[$ActionVal] } else { "Unknown ($ActionVal)" }
			}
			[PSCustomObject][Ordered]@{
				GUID        = $GUID
				Action      = $Action
				Description = $script:ASRRules[$GUID]
			}
		}

		$Known = @($script:ASRRules.Keys | ForEach-Object { $_.ToLower() })
		foreach ($Key in $Configured.Keys)
		{
			if ($Key -in $Known) { continue }
			$ActionVal = $Configured[$Key]
			[PSCustomObject][Ordered]@{
				GUID        = $Key
				Action      = if ($script:ASROptions.Contains($ActionVal)) { $script:ASROptions[$ActionVal] } else { "Unknown ($ActionVal)" }
				Description = 'Unknown rule (configured on this machine, not in this module''s list)'
			}
		}
	}
	catch
	{
		Write-MyCatchAudit -Source 'Get-CDASRRule: querying/mapping ASR rule state' -ErrorRecord $_
		throw
	}
}
