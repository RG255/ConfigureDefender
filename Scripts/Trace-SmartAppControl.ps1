#requires -Version 5.1
#requires -RunAsAdministrator
<#
	.SYNOPSIS
	Briefly enables the Code Integrity Verbose channel, captures Smart App Control / App Control
	image-load decisions (allows AND blocks) for a short window, then always disables it again.

	.DESCRIPTION
	Smart App Control only logs BLOCKS to Microsoft-Windows-CodeIntegrity/Operational; successful
	("allowed") loads are recorded only in the high-volume Microsoft-Windows-CodeIntegrity/Verbose
	channel, which is disabled by default. This helper turns that channel on just long enough to
	observe why a specific app is ALLOWED - so you can compare a passing app against a failing one -
	then turns it back off. The channel is disabled again in a finally block even on error.

	Run from an ELEVATED PowerShell (the script self-enforces this). The Verbose channel is noisy
	(every image load system-wide), so keep the window short and filter with -Match.

	.PARAMETER Path
	Optional executable to launch after enabling the channel. If omitted, use -Interactive and
	reproduce the load yourself.

	.PARAMETER ArgumentList
	Optional arguments passed to -Path.

	.PARAMETER Match
	Case-insensitive substring; only events whose message mentions it are kept (e.g. an app name or
	folder). Defaults to the leaf name of -Path. Use -IncludeAll to keep everything.

	.PARAMETER Seconds
	Capture window in seconds when not using -Interactive. Default 15.

	.PARAMETER Interactive
	Prompt you to reproduce the load, then press Enter to stop capturing (instead of a fixed window).

	.PARAMETER IncludeAll
	Do not filter by -Match; return every Code Integrity Verbose event in the window (very noisy).

	.PARAMETER MaxEvents
	Cap on returned events. Default 300.

	.EXAMPLE
	# Capture the allow decisions while launching a known-good signed app
	.\Trace-SmartAppControl.ps1 -Path 'C:\Windows\System32\notepad.exe' -Seconds 8

	.EXAMPLE
	# Manual repro of a blocked app - launch it yourself during the capture, then compare
	.\Trace-SmartAppControl.ps1 -Match 'Sunny Explorer' -Interactive

	.NOTES
	Returns objects: TimeCreated, Id, Decision, Process, File, RequestedLevel, ValidatedLevel,
	Publisher, Sha256, Message. Pipe to Format-Table -Auto or Out-GridView.

	The Decision column is a best-effort map from event Id; the Message column is authoritative.
	The block IDs match Get-CDEvents (3077/3033 blocked, 3076/3034 audit); allow IDs (3090/3091/3092)
	and 3115 (allowed under audit policy) are labelled Allowed. Refine the map if a run shows an
	unmapped Id carrying an allow message.
#>
[CmdletBinding()]
param
(
	[string]$Path,
	[string[]]$ArgumentList,
	[string]$Match,
	[int]$Seconds = 15,
	[switch]$Interactive,
	[switch]$IncludeAll,
	[int]$MaxEvents = 300
)

$Channel = 'Microsoft-Windows-CodeIntegrity/Verbose'

if (-not $Match -and $Path) { $Match = [System.IO.Path]::GetFileNameWithoutExtension($Path) }

function ConvertTo-CiHash ($EvRecord)
{
	$Hash = @{}
	foreach ($d in ([xml]$EvRecord.ToXml()).Event.EventData.Data) { $Hash[$d.Name] = $d.'#text' }
	return $Hash
}
function Get-CiLevelName ([string]$n)
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

Write-Host ("Enabling {0} ..." -f $Channel) -ForegroundColor Cyan
& wevtutil.exe sl "$Channel" /e:true
if ($LASTEXITCODE -ne 0) { throw ("Failed to enable channel (wevtutil exit {0}). Run from an elevated prompt." -f $LASTEXITCODE) }

