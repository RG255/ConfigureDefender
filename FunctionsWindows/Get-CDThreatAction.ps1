#requires -Version 5.0
Function Get-CDThreatAction
{
	<#
		.SYNOPSIS
		Returns the default action configured for each Defender threat severity level.

		.DESCRIPTION
		Returns an array of PSCustomObjects with Level, Property, Value (int), and
		Action (string label) for each of the five threat severity levels.
	#>
	[CmdletBinding()]
	[OutputType([PSCustomObject[]])]
	param()

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	try
	{
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

		# One loop over the five severity levels instead of five copies of the same object literal
		foreach ($Level in 'Severe', 'High', 'Moderate', 'Low', 'Unknown')
		{
			$Prop = '{0}ThreatDefaultAction' -f $Level
			$Raw  = $Pref.$Prop
			[PSCustomObject]@{
				Level    = $Level
				Property = $Prop
				Value    = $Raw
				Action   = if ($ActionMap.ContainsKey([int]$Raw)) { $ActionMap[[int]$Raw] } else { "Unknown ($Raw)" }
			}
		}
	}
	catch
	{
		Write-MyCatchAudit -Source 'Get-CDThreatAction: querying threat-action defaults' -ErrorRecord $_
		throw
	}
}
