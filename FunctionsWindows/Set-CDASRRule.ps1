#requires -Version 5.0
Function Set-CDASRRule
{
	<#
		.SYNOPSIS
		Adds, removes, or changes the action of an ASR rule.

		.DESCRIPTION
		Requires elevation - intended to run in the elevated NamedPipe server process.

		.PARAMETER GUID
		The GUID of the rule to add or change.

		.PARAMETER Action
		The action to apply: Disabled, Audit, or Blocked.

		.PARAMETER AddAll
		Add all known ASR rules with the specified Action.

		.PARAMETER RemoveGUID
		The GUID of a specific rule to remove.

		.PARAMETER RemoveAll
		Remove all currently configured ASR rules.

		.EXAMPLE
		Set-CDASRRule -GUID 'be9ba2d9-...' -Action Blocked
		Set-CDASRRule -AddAll -Action Audit
		Set-CDASRRule -RemoveGUID 'be9ba2d9-...'
		Set-CDASRRule -RemoveAll
	#>
	[CmdletBinding(DefaultParameterSetName = 'Change')]
	param
	(
		[Parameter(Mandatory, ParameterSetName = 'Change')]
		[Parameter(Mandatory, ParameterSetName = 'Add')]
		[string]$GUID,

		[Parameter(Mandatory, ParameterSetName = 'Change')]
		[Parameter(Mandatory, ParameterSetName = 'Add')]
		[Parameter(Mandatory, ParameterSetName = 'AddAll')]
		[ValidateSet('Disabled', 'Audit', 'Blocked', 'Warn')]
		[string]$Action,

		[Parameter(ParameterSetName = 'Add')]
		[switch]$Add,

		[Parameter(Mandatory, ParameterSetName = 'AddAll')]
		[switch]$AddAll,

		[Parameter(Mandatory, ParameterSetName = 'Remove')]
		[string]$RemoveGUID,

		[Parameter(Mandatory, ParameterSetName = 'RemoveAll')]
		[switch]$RemoveAll
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		{ $_ -in 'Add', 'Change' }
		{
			Add-MpPreference -AttackSurfaceReductionRules_Ids $GUID `
				-AttackSurfaceReductionRules_Actions $script:ASROptions[$Action]
		}
		'AddAll'
		{
			foreach ($RuleGUID in $script:ASRRules.Keys)
			{
				Add-MpPreference -AttackSurfaceReductionRules_Ids $RuleGUID `
					-AttackSurfaceReductionRules_Actions $script:ASROptions[$Action]
			}
		}
		'Remove'
		{
			Remove-MpPreference -AttackSurfaceReductionRules_Ids $RemoveGUID
		}
		'RemoveAll'
		{
			$CurrentIDs = (Get-MpPreference).AttackSurfaceReductionRules_Ids
			if ($CurrentIDs)
			{
				foreach ($RuleGUID in $CurrentIDs)
				{ Remove-MpPreference -AttackSurfaceReductionRules_Ids $RuleGUID }
			}
		}
	}
}
