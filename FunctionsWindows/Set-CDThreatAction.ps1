#requires -Version 5.0
Function Set-CDThreatAction
{
	<#
		.SYNOPSIS
		Sets the default action for a Defender threat severity level.

		.DESCRIPTION
		Requires elevation - intended to run in the elevated NamedPipe server process.

		.PARAMETER Level
		The threat severity level: Severe, High, Moderate, Low, or Unknown.

		.PARAMETER Action
		The action to take: Clean, Quarantine, Remove, Allow, UserDefined, NoAction, or Block.
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateSet('Severe', 'High', 'Moderate', 'Low', 'Unknown')]
		[string]$Level,

		[Parameter(Mandatory)]
		[ValidateSet('Clean', 'Quarantine', 'Remove', 'Allow', 'UserDefined', 'NoAction', 'Block')]
		[string]$Action
	)

	$ActionMap = @{
		Clean       = 0
		Quarantine  = 1
		Remove      = 2
		Allow       = 6
		UserDefined = 8
		NoAction    = 9
		Block       = 10
	}

	$PropertyMap = @{
		Severe   = 'SevereThreatDefaultAction'
		High     = 'HighThreatDefaultAction'
		Moderate = 'ModerateThreatDefaultAction'
		Low      = 'LowThreatDefaultAction'
		Unknown  = 'UnknownThreatDefaultAction'
	}

	$Params = @{ $PropertyMap[$Level] = $ActionMap[$Action] }
	Set-MpPreference @Params
}
