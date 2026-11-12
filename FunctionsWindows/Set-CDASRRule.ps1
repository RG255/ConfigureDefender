#requires -Version 5.0
Function Set-CDASRRule
{
	<#
		.SYNOPSIS
		Adds, removes, or changes the action of an ASR rule.

		.DESCRIPTION
		Requires elevation - intended to run in the elevated NamedPipe server process.
		Each successful change is recorded in the Application event log (source ConfigureDefender, event 4003 (ASR rule changed or removed)) with the names or paths involved, never a secret.

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
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
		Justification = 'Set-CDASRRule writes an ASR rule action - state change is the explicit purpose of this function.')]
	[CmdletBinding(DefaultParameterSetName = 'Change')]
	param
	(
		[Parameter(Mandatory, ParameterSetName = 'Change')]
		[Parameter(Mandatory, ParameterSetName = 'Add')]
		[ValidatePattern('^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
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
		[ValidatePattern('^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
		[string]$RemoveGUID,

		[Parameter(Mandatory, ParameterSetName = 'RemoveAll')]
		[switch]$RemoveAll
	)

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	$Audit = $null
	try
	{
		switch ($PSCmdlet.ParameterSetName)
		{
			{ $_ -in 'Add', 'Change' }
			{
				Add-MpPreference -AttackSurfaceReductionRules_Ids $GUID `
					-AttackSurfaceReductionRules_Actions $script:ASROptions[$Action]
				$Audit = "Defender ASR rule {0} set to {1}" -f $GUID, $Action
			}
			'AddAll'
			{
				# ONE call with parallel arrays (the documented form), not one call per rule
				$RuleIds     = @($script:ASRRules.Keys)
				$RuleActions = @($RuleIds | ForEach-Object { $script:ASROptions[$Action] })
				Add-MpPreference -AttackSurfaceReductionRules_Ids $RuleIds -AttackSurfaceReductionRules_Actions $RuleActions
				$Audit = "Defender ASR: all {0} known rules set to {1}" -f $RuleIds.Count, $Action
			}
			'Remove'
			{
				Remove-MpPreference -AttackSurfaceReductionRules_Ids $RemoveGUID
				$Audit = "Defender ASR rule {0} removed" -f $RemoveGUID
			}
			'RemoveAll'
			{
				$CurrentIDs = @((Get-MpPreference).AttackSurfaceReductionRules_Ids | Where-Object { $_ })
				if ($CurrentIDs.Count -gt 0) { Remove-MpPreference -AttackSurfaceReductionRules_Ids $CurrentIDs }
				$Audit = "Defender ASR: all configured rules removed ({0})" -f $CurrentIDs.Count
			}
		}
	}
	catch
	{
		Write-MyCatchAudit -Source 'Set-CDASRRule: writing ASR rule state' -ErrorRecord $_
		throw
	}

	if ($Audit) { Write-CDAuditEvent -EventId 4003 -Message $Audit }
}
