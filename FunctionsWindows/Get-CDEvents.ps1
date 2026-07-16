#requires -Version 5.0
Function Get-CDEvents
{
	<#
		.SYNOPSIS
		Returns Defender (ASR / CFA) and Smart App Control (SAC / App Control) events.

		.DESCRIPTION
		ASR and Controlled Folder Access events come from Microsoft-Windows-Windows Defender/
		Operational; Smart App Control / App Control (Code Integrity) events come from a DIFFERENT
		log, Microsoft-Windows-CodeIntegrity/Operational. Both block-mode and audit-mode events are
		collected.

			ASR : 1121 (block), 1122 (audit)
			CFA : 1123 (block file), 1124 (audit file),
			      1127 (block sector/memory), 1128 (audit sector/memory)
			SAC : 3077 (blocked, enforcement), 3076 (would-be blocked, audit),
			      3033 (signing-level failure), 3034 (audit signing-level failure),
			      3089 (signature details - folded into the block row via Correlation ActivityId)

		SAC decision events (3077/3033/3089...) that describe ONE load attempt share a Correlation
		ActivityId; they are grouped into a single row, and the 3089 signature record supplies the
		reason (unsigned, or the signer name / signing level). \Device\HarddiskVolumeN paths are
		converted to drive letters. Policy-refresh events (3099) are intentionally NOT returned - there
		are hundreds and they are not app blocks.

		.PARAMETER Filter
		Which event types to return: All (default), ASR, CFA, SAC (blocks), or SAC-Allow.
		SAC-Allow reads Smart App Control ALLOW decisions (event 3090/3091) from the CodeIntegrity
		Verbose channel, which is empty unless that channel was enabled during the load (see
		Set-CDCIVerbose / the Events tab "Log Allows" toggle).

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
		[ValidateSet('All', 'ASR', 'CFA', 'SAC', 'SAC-Allow')]
		[string]$Filter = 'All',

		[datetime]$Since,

		[string]$Like
	)

	if (-not $Since)
	{ $Since = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime }

	$Enc = [System.Text.Encoding]::UTF8
	$Out = [System.Collections.Generic.List[object]]::new()

	# =====================================================================================
	# Defender log: ASR + CFA
	# =====================================================================================
	if ($Filter -in 'All', 'ASR', 'CFA')
	{
		$EventIDs = switch ($Filter)
		{
			'ASR' { @(1121, 1122) }
			'CFA' { @(1123, 1124, 1127, 1128) }
			default { @(1121, 1122, 1123, 1124, 1127, 1128) }
		}

		Get-WinEvent -LogName 'Microsoft-Windows-Windows Defender/Operational' -ErrorAction SilentlyContinue |
			Where-Object { $_.Id -in $EventIDs -and $_.TimeCreated -gt $Since } |
			ForEach-Object {
				$EvRec   = $_
				$Message = [string]::New($Enc.GetBytes($EvRec.Message)) -split "`n"
				$IsASR   = $EvRec.Id -in 1121, 1122

				$Obj = [PSCustomObject][Ordered]@{
					EventID     = [string]$EvRec.Id
					EventType   = if ($IsASR) { 'Attack Surface Reduction' } else { 'Controlled Folder Access' }
					TimeCreated = $EvRec.TimeCreated
					ID          = $null
					RuleInfo    = $null
					Path        = $null
					ProcessName = $null
					User        = $null
				}
				foreach ($Line in $Message)
				{
					$Parts = $Line -split ':', 2
					if ($Parts.Count -eq 2 -and $Parts[1])
					{
						$Key   = $Parts[0].Trim().Replace(' ', '')
						$Value = $Parts[1].Trim()
						if ($Obj.PSObject.Properties[$Key]) { $Obj.$Key = $Value }
					}
				}
				if ($IsASR)
				{
					if ($Obj.ID)
					{ $Obj.RuleInfo = if ($script:ASRRules.Contains($Obj.ID)) { $script:ASRRules[$Obj.ID] } else { 'Unknown rule' } }
					if ($EvRec.Id -eq 1122)
					{ $Obj.RuleInfo = ('{0} (Audit)' -f $(if ($Obj.RuleInfo) { $Obj.RuleInfo } else { 'ASR' })) }
				}
				else
				{
					$Obj.RuleInfo = switch ($EvRec.Id)
					{
						1123 { 'Block (file)' }
						1124 { 'Audit (file)' }
						1127 { 'Block (sector/memory)' }
						1128 { 'Audit (sector/memory)' }
						default { 'Controlled Folder Access' }
					}
				}
				if (-not $Like -or $Obj.ProcessName -ilike "*$Like*") { $Out.Add($Obj) }
			}
	}

	# =====================================================================================
	# CodeIntegrity log: Smart App Control / App Control
	# =====================================================================================
	if ($Filter -in 'All', 'SAC')
	{
		# \Device\HarddiskVolumeN -> drive letter map (QueryDosDevice)
		if (-not ('CDNative.Dev' -as [type]))
		{
			Add-Type -Namespace CDNative -Name Dev -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError = true, CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern uint QueryDosDevice(string lpDeviceName, System.Text.StringBuilder lpTargetPath, uint ucchMax);
'@
		}
		$DevMap = [ordered]@{}
		foreach ($n in 67..90)   # C..Z
		{
			$dl = [char]$n
			$sb = New-Object System.Text.StringBuilder 512
			if ([CDNative.Dev]::QueryDosDevice("$dl`:", $sb, 512) -ne 0) { $DevMap[$sb.ToString()] = "$dl`:" }
		}
		function Convert-Dev([string]$p)
		{
			if (-not $p) { return $p }
			foreach ($dev in $DevMap.Keys)
			{
				if ($p.StartsWith($dev + '\', [System.StringComparison]::OrdinalIgnoreCase))
				{ return $DevMap[$dev] + $p.Substring($dev.Length) }
			}
			return $p
		}

		$SacRaw = @(Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-CodeIntegrity/Operational'; Id = @(3076, 3077, 3033, 3034, 3089, 3118); StartTime = $Since } -ErrorAction SilentlyContinue)

		function ConvertTo-EventDataHash ($EvRecord)
		{
			$Hash = @{}
			foreach ($d in ([xml]$EvRecord.ToXml()).Event.EventData.Data) { $Hash[$d.Name] = $d.'#text' }
			return $Hash
		}
		# SI_SIGNING_LEVEL - only the well-established values are named; others show the raw number
		function Get-SignLevelName ([string]$n)
		{
			switch ($n)
			{
				'0'  { 'Unchecked' }
				'1'  { 'Unsigned' }
				'2'  { 'Enterprise' }
				'4'  { 'Authenticode' }
				'8'  { 'Microsoft' }
				'12' { 'Windows' }
				'14' { 'WindowsTCB' }
				default { if ($n) { "Level $n" } else { '' } }
			}
		}

		# 3089 signature details, keyed by Correlation ActivityId
		$SigByAct = @{}
		foreach ($s in ($SacRaw | Where-Object { $_.Id -eq 3089 }))
		{
			$act = if ($s.ActivityId) { $s.ActivityId.ToString() } else { $null }
			if ($act -and -not $SigByAct.ContainsKey($act)) { $SigByAct[$act] = ConvertTo-EventDataHash $s }
		}

		# 3118 SAC block-details (Defender / ISG reputation), keyed by ActivityId
		$RepByAct = @{}
		foreach ($s in ($SacRaw | Where-Object { $_.Id -eq 3118 }))
		{
			$act = if ($s.ActivityId) { $s.ActivityId.ToString() } else { $null }
			if ($act -and -not $RepByAct.ContainsKey($act)) { $RepByAct[$act] = ConvertTo-EventDataHash $s }
		}

		# Group the block/audit events by ActivityId so 3077 + 3033 (same decision) collapse to one row
		$Blocks = @($SacRaw | Where-Object { $_.Id -in 3076, 3077, 3033, 3034 })
		$Groups = $Blocks | Group-Object { if ($_.ActivityId) { $_.ActivityId.ToString() } else { 'r' + $_.RecordId } }
		foreach ($g in $Groups)
		{
			$Pri  = $g.Group | Sort-Object { switch ($_.Id) { 3077 { 0 } 3076 { 1 } 3033 { 2 } 3034 { 3 } default { 9 } } } | Select-Object -First 1
			$Mode = switch ($Pri.Id) { 3077 { 'Blocked' } 3033 { 'Blocked' } 3076 { 'Audit' } 3034 { 'Audit' } default { 'Blocked' } }

			# The 3077/3076 event carries the file path, hashes, signing levels and policy
			$Full   = $g.Group | Where-Object { $_.Id -in 3077, 3076 } | Select-Object -First 1
			$Ci     = if ($Full) { ConvertTo-EventDataHash $Full } else { @{} }
			$MsgSrc = if ($Full) { $Full.Message } else { $Pri.Message }

			$ProcPath = $null; $FilePath = $null; $ReqLevelName = $null
			if ($MsgSrc -match 'process \((.+?)\) attempted to load (.+?) that did not meet')
			{ $ProcPath = $Matches[1]; $FilePath = $Matches[2] }
			if ($MsgSrc -match 'did not meet the (.+?) signing level requirements') { $ReqLevelName = $Matches[1] }
			if (-not $FilePath -and $Ci['File Name'])    { $FilePath = $Ci['File Name'] }
			if (-not $ProcPath -and $Ci['Process Name']) { $ProcPath = $Ci['Process Name'] }

			$act = if ($Pri.ActivityId) { $Pri.ActivityId.ToString() } else { $null }
			$Sig = if ($act) { $SigByAct[$act] } else { $null }
			$Rep = if ($act) { $RepByAct[$act] } else { $null }

			# Reason (short phrase for the Rule column)
			$Reason = $null
			$Tsc    = -1
			if ($Sig) { $t = 0; if ([int]::TryParse([string]$Sig['TotalSignatureCount'], [ref]$t)) { $Tsc = $t } }
			if ($Tsc -eq 0) { $Reason = 'unsigned' }
			elseif ($Sig -and $Sig['PublisherName'] -and $Sig['PublisherName'] -ne 'Unknown') { $Reason = 'signed by {0}, untrusted' -f $Sig['PublisherName'] }
			elseif ($Sig) { $Reason = 'signature not trusted' }

			# Reputation phrase (for the details view)
			$RepText = $null
			if ($Rep)
			{
				if ($Rep['IsUnfriendlyFile'] -eq 'true') { $RepText = 'flagged as unfriendly' }
				elseif ($Tsc -eq 0) { $RepText = 'no established reputation' }
			}

			# Defender cloud-reputation check (from the 3118 block-details event): SAC always
			# consults Defender and requests a cloud check, but often satisfies it from cache.
			$CloudText = $null
			if ($Rep)
			{
				$WasCalled    = $Rep['DefenderCalled'] -eq 'true'
				$CloudAsked   = $Rep['DefenderCloudCallRequested'] -eq 'true'
				$CloudMade    = $Rep['DefenderMadeCloudCall'] -eq 'true'
				if (-not $WasCalled) { $CloudText = 'Defender not consulted' }
				elseif ($CloudMade)
				{
					$Http = $null
					$Hc   = [string]$Rep['DefenderCloudHTTPCode']
					if ($Hc -match '^0x[0-9a-fA-F]+$')
					{ $Sb = ([Convert]::ToUInt32($Hc, 16) -shr 24); if ($Sb -ge 100 -and $Sb -le 599) { $Http = $Sb } }
					$CloudText = if ($Http) { 'cloud reputation check performed (HTTP {0})' -f $Http } else { 'cloud reputation check performed' }
				}
				elseif ($CloudAsked) { $CloudText = 'cloud check requested but not performed (used cached / local reputation)' }
				else { $CloudText = 'no cloud check requested' }
			}

			# Full forensic detail (only fields with a meaningful value)
			$Details = [Ordered]@{}
			$Details['Detected'] = $Pri.TimeCreated
			$Details['Decision'] = $Mode
			if ($ProcPath) { $Details['Process'] = Convert-Dev $ProcPath }
			if ($FilePath) { $Details['File']    = Convert-Dev $FilePath }
			$Sha = $Ci['SHA256 Hash']
			if ($Sha) { $Details['SHA256'] = $Sha }
			$ReqName = if ($ReqLevelName) { $ReqLevelName } elseif ($Ci['Requested Signing Level']) { Get-SignLevelName $Ci['Requested Signing Level'] } else { $null }
			if ($ReqName) { $Details['Requested signing level'] = $ReqName }
			if ($Ci['Validated Signing Level']) { $Details['Validated signing level'] = Get-SignLevelName $Ci['Validated Signing Level'] }
			if ($Tsc -ge 0) { $Details['Signatures'] = $Tsc }
			if ($Sig -and $Sig['PublisherName'] -and $Sig['PublisherName'] -ne 'Unknown') { $Details['Signer']  = $Sig['PublisherName'] }
			if ($Sig -and $Sig['IssuerName']    -and $Sig['IssuerName']    -ne 'Unknown') { $Details['Issuer']  = $Sig['IssuerName'] }
			if ($Sig -and $Tsc -gt 0 -and $null -ne $Sig['KnownRoot']) { $Details['Chains to trusted root'] = if ($Sig['KnownRoot'] -eq '0') { 'No' } else { 'Yes' } }
			if ($Sig -and $Sig['VerificationError'] -and $Sig['VerificationError'] -ne '0') { $Details['Verification error'] = $Sig['VerificationError'] }
			if ($Sig -and $Sig['NotValidBefore'] -and $Sig['NotValidBefore'] -notlike '1601-*') { $Details['Cert valid from'] = $Sig['NotValidBefore'] }
			if ($Sig -and $Sig['NotValidAfter']  -and $Sig['NotValidAfter']  -notlike '1601-*') { $Details['Cert valid to']   = $Sig['NotValidAfter'] }
			if ($RepText) { $Details['Reputation'] = $RepText }
			if ($CloudText) { $Details['Defender cloud check'] = $CloudText }
			if ($Rep -and $Rep['DefenderThreatName']) { $Details['Threat name'] = $Rep['DefenderThreatName'] }
			if ($Rep -and $Rep['DefenderStatusCode'] -and $Rep['DefenderStatusCode'] -ne '0x0') { $Details['Defender status'] = $Rep['DefenderStatusCode'] }
			if ($Ci['SI Signing Scenario']) { $Details['Signing scenario'] = switch ($Ci['SI Signing Scenario']) { '1' { 'User mode' } '0' { 'Kernel / driver' } default { $Ci['SI Signing Scenario'] } } }
			if ($Ci['UserWriteable']) { $Details['File user-writeable'] = if ($Ci['UserWriteable'] -eq 'true') { 'Yes' } else { 'No' } }
			if ($Ci['FileVersion'] -and $Ci['FileVersion'] -ne '0.0.0.0') { $Details['File version'] = $Ci['FileVersion'] }
			if ($Ci['PolicyName']) { $Details['SAC policy']  = $Ci['PolicyName'] }
			if ($Ci['PolicyGUID']) { $Details['Policy GUID'] = $Ci['PolicyGUID'] }
			if ($Ci['Status'])     { $Details['CI status']   = $Ci['Status'] }

			$Obj = [PSCustomObject][Ordered]@{
				EventID     = [string]$Pri.Id
				EventType   = 'Smart App Control (blocked)'
				TimeCreated = $Pri.TimeCreated
				ID          = $act
				RuleInfo    = if ($Reason) { '{0} - {1}' -f $Mode, $Reason } else { $Mode }
				Path        = Convert-Dev $FilePath
				ProcessName = if ($ProcPath) { [System.IO.Path]::GetFileName((Convert-Dev $ProcPath)) } else { $null }
				User        = $null
				Sha256      = $Sha
				Details     = $Details
			}
			if (-not $Like -or $Obj.ProcessName -ilike "*$Like*") { $Out.Add($Obj) }
		}
	}

	# =====================================================================================
	# CodeIntegrity Verbose log: SAC ALLOW decisions (event 3090 / 3091). Only populated while
	# the high-volume Verbose channel is enabled (see Set-CDCIVerbose and the Events tab
	# "Log Allows" toggle). Reading needs no elevation (the channel grants Interactive Users
	# read). Self-contained: it re-derives its own drive-letter map and helpers so it does not
	# depend on the block branch above having run.
	# =====================================================================================
	if ($Filter -eq 'SAC-Allow')
	{
		if (-not ('CDNative.Dev' -as [type]))
		{
			Add-Type -Namespace CDNative -Name Dev -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError = true, CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern uint QueryDosDevice(string lpDeviceName, System.Text.StringBuilder lpTargetPath, uint ucchMax);
'@
		}
		$DevMapA = [ordered]@{}
		foreach ($n in 67..90)
		{
			$dl = [char]$n
			$sb = New-Object System.Text.StringBuilder 512
			if ([CDNative.Dev]::QueryDosDevice("$dl`:", $sb, 512) -ne 0) { $DevMapA[$sb.ToString()] = "$dl`:" }
		}
		function Convert-DevA([string]$p)
		{
			if (-not $p) { return $p }
			foreach ($dev in $DevMapA.Keys)
			{
				if ($p.StartsWith($dev + '\', [System.StringComparison]::OrdinalIgnoreCase))
				{ return $DevMapA[$dev] + $p.Substring($dev.Length) }
			}
			return $p
		}
		function Get-LevelA([string]$n)
		{
			switch ($n) { '0' { 'Unchecked' } '1' { 'Unsigned' } '2' { 'Enterprise' } '4' { 'Authenticode' } '8' { 'Microsoft' } '12' { 'Windows' } '14' { 'WindowsTCB' } default { if ($n) { "Level $n" } else { '' } } }
		}

		# SAC does NOT emit 3090 here. The ALLOW decision is event 3075 ("...to load X with validated
		# <Level> signing level"); event 3088 (per-module policy test) gives the WHY (Smartlocker,
		# Defender trust, policy). Readable even after the channel is disabled again.
		$VerRaw = @(Get-WinEvent -LogName 'Microsoft-Windows-CodeIntegrity/Verbose' -Oldest -ErrorAction SilentlyContinue |
				Where-Object { $_.Id -in 3075, 3088 -and $_.TimeCreated -gt $Since })
		$TestByFile = @{}
		foreach ($te in ($VerRaw | Where-Object { $_.Id -eq 3088 }))
		{
			$td = @{}
			foreach ($d in ([xml]$te.ToXml()).Event.EventData.Data) { $td[$d.Name] = $d.'#text' }
			$fn = $td['FileName']
			if ($fn) { $fk = Split-Path $fn -Leaf; if (-not $TestByFile.ContainsKey($fk)) { $TestByFile[$fk] = $td } }
		}
		foreach ($e in ($VerRaw | Where-Object { $_.Id -eq 3075 }))
		{
			$Cd = @{}
			foreach ($d in ([xml]$e.ToXml()).Event.EventData.Data) { $Cd[$d.Name] = $d.'#text' }
			$ProcPath = $null; $FilePath = $null; $LvName = $null
			if ($e.Message -match 'process \((.+?)\) spent .+? to load (.+?) with validated (.+?) signing level')
			{ $ProcPath = $Matches[1]; $FilePath = $Matches[2]; $LvName = $Matches[3] }
			if (-not $LvName -and $Cd['ValidatedSigningLevel']) { $LvName = Get-LevelA $Cd['ValidatedSigningLevel'] }
			$FileConv = Convert-DevA $FilePath
			$Test = if ($FileConv) { $TestByFile[(Split-Path $FileConv -Leaf)] } else { $null }
			$DetailsA = [Ordered]@{}
			$DetailsA['Detected'] = $e.TimeCreated
			$DetailsA['Decision'] = 'Allowed'
			if ($ProcPath) { $DetailsA['Loaded by'] = Convert-DevA $ProcPath }
			if ($FileConv) { $DetailsA['File'] = $FileConv }
			if ($Cd['RequestedSigningLevel']) { $DetailsA['Requested signing level'] = Get-LevelA $Cd['RequestedSigningLevel'] }
			if ($LvName) { $DetailsA['Validated signing level'] = $LvName }
			if ($Test)
			{
				if ($Test['PolicyName']) { $DetailsA['SAC policy'] = $Test['PolicyName'] }
				if ($Test['SmartlockerEnabled']) { $DetailsA['Smartlocker'] = $Test['SmartlockerEnabled'] }
				if ($Test['PassesSmartlocker']) { $DetailsA['Passes Smartlocker'] = $Test['PassesSmartlocker'] }
				if ($Test['ManagedInstallerEnabled']) { $DetailsA['Managed installer'] = $Test['ManagedInstallerEnabled'] }
				if ($Test['DefenderTrust']) { $DetailsA['Defender trust'] = $Test['DefenderTrust'] }
				if ($Test['StatusCode']) { $DetailsA['CI status'] = $Test['StatusCode'] }
			}
			if ($Cd['ElapsedTime']) { $DetailsA['CI check (microsec)'] = $Cd['ElapsedTime'] }
			$DetailsA['Event'] = ($e.Message -split "`n")[0]
			$Obj = [PSCustomObject][Ordered]@{
				EventID     = [string]$e.Id
				EventType   = 'Smart App Control (allowed)'
				TimeCreated = $e.TimeCreated
				ID          = if ($e.ActivityId) { $e.ActivityId.ToString() } else { $null }
				RuleInfo    = if ($LvName) { 'Allowed - validated {0}' -f $LvName } else { 'Allowed' }
				Path        = $FileConv
				ProcessName = if ($ProcPath) { [System.IO.Path]::GetFileName((Convert-DevA $ProcPath)) } else { $null }
				User        = $null
				Sha256      = $null
				Details     = $DetailsA
			}
			if (-not $Like -or $Obj.ProcessName -ilike "*$Like*") { $Out.Add($Obj) }
		}
	}

	$Out | Sort-Object TimeCreated -Descending
}
