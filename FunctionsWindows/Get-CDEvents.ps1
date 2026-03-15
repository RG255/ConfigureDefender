#requires -Version 5.0
Function Get-CDEvents
{
	<#
		.SYNOPSIS
		Returns Defender events from the Windows event log.

		.DESCRIPTION
		Retrieves events from Microsoft-Windows-Windows Defender/Operational for
		Attack Surface Reduction (Event ID 1121) and/or Controlled Folder Access
		(Event ID 1123) violations.  Events are parsed from the message text into
		structured objects.

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

	# Determine event IDs to collect
	$EventIDs = switch ($Filter)
	{
		'ASR' { @(1121) }
		'CFA' { @(1123) }
		default { @(1121, 1123) }
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

		$Obj = [PSCustomObject][Ordered]@{
			EventID     = [string]$EvRec.Id
			EventType   = if ($EvRec.Id -eq 1121) { 'Attack Surface Reduction' } else { 'Controlled Folder Access' }
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

		# Resolve rule GUID to description (ASR only)
		if ($EvRec.Id -eq 1121 -and $Obj.ID)
		{
			$Obj.RuleInfo = if ($script:ASRRules.Contains($Obj.ID)) { $script:ASRRules[$Obj.ID] } else { 'Unknown rule' }
		}

		# Apply Like filter if specified
		if (-not $Like -or $Obj.ProcessName -ilike "*$Like*")
		{ $Obj }
	}

	$Results
}
