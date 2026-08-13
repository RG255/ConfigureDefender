#requires -Version 5.0
Function Set-CDCIVerbose
{
	<#
		.SYNOPSIS
		Enables or disables the Microsoft-Windows-CodeIntegrity/Verbose channel (SAC allow logging) and
		manages a self-deleting watchdog scheduled task that guarantees it is turned off again.

		.DESCRIPTION
		Smart App Control records BLOCKS in the Operational log but successful ALLOW decisions only in
		the CodeIntegrity/Verbose channel - a high-volume Debug channel disabled by default. Toggling a
		channel modifies event-log configuration and requires elevation, so this runs on the elevated
		NamedPipe server. Reading the captured allows afterwards does NOT need elevation.

		Uses the in-process EventLogConfiguration API (Get-WinEvent -ListLog + SaveChanges), NOT
		wevtutil.exe: the elevated pipe server has no console and launching an external process there
		can deadlock and hang the GUI.

		The enable/disable flag is saved on its OWN SaveChanges - a Debug channel rejects the flag combined
		with size/mode changes ("The parameter is incorrect"). Widening to 128 MB (the channel keeps its
		manifest LogMode = Retain and rejects Circular, so it STOPS when full - hence the large cap) is
		done as separate, best-effort saves; if the channel rejects them the default 1 MB stands and
		logging still works. On enable a watchdog scheduled task
		(runs as SYSTEM) is registered that disables the channel again then self-deletes - always with an
		AtStartup trigger (so a reboot turns it off even after a GUI crash), plus a timed trigger when
		-WatchdogMinutes is given. On disable the default cap is restored and the watchdog removed.

		.PARAMETER Disable
		Disable the channel, restore the default cap, and remove the watchdog. Omit to enable.

		.PARAMETER WatchdogMinutes
		When enabling, also auto-disable this many minutes from now (in addition to the always-present
		next-reboot safety). 0 = reboot-only safety (stays on until manually stopped).

		.OUTPUTS
		PSCustomObject with Channel, Enabled, MaxSizeMB and Watchdog.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Toggles a single event-log channel via the GUI toggle / pipe; no per-item confirmation applies.')]
	[CmdletBinding()]
	param
	(
		[switch]$Disable,

		[int]$WatchdogMinutes = 0
	)

	$Channel      = 'Microsoft-Windows-CodeIntegrity/Verbose'
	$TaskName     = 'ConfigureDefender-SACVerboseWatchdog'
	$DefaultBytes = 1052672

	if ($Disable)
	{
		# Critical: disable the channel (its own SaveChanges).
		$Log = Get-WinEvent -ListLog $Channel -ErrorAction Stop
		$Log.IsEnabled = $false
		$Log.SaveChanges()
		# Best-effort: restore the default cap / mode while disabled (separate saves).
		try { $C = Get-WinEvent -ListLog $Channel -ErrorAction Stop; $C.MaximumSizeInBytes = $DefaultBytes; $C.SaveChanges() } catch { $null = $_ }
		try { $C = Get-WinEvent -ListLog $Channel -ErrorAction Stop; $C.LogMode = [System.Diagnostics.Eventing.Reader.EventLogMode]::Retain; $C.SaveChanges() } catch { $null = $_ }
		Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
	}
	else
	{
		# Best-effort: widen to 128 MB so a long session does not fill up (this Debug channel keeps its
		# manifest LogMode = Retain and rejects Circular, so it STOPS when full - hence the large cap).
		# Circular is still attempted in case a future build allows it. Separate saves, each on its own;
		# a rejected size/mode change just leaves the 1 MB default and logging still works.
		try { $C = Get-WinEvent -ListLog $Channel -ErrorAction Stop; $C.MaximumSizeInBytes = 134217728; $C.SaveChanges() } catch { $null = $_ }
		try { $C = Get-WinEvent -ListLog $Channel -ErrorAction Stop; $C.LogMode = [System.Diagnostics.Eventing.Reader.EventLogMode]::Circular; $C.SaveChanges() } catch { $null = $_ }

		# Critical: enable the channel (its own SaveChanges).
		$On = Get-WinEvent -ListLog $Channel -ErrorAction Stop
		$On.IsEnabled = $true
		$On.SaveChanges()

		# (Re)register the watchdog: AtStartup always, plus a timed trigger when requested. The action
		# disables the channel again and deletes the task; it runs even if the GUI is killed.
		Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
		$WdCmd = "wevtutil sl '$Channel' /e:false; schtasks /delete /tn '$TaskName' /f"
		$Act   = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -WindowStyle Hidden -Command "{0}"' -f $WdCmd)
		$Trg   = @(New-ScheduledTaskTrigger -AtStartup)
		if ($WatchdogMinutes -gt 0) { $Trg += New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes($WatchdogMinutes) }
		$Prn   = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
		$null  = Register-ScheduledTask -TaskName $TaskName -Action $Act -Trigger $Trg -Principal $Prn -Force
	}

	$Now = Get-WinEvent -ListLog $Channel -ErrorAction SilentlyContinue
	[PSCustomObject]@{
		Channel   = $Channel
		Enabled   = [bool]($Now.IsEnabled)
		MaxSizeMB = if ($Now) { [math]::Round($Now.MaximumSizeInBytes / 1MB, 0) } else { 0 }
		Watchdog  = if ($Disable) { 'removed' } elseif ($WatchdogMinutes -gt 0) { "reboot + $WatchdogMinutes min" } else { 'reboot only' }
	}
}
