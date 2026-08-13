#requires -Version 5.0
Function Get-CDThreatActions
{
	<#
		.SYNOPSIS
		Returns the default action configured for each Defender threat severity level.

		.DESCRIPTION
		Returns an array of PSCustomObjects with Level, Property, Value (int), and
		Action (string label) for each of the five threat severity levels.
	#>
	[CmdletBinding()]
	param()

	$Pref = Get-MpPreference

	$ActionMap = @{
		0 = 'Clean'
		1 = 'Quarantine'
		2 = 'Remove'
		6 = 'Allow'
		8 = 'UserDefined'
		9 = 'NoAction'
		10 = 'Block'
	}

	@(
		[PSCustomObject]@{
			Level    = 'Severe'
			Property = 'SevereThreatDefaultAction'
			Value    = $Pref.SevereThreatDefaultAction
			Action   = if ($ActionMap.ContainsKey([int]$Pref.SevereThreatDefaultAction)) { $ActionMap[[int]$Pref.SevereThreatDefaultAction] } else { "Unknown ($($Pref.SevereThreatDefaultAction))" }
		}
		[PSCustomObject]@{
			Level    = 'High'
			Property = 'HighThreatDefaultAction'
			Value    = $Pref.HighThreatDefaultAction
			Action   = if ($ActionMap.ContainsKey([int]$Pref.HighThreatDefaultAction)) { $ActionMap[[int]$Pref.HighThreatDefaultAction] } else { "Unknown ($($Pref.HighThreatDefaultAction))" }
		}
		[PSCustomObject]@{
			Level    = 'Moderate'
			Property = 'ModerateThreatDefaultAction'
			Value    = $Pref.ModerateThreatDefaultAction
			Action   = if ($ActionMap.ContainsKey([int]$Pref.ModerateThreatDefaultAction)) { $ActionMap[[int]$Pref.ModerateThreatDefaultAction] } else { "Unknown ($($Pref.ModerateThreatDefaultAction))" }
		}
		[PSCustomObject]@{
			Level    = 'Low'
			Property = 'LowThreatDefaultAction'
			Value    = $Pref.LowThreatDefaultAction
			Action   = if ($ActionMap.ContainsKey([int]$Pref.LowThreatDefaultAction)) { $ActionMap[[int]$Pref.LowThreatDefaultAction] } else { "Unknown ($($Pref.LowThreatDefaultAction))" }
		}
		[PSCustomObject]@{
			Level    = 'Unknown'
			Property = 'UnknownThreatDefaultAction'
			Value    = $Pref.UnknownThreatDefaultAction
			Action   = if ($ActionMap.ContainsKey([int]$Pref.UnknownThreatDefaultAction)) { $ActionMap[[int]$Pref.UnknownThreatDefaultAction] } else { "Unknown ($($Pref.UnknownThreatDefaultAction))" }
		}
	)
}
