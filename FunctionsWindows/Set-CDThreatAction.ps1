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
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
		Justification = 'Set-CDThreatAction writes a threat-action preference - state change is the explicit purpose of this function.')]
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

	$PropertyMap = @{
		Severe   = 'SevereThreatDefaultAction'
		High     = 'HighThreatDefaultAction'
		Moderate = 'ModerateThreatDefaultAction'
		Low      = 'LowThreatDefaultAction'
		Unknown  = 'UnknownThreatDefaultAction'
	}

	# Set-MpPreference's -XxxThreatDefaultAction parameters are a real enum keyed by NAME
	# (Clean, Quarantine, Remove, Allow, UserDefined, NoAction, Block, None) - $Action already
	# matches those names via ValidateSet above, so pass it straight through. A prior numeric
	# translation here (Clean=0, NoAction=9, ...) was wrong - the enum does not accept those
	# integers, so every call failed with a ParameterArgumentTransformationError.
	$Params = @{ $PropertyMap[$Level] = $Action }
	Set-MpPreference @Params
}
