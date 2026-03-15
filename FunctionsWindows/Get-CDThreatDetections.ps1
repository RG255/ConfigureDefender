#requires -Version 5.0
Function Get-CDThreatDetections
{
	<#
		.SYNOPSIS
		Returns Defender threat detection history with human-readable fields.

		.DESCRIPTION
		Joins Get-MpThreatDetection with Get-MpThreat to resolve ThreatID to name,
		severity, and category. All numeric status/action/source fields are translated
		to descriptive strings. No elevation required.

		.PARAMETER Since
		Only return detections on or after this date. Defaults to all history.

		.PARAMETER Filter
		Limits results by remediation outcome:
		  All        - all detections (default)
		  Active     - threats currently marked as active
		  Remediated - successfully cleaned, quarantined, or removed
		  Failed     - remediation was attempted but failed
	#>
	[CmdletBinding()]
	param
	(
		[DateTime]$Since,

		[ValidateSet('All', 'Active', 'Remediated', 'Failed')]
		[string]$Filter = 'All'
	)

	$SeverityMap = @{
		0 = 'Unknown'; 1 = 'Low'; 2 = 'Moderate'; 4 = 'High'; 5 = 'Severe'
	}

	$CategoryMap = @{
		0  = 'Invalid';             1  = 'Adware';              2  = 'Spyware'
		3  = 'PasswordStealer';     4  = 'TrojanDownloader';    5  = 'Worm'
		6  = 'Backdoor';            7  = 'RemoteAccessTrojan';  8  = 'Trojan'
		9  = 'EmailFlooder';        10 = 'Keylogger';           11 = 'Dialer'
		12 = 'MonitoringSoftware';  13 = 'BrowserModifier';     14 = 'Cookie'
		15 = 'BrowserPlugin';       19 = 'JokeProgram';         25 = 'PotentiallyUnwanted'
		28 = 'Exploit';             32 = 'Tool';                38 = 'Virus'
		42 = 'Behavior';            43 = 'VulnerabilityExploit'; 47 = 'Ransomware'
	}

	$SourceMap = @{
		0  = 'Unknown';       1  = 'User';             2  = 'System'
		3  = 'RealTime';      4  = 'IOAV';             5  = 'NIS'
		6  = 'BHO';           7  = 'IEProtect';        8  = 'EarlyLoad'
		9  = 'ScriptedClassic'; 10 = 'ELAM';           11 = 'ScriptedAdvanced'
		12 = 'DLP';           13 = 'Network';          14 = 'AsyncScan'
	}

	$StatusMap = @{
		0   = 'Unknown';        1   = 'Detected';        2   = 'Cleaned'
		3   = 'Quarantined';    4   = 'Removed';         5   = 'Allowed'
		6   = 'Blocked';        102 = 'CleanFailed';     103 = 'QuarantineFailed'
		104 = 'RemoveFailed';   105 = 'AllowFailed';     107 = 'NotSupported'
	}

	$ActionMap = @{
		1 = 'Clean'; 2 = 'Quarantine'; 3 = 'Remove'
		6 = 'Allow'; 8 = 'UserDefined'; 9 = 'NoAction'; 10 = 'Block'
	}

	$ExecMap = @{
		0 = 'Unknown'; 1 = 'Blocked'; 2 = 'Allowed'; 3 = 'Executing'; 4 = 'NotExecuting'
	}

	# Build lookup from Get-MpThreat - name, severity, category per ThreatID
	$ThreatInfo = @{}
	Get-MpThreat -ErrorAction SilentlyContinue | ForEach-Object {
		$ThreatInfo[[int]$_.ThreatID] = $_
	}

	$Detections = @(Get-MpThreatDetection -ErrorAction SilentlyContinue)

	if ($Since)
	{ $Detections = $Detections | Where-Object { $_.InitialDetectionTime -ge $Since } }

	$Detections = $Detections | ForEach-Object {
		$TID    = [int]$_.ThreatID
		$Info   = $ThreatInfo[$TID]
		$Sid    = [int]$_.ThreatStatusID
		$AId    = [int]$_.CleaningActionID
		$SrcId  = [int]$_.DetectionSourceTypeID
		$EId    = [int]$_.CurrentThreatExecutionStatusID

		[PSCustomObject]@{
			Detected      = if ($_.InitialDetectionTime) { $_.InitialDetectionTime } else { $_.LastThreatStatusChangeTime }
			ThreatName    = if ($Info) { $Info.ThreatName } else { "Unknown (ID $TID)" }
			Severity      = if ($Info -and $SeverityMap.ContainsKey([int]$Info.SeverityID))  { $SeverityMap[[int]$Info.SeverityID]  } else { 'Unknown' }
			Category      = if ($Info -and $CategoryMap.ContainsKey([int]$Info.CategoryID))  { $CategoryMap[[int]$Info.CategoryID]  } else { 'Unknown' }
			IsActive      = if ($Info) { [bool]$Info.IsActive } else { $false }
			Status        = if ($StatusMap.ContainsKey($Sid))   { $StatusMap[$Sid]   } else { "Unknown ($Sid)" }
			Action        = if ($ActionMap.ContainsKey($AId))   { $ActionMap[$AId]   } else { "Unknown ($AId)" }
			ActionSuccess = $_.ActionSuccess
			Source        = if ($SourceMap.ContainsKey($SrcId)) { $SourceMap[$SrcId] } else { "Unknown ($SrcId)" }
			Execution     = if ($ExecMap.ContainsKey($EId))     { $ExecMap[$EId]     } else { "Unknown ($EId)" }
			Remediated    = $_.RemediationTime
			User          = $_.DomainUser
			ProcessName   = $_.ProcessName
			Resources     = $_.Resources
			ThreatID      = $TID
			DetectionID   = $_.DetectionID
		}
	}

	switch ($Filter)
	{
		'Active'     { $Detections = $Detections | Where-Object { $_.IsActive } }
		'Remediated' { $Detections = $Detections | Where-Object { $_.Status -in 'Cleaned', 'Quarantined', 'Removed' } }
		'Failed'     { $Detections = $Detections | Where-Object { $_.Status -match 'Failed' } }
	}

	$Detections | Sort-Object Detected -Descending
}
