#requires -Version 5.0
Function Get-CDEvents
{
	<#
		.SYNOPSIS
		Returns Defender events from the Windows event log.

		.DESCRIPTION
		Retrieves events from Microsoft-Windows-Windows Defender/Operational for
		Attack Surface Reduction and/or Controlled Folder Access.  Both block-mode
		and audit-mode events are collected, and for Controlled Folder Access the
		file-modification events AND the sector/memory-write events are collected:

			ASR : 1121 (block), 1122 (audit)
			CFA : 1123 (block file), 1124 (audit file),
			      1127 (block sector/memory), 1128 (audit sector/memory)

		Events are parsed from the message text into structured objects.  The Mode
		(block / audit and file / sector) is surfaced through RuleInfo.

		.PARAMETER Filter
		Which event types to return: All (default), ASR, or CFA.

		.PARAMETER Since
		Only return events after this datetime.  Defaults to last system boot time.

		.PARAMETER Like
		Optional wildcard filter applied to ProcessName after retrieval.

		.OUTPUTS
		Array of PSCustomObjects with event details.
	#>
	[CmdletBinding()]
	param
	(
		[ValidateSet('All', 'ASR', 'CFA')]
		[string]$Filter = 'All',

		[datetime]$Since,

		[string]$Like
	)

	# Determine event IDs to collect. ASR: 1121 block, 1122 audit. CFA: 1123 block-file,
	# 1124 audit-file, 1127 block-sector/memory, 1128 audit-sector/memory. Block-only IDs
	# (1121/1123) miss audit-mode activity and CFA sector-write blocks (1127) entirely.
	$EventIDs = switch ($Filter)
	{
		'ASR' { @(1121, 1122) }
		'CFA' { @(1123, 1124, 1127, 1128) }
		default { @(1121, 1122, 1123, 1124, 1127, 1128) }
	}

	# Default Since to last boot time
	if (-not $Since)
	{
		$Since = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
	}

	$Enc = [System.Text.Encoding]::UTF8

	$Results = Get-WinEvent -LogName 'Microsoft-Windows-Windows Defender/Operational' -ErrorAction SilentlyContinue |
	Where-Object { $_.Id -in $EventIDs -and $_.TimeCreated -gt $Since } |
	ForEach-Object {
		$EvRec   = $_
		$Message = [string]::New($Enc.GetBytes($EvRec.Message)) -split "`n"
		$IsASR   = $EvRec.Id -in 1121, 1122

		$Obj = [PSCustomObject][Ordered]@{
			EventID     = [string]$EvRec.Id
			EventType   = if ($IsASR) { 'Attack Surface Reduction' } else { 'Controlled Folder Access' }
			TimeCreated = $EvRec.TimeCreated
			ID          = $null      # ASR only: rule GUID from message
			RuleInfo    = $null      # ASR only: rule description
			Path        = $null
			ProcessName = $null
			User        = $null
		}

		# Parse key:value pairs from the message body
		foreach ($Line in $Message)
		{
			$Parts = $Line -split ':', 2
			if ($Parts.Count -eq 2 -and $Parts[1])
			{
				$Key   = $Parts[0].Trim().Replace(' ', '')
				$Value = $Parts[1].Trim()
				if ($Obj.PSObject.Properties[$Key])
				{ $Obj.$Key = $Value }
			}
		}

		# ASR: resolve rule GUID to description (block and audit both carry a rule GUID);
		# mark audit-mode so the user does not mistake it for an actual block.
		if ($IsASR)
		{
			if ($Obj.ID)
			{ $Obj.RuleInfo = if ($script:ASRRules.Contains($Obj.ID)) { $script:ASRRules[$Obj.ID] } else { 'Unknown rule' } }
			if ($EvRec.Id -eq 1122)
			{ $Obj.RuleInfo = ('{0} (Audit)' -f $(if ($Obj.RuleInfo) { $Obj.RuleInfo } else { 'ASR' })) }
		}
		else
		{
			# CFA has no rule GUID - surface the mode (block/audit, file/sector) in RuleInfo so
			# the otherwise-empty Rule column tells the user what kind of CFA event this is.
			$Obj.RuleInfo = switch ($EvRec.Id)
			{
				1123 { 'Block (file)' }
				1124 { 'Audit (file)' }
				1127 { 'Block (sector/memory)' }
				1128 { 'Audit (sector/memory)' }
				default { 'Controlled Folder Access' }
			}
		}

		# Apply Like filter if specified
		if (-not $Like -or $Obj.ProcessName -ilike "*$Like*")
		{ $Obj }
	}

	$Results
}