$Start   = Get-Date
$Results = New-Object System.Collections.Generic.List[object]
try
{
	if ($Path)
	{
		Write-Host ("Launching {0} ..." -f $Path) -ForegroundColor Cyan
		if ($ArgumentList) { Start-Process -FilePath $Path -ArgumentList $ArgumentList -ErrorAction SilentlyContinue }
		else               { Start-Process -FilePath $Path -ErrorAction SilentlyContinue }
	}

	if ($Interactive)
	{
		[void](Read-Host 'Reproduce the app launch / load now, then press Enter to stop capturing')
	}
	else
	{
		Write-Host ("Capturing for {0}s ..." -f $Seconds) -ForegroundColor Cyan
		Start-Sleep -Seconds $Seconds
	}

	Write-Host 'Reading captured events ...' -ForegroundColor Cyan
	$Raw = @(Get-WinEvent -LogName $Channel -Oldest -ErrorAction SilentlyContinue |
			Where-Object { $_.TimeCreated -ge $Start })

	foreach ($e in $Raw)
	{
		if (-not $IncludeAll -and $Match -and ($e.Message -notmatch [regex]::Escape($Match))) { continue }

		$Line = ($e.Message -split "`n")[0]
		$H    = ConvertTo-CiHash $e

		# Field names differ by event: 3077 uses 'File Name'/'Process Name'/'SHA256 Hash';
		# 3115/3118 use 'FileName'/'ProcessName'/'SHA256Hash'. Try both.
		$Proc = $null; $File = $null
		if ($e.Message -match 'process \((.+?)\)')                   { $Proc = $Matches[1] }
		if (-not $Proc -and $H['Process Name'])                      { $Proc = $H['Process Name'] }
		if (-not $Proc -and $H['ProcessName'])                       { $Proc = $H['ProcessName'] }
		if ($e.Message -match 'load (.+?)(?: that | which | with |,|\.$)')  { $File = $Matches[1] }
		if (-not $File -and $H['File Name'])                         { $File = $H['File Name'] }
		if (-not $File -and $H['FileName'])                          { $File = $H['FileName'] }

		$Decision = switch ($e.Id)
		{
			3075 { 'Allowed' }          # SAC allow decision (Verbose): "...validated <Level> signing level"
			3090 { 'Allowed' }
			3091 { 'Allowed' }
			3092 { 'Allowed' }
			3077 { 'Blocked' }
			3033 { 'Blocked' }
			3076 { 'Audit' }
			3034 { 'Audit' }
			3115 { 'Allowed (audit)' }
			3088 { 'Policy test' }      # per-module test (Smartlocker / Defender trust / policy)
			3089 { 'Signature info' }
			default { 'Info' }
		}

		$Results.Add([PSCustomObject][Ordered]@{
			TimeCreated    = $e.TimeCreated
			Id             = $e.Id
			Decision       = $Decision
			Process        = if ($Proc) { [System.IO.Path]::GetFileName($Proc) } else { '' }
			File           = $File
			RequestedLevel = Get-CiLevelName $H['Requested Signing Level']
			ValidatedLevel = Get-CiLevelName $H['Validated Signing Level']
			Publisher      = $H['PublisherName']
			Sha256         = if ($H['SHA256 Hash']) { $H['SHA256 Hash'] } else { $H['SHA256Hash'] }
			Message        = $Line
		})
		if ($Results.Count -ge $MaxEvents) { break }
	}
}
finally
{
	& wevtutil.exe sl "$Channel" /e:false
	Write-Host ("{0} disabled again." -f $Channel) -ForegroundColor Green
}

Write-Host ("`nCaptured {0} matching event(s) in the window." -f $Results.Count)
$ByDecision = $Results | Group-Object Decision | ForEach-Object { '{0}={1}' -f $_.Name, $_.Count }
if ($ByDecision) { Write-Host ('  ' + ($ByDecision -join '   ')) }
if ($Results.Count -eq 0)
{
	Write-Host '  (nothing matched - the app may not have triggered CI-checked loads, or widen -Seconds / use -IncludeAll)' -ForegroundColor Yellow
}
$Results
