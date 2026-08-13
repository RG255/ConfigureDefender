#region Tab 10 - Threat Actions
$TabThreat = New-Tab 'Threat Actions'

$ToolStripThreat      = New-Object System.Windows.Forms.ToolStrip
$ToolStripThreat.Dock = 'Top'

$TsBtnThreatRefresh              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnThreatRefresh.Text         = 'Refresh'
$TsBtnThreatRefresh.DisplayStyle = 'Text'
$TsBtnThreatRefresh.ToolTipText  = 'Refresh threat actions from Windows Defender'
$ToolStripThreat.Items.Add($TsBtnThreatRefresh) | Out-Null

$ToolStripThreat.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$TsBtnThreatSetAction                   = New-Object System.Windows.Forms.ToolStripDropDownButton
$TsBtnThreatSetAction.Text              = 'Set Action'
$TsBtnThreatSetAction.DisplayStyle      = 'Text'
$TsBtnThreatSetAction.ShowDropDownArrow = $true

$ThreatActionHandler = {
	$Action   = $this.Tag
	$Selected = @($LvThreat.SelectedItems)
	if ($Selected.Count -eq 0) { $StatusLabel.Text = 'No threat level selected.'; return }
	try
	{
		$SRP      = Get-CDSRP
		$Ok       = 0
		$ErrCount = 0
		foreach ($Li in $Selected)
		{
			$Level = $Li.Tag
			$SRP.DataObject = "Set-CDThreatAction -Level '$Level' -Action '$Action'" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error)
			{ $ErrCount++; $StatusLabel.Text = "Error on $Level : $($SRP.DataObject.Error)" }
			else
			{ $Li.SubItems[1].Text = $Action; $Ok++ }
		}
		if ($ErrCount -eq 0) { $StatusLabel.Text = "$Ok threat level(s) set to $Action." }
		else { $StatusLabel.Text = "$Ok set, $ErrCount error(s)." }
	}
	catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
}

foreach ($ActionName in @('Clean', 'Quarantine', 'Remove', 'Allow', 'Block', 'NoAction', 'UserDefined'))
{
	$Item     = New-Object System.Windows.Forms.ToolStripMenuItem($ActionName)
	$Item.Tag = $ActionName
	$Item.Add_Click($ThreatActionHandler)
	$TsBtnThreatSetAction.DropDownItems.Add($Item) | Out-Null
}
$ToolStripThreat.Items.Add($TsBtnThreatSetAction) | Out-Null

$LvThreat               = New-Object System.Windows.Forms.ListView
$LvThreat.Dock          = 'Fill'
$LvThreat.View          = 'Details'
$LvThreat.FullRowSelect = $true
$LvThreat.GridLines     = $true
$LvThreat.MultiSelect   = $true
$LvThreat.Columns.Add('Threat Level', 150) | Out-Null
$LvThreat.Columns.Add('Action',       200) | Out-Null
$LvThreat.Add_SizeChanged({
	$w = $LvThreat.ClientSize.Width - 150 - 22
	if ($w -gt 100) { $LvThreat.Columns[1].Width = $w }
})

$TabThreat.Controls.Add($LvThreat)
$TabThreat.Controls.Add($ToolStripThreat)

$TsBtnThreatRefresh.Add_Click({
	$StatusLabel.Text = 'Loading...'
	$Form.UseWaitCursor = $true
	[System.Windows.Forms.Application]::DoEvents()
	$LvThreat.Items.Clear()
	try
	{
		foreach ($T in @(Get-CDThreatActions))
		{
			$Li = New-Object System.Windows.Forms.ListViewItem($T.Level)
			$Li.SubItems.Add($T.Action) | Out-Null
			$Li.Tag = $T.Level
			$LvThreat.Items.Add($Li) | Out-Null
		}
		$StatusLabel.Text = "Threat Actions loaded."
	}
	catch { $StatusLabel.Text = 'Error loading Threat Actions: ' + $_.Exception.Message }
	finally { $Form.UseWaitCursor = $false }
})
#endregion

#region Tab 11 - Events
$TabEvents = New-Tab 'Events'

$ToolStripEvents      = New-Object System.Windows.Forms.ToolStrip
$ToolStripEvents.Dock = 'Top'

$TsBtnEvRefresh              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnEvRefresh.Text         = 'Refresh'
$TsBtnEvRefresh.DisplayStyle = 'Text'
$TsBtnEvRefresh.ToolTipText  = 'Refresh events from the Windows Defender event log'
$ToolStripEvents.Items.Add($TsBtnEvRefresh) | Out-Null

$TsBtnEvAdd              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnEvAdd.Text         = 'Add as Exclusion'
$TsBtnEvAdd.DisplayStyle = 'Text'
$TsBtnEvAdd.ToolTipText  = 'Select one event row first, then click to add its path as an exclusion'
$ToolStripEvents.Items.Add($TsBtnEvAdd) | Out-Null

$TsBtnEvDetails              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnEvDetails.Text         = 'Details'
$TsBtnEvDetails.DisplayStyle = 'Text'
$TsBtnEvDetails.ToolTipText  = 'Show full block details for the selected Smart App Control event (or double-click the row)'
$ToolStripEvents.Items.Add($TsBtnEvDetails) | Out-Null

$ToolStripEvents.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
$ToolStripEvents.Items.Add((New-Object System.Windows.Forms.ToolStripLabel('  Filter:'))) | Out-Null

$TsCmbEvFilter               = New-Object System.Windows.Forms.ToolStripComboBox
$TsCmbEvFilter.DropDownStyle = 'DropDownList'
$TsCmbEvFilter.Width         = 95
$TsCmbEvFilter.Items.AddRange(@('All', 'ASR', 'CFA', 'SAC', 'SAC-Allow'))
$TsCmbEvFilter.SelectedIndex = 0
$ToolStripEvents.Items.Add($TsCmbEvFilter) | Out-Null

$ToolStripEvents.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
$ToolStripEvents.Items.Add((New-Object System.Windows.Forms.ToolStripLabel('Since:'))) | Out-Null

$TsCmbEvSince               = New-Object System.Windows.Forms.ToolStripComboBox
$TsCmbEvSince.DropDownStyle = 'DropDownList'
$TsCmbEvSince.Width         = 100
$TsCmbEvSince.Items.AddRange(@('Since Boot', 'Today', 'Yesterday', 'Last 7 Days', 'Last 30 Days', 'Custom Date'))
$TsCmbEvSince.SelectedIndex = 0
$ToolStripEvents.Items.Add($TsCmbEvSince) | Out-Null

$EvDatePicker            = New-Object System.Windows.Forms.DateTimePicker
$EvDatePicker.Format     = [System.Windows.Forms.DateTimePickerFormat]::Short
$EvDatePicker.Value      = [datetime]::Today
$EvDatePickerHost          = New-Object System.Windows.Forms.ToolStripControlHost($EvDatePicker)
$EvDatePickerHost.AutoSize = $false
$EvDatePickerHost.Size     = New-Object System.Drawing.Size(100, 22)
$EvDatePickerHost.Visible  = $false
$ToolStripEvents.Items.Add($EvDatePickerHost) | Out-Null

$ToolStripEvents.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
$ToolStripEvents.Items.Add((New-Object System.Windows.Forms.ToolStripLabel('SAC Allows:'))) | Out-Null
$TsBtnLogAllows              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnLogAllows.Text         = 'Log'
$TsBtnLogAllows.DisplayStyle = 'Text'
$TsBtnLogAllows.CheckOnClick = $true
$TsBtnLogAllows.ToolTipText  = 'Toggle CodeIntegrity Verbose logging to capture SAC allow decisions (event 3075). High volume - turn OFF when done. Then pick the SAC-Allow filter and Refresh to view. Re-enabling CLEARS the previous capture (you will be offered a save first).'
$ToolStripEvents.Items.Add($TsBtnLogAllows) | Out-Null

$TsBtnSaveAllows              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnSaveAllows.Text         = 'Save'
$TsBtnSaveAllows.DisplayStyle = 'Text'
$TsBtnSaveAllows.ToolTipText  = 'Save the currently captured SAC allow events to a CSV file'
$ToolStripEvents.Items.Add($TsBtnSaveAllows) | Out-Null

$TsBtnOpenAllows              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnOpenAllows.Text         = 'Open'
$TsBtnOpenAllows.DisplayStyle = 'Text'
$TsBtnOpenAllows.ToolTipText  = 'Open a previously saved SAC allows CSV and view it in the grid (Refresh reverts to live events)'
$ToolStripEvents.Items.Add($TsBtnOpenAllows) | Out-Null

$ToolStripEvents.Items.Add((New-Object System.Windows.Forms.ToolStripLabel('Auto-off min:'))) | Out-Null
$TsTxtAutoOff              = New-Object System.Windows.Forms.ToolStripTextBox
$TsTxtAutoOff.Text         = '15'
$TsTxtAutoOff.AutoSize     = $false
$TsTxtAutoOff.Width        = 36
$TsTxtAutoOff.ToolTipText  = 'Minutes before SAC allow logging auto-disables. 0 = stay on until you click Log. A next-reboot safety-off is always set.'
$ToolStripEvents.Items.Add($TsTxtAutoOff) | Out-Null

$ToolStripEvents.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
$ToolStripEvents.Items.Add((New-Object System.Windows.Forms.ToolStripLabel('Find:'))) | Out-Null
$TsTxtFind              = New-Object System.Windows.Forms.ToolStripTextBox
$TsTxtFind.AutoSize     = $false
$TsTxtFind.Width        = 130
$TsTxtFind.ToolTipText  = 'Filter the shown rows to those matching this text in ANY column (process, path/DLL, rule, or any detail field) - so related entries correlate across columns. Use after Open to isolate one program, then Save keeps just the shown rows.'
$ToolStripEvents.Items.Add($TsTxtFind) | Out-Null

$TsCmbEvFilter.Add_SelectedIndexChanged({ $TsBtnEvRefresh.PerformClick() })

$TsCmbEvSince.Add_SelectedIndexChanged({
	$EvDatePickerHost.Visible = ($TsCmbEvSince.SelectedItem -eq 'Custom Date')
	if ($TsCmbEvSince.SelectedItem -ne 'Custom Date') { $TsBtnEvRefresh.PerformClick() }
})

$EvDatePicker.Add_ValueChanged({ $TsBtnEvRefresh.PerformClick() })

$LvEvents               = New-Object System.Windows.Forms.ListView
$LvEvents.Dock          = 'Fill'
$LvEvents.View          = 'Details'
$LvEvents.FullRowSelect = $true
$LvEvents.GridLines     = $true
$LvEvents.Columns.Add('Time',        145) | Out-Null
$LvEvents.Columns.Add('Type',        175) | Out-Null
$LvEvents.Columns.Add('ProcessName', 200) | Out-Null
$LvEvents.Columns.Add('Path',        260) | Out-Null
$LvEvents.Columns.Add('Rule',        180) | Out-Null
$LvEvents.Add_SizeChanged({
	$w = $LvEvents.ClientSize.Width - 145 - 175 - 200 - 260 - 22
	if ($w -gt 60) { $LvEvents.Columns[4].Width = $w }
})

$TabEvents.Controls.Add($LvEvents)
$TabEvents.Controls.Add($ToolStripEvents)

$TsBtnEvRefresh.Add_Click({
	if ($script:EvRefreshing) { return }
	$script:EvRefreshing = $true
	$script:EvFindBusy = $true; $TsTxtFind.Text = ''; $script:EvFindBusy = $false
	$StatusLabel.Text = 'Loading...'
	$Form.UseWaitCursor = $true
	[System.Windows.Forms.Application]::DoEvents()
	try
	{
		$FilterVal = if ($TsCmbEvFilter.SelectedItem)  { $TsCmbEvFilter.SelectedItem.ToString()  } else { 'All' }
		$SinceKey  = if ($TsCmbEvSince.SelectedItem)   { $TsCmbEvSince.SelectedItem.ToString()   } else { 'Since Boot' }
		$Since     = switch ($SinceKey)
		{
			'Today'        { [datetime]::Today }
			'Yesterday'    { [datetime]::Today.AddDays(-1) }
			'Last 7 Days'  { [datetime]::Today.AddDays(-7) }
			'Last 30 Days' { [datetime]::Today.AddDays(-30) }
			'Custom Date'  { $EvDatePicker.Value.Date }
			default        { $null }  # Since Boot - Get-CDEvents default
		}
		# Clear immediately so old data does not persist while fetching
		$LvEvents.Items.Clear()
		[System.Windows.Forms.Application]::DoEvents()
		# Force cursor after all DoEvents so dropdown-close events cannot reset it
		[System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::WaitCursor
		[array]$Events = if ($Since) { Get-CDEvents -Filter $FilterVal -Since $Since }
		                 else         { Get-CDEvents -Filter $FilterVal }
		$script:GridRows   = @($Events)
		$script:GridLoaded = $false
		$LvEvents.BeginUpdate()
		foreach ($Ev in $Events)
		{
			$Li = New-Object System.Windows.Forms.ListViewItem($Ev.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))
			$Li.SubItems.Add($Ev.EventType)                                           | Out-Null
			$Li.SubItems.Add($(if ($Ev.ProcessName) { $Ev.ProcessName } else { '' })) | Out-Null
			$Li.SubItems.Add($(if ($Ev.Path)        { $Ev.Path }        else { '' })) | Out-Null
			$Li.SubItems.Add($(if ($Ev.RuleInfo)    { $Ev.RuleInfo }    else { '' })) | Out-Null
			$Li.Tag = $Ev
			if ($Ev.EventType -eq 'Controlled Folder Access') { $Li.ForeColor = [System.Drawing.Color]::DarkBlue }
			elseif ($Ev.EventType -eq 'Smart App Control (allowed)') { $Li.ForeColor = [System.Drawing.Color]::DarkGreen }
			elseif ($Ev.EventType -like 'Smart App Control*') { $Li.ForeColor = [System.Drawing.Color]::DarkRed }
			$LvEvents.Items.Add($Li) | Out-Null
		}
		Add-EmptyPlaceholder $LvEvents
		$LvEvents.EndUpdate()
		if ($Events.Count -eq 0)
		{
			$Hint = if ($FilterVal -eq 'SAC-Allow')
				{ ' - SAC allows are captured only while "Log SAC Allows" is ON: enable it, launch the app, then Refresh (enabling clears any previous capture)' }
			elseif ($FilterVal -eq 'SAC' -and $SinceKey -eq 'Since Boot')
				{ ' - no SAC blocks since the last boot; widen Since (they may predate this boot)' }
			else { '' }
			$StatusLabel.Text = "Events loaded (0 events)$Hint."
		}
		else { $StatusLabel.Text = "Events loaded ($($Events.Count) events)." }
	}
	catch
	{
		# Surface the error AND persist it to the per-day log so it is not lost.
		try { Write-OperationError -Operation ('Get-CDEvents -Filter {0}' -f $FilterVal) -ErrorInfo $_ } catch { $null = $_ }
		$StatusLabel.Text = 'Error loading Events: ' + $_.Exception.Message
	}
	finally { $script:EvRefreshing = $false; $Form.UseWaitCursor = $false; [System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::Default }
})

$TsBtnEvAdd.Add_Click({
	if ($LvEvents.SelectedItems.Count -ne 1) { $StatusLabel.Text = 'Select exactly one event row.'; return }
	$Li       = $LvEvents.SelectedItems[0]
	$EvType   = $Li.SubItems[1].Text  # 'Attack Surface Reduction' or 'Controlled Folder Access'
	$ProcName = $Li.SubItems[2].Text
	$Path     = $Li.SubItems[3].Text

	if ($EvType -eq 'Attack Surface Reduction')
	{
		# Pre-fill the ASR Exclusion dialog with the blocked path
		$PathToAdd = Show-ExclPathDialog 'Add ASR Exclusion from Event' $Path
		if ($PathToAdd)
		{
			try
			{
				$SRP     = Get-CDSRP
				$Escaped = $PathToAdd -replace "'", "''"
				$SRP.DataObject = "Set-CDASRExclusion -Path '$Escaped' -Add" | Send-Request @SRP -NoExitOnError
				if ($SRP.DataObject.Error)
				{ $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" }
				else
				{ $StatusLabel.Text = "Added ASR exclusion: $PathToAdd" }
			}
			catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
		}
	}
	elseif ($EvType -eq 'Controlled Folder Access')
	{
		if (-not $ProcName) { $StatusLabel.Text = 'No process name in this event.'; return }
		$Confirm = [System.Windows.Forms.MessageBox]::Show(
			"Add to Allowed Applications:`n`n$ProcName",
			'Add Allowed Application',
			[System.Windows.Forms.MessageBoxButtons]::OKCancel,
			[System.Windows.Forms.MessageBoxIcon]::Question
		)
		if ($Confirm -eq 'OK')
		{
			try
			{
				$SRP     = Get-CDSRP
				$Escaped = $ProcName -replace "'", "''"
				$SRP.DataObject = "Set-CDAllowedApplication -Path '$Escaped' -Add" | Send-Request @SRP -NoExitOnError
				if ($SRP.DataObject.Error)
				{ $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" }
				else
				{ $StatusLabel.Text = "Added allowed application: $ProcName" }
			}
			catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
		}
	}
	else
	{ $StatusLabel.Text = 'Unknown event type - cannot add.' }
})

# Full block-details dialog for a Smart App Control event. Uses a read-only,
# selectable text box so the whole record can be dragged/Ctrl+C'd or copied wholesale.
function Show-SacDetailsDialog ($EvObj)
{
	$Lines = New-Object System.Collections.Generic.List[string]
	if ($EvObj.Details)
	{
		$MaxLen = 0
		foreach ($k in $EvObj.Details.Keys) { if (([string]$k).Length -gt $MaxLen) { $MaxLen = ([string]$k).Length } }
		foreach ($kv in $EvObj.Details.GetEnumerator())
		{ $Lines.Add(('{0} : {1}' -f ([string]$kv.Key).PadRight($MaxLen), [string]$kv.Value)) }
	}
	$AllText = $Lines -join [System.Environment]::NewLine

	$Dlg                 = New-Object System.Windows.Forms.Form
	$Dlg.Text            = 'Smart App Control - Block Details'
	$Dlg.Size            = New-Object System.Drawing.Size(680, 460)
	$Dlg.StartPosition   = 'CenterParent'
	$Dlg.MinimumSize     = New-Object System.Drawing.Size(480, 300)
	$Dlg.FormBorderStyle = 'Sizable'

	$Tb           = New-Object System.Windows.Forms.TextBox
	$Tb.Multiline = $true
	$Tb.ReadOnly  = $true
	$Tb.ScrollBars = 'Both'
	$Tb.WordWrap  = $false
	$Tb.Dock      = 'Fill'
	$Tb.Font      = New-Object System.Drawing.Font('Consolas', 9)
	$Tb.BackColor = [System.Drawing.SystemColors]::Window
	$Tb.Text      = $AllText

	$Bar        = New-Object System.Windows.Forms.Panel
	$Bar.Dock   = 'Bottom'
	$Bar.Height = 40

	$Sha = [string]$EvObj.Sha256

	$BtnCopyAll          = New-Object System.Windows.Forms.Button
	$BtnCopyAll.Text     = 'Copy All'
	$BtnCopyAll.Width    = 90
	$BtnCopyAll.Location = New-Object System.Drawing.Point(10, 7)
	$BtnCopyAll.Add_Click({ if ($AllText) { [System.Windows.Forms.Clipboard]::SetText($AllText) } }.GetNewClosure())

	$BtnCopySha          = New-Object System.Windows.Forms.Button
	$BtnCopySha.Text     = 'Copy SHA256'
	$BtnCopySha.Width    = 110
	$BtnCopySha.Location = New-Object System.Drawing.Point(108, 7)
	$BtnCopySha.Enabled  = [bool]$Sha
	$BtnCopySha.Add_Click({ if ($Sha) { [System.Windows.Forms.Clipboard]::SetText($Sha) } }.GetNewClosure())

	$BtnClose          = New-Object System.Windows.Forms.Button
	$BtnClose.Text     = 'Close'
	$BtnClose.Width    = 80
	$BtnClose.Location = New-Object System.Drawing.Point(226, 7)
	$BtnClose.Add_Click({ $Dlg.Close() }.GetNewClosure())
	$Dlg.CancelButton  = $BtnClose

	$Bar.Controls.Add($BtnCopyAll)
	$Bar.Controls.Add($BtnCopySha)
	$Bar.Controls.Add($BtnClose)
	$Dlg.Controls.Add($Tb)
	$Dlg.Controls.Add($Bar)
	$Dlg.ShowDialog($Form) | Out-Null
	$Dlg.Dispose()
}

$EvShowDetails = {
	if ($LvEvents.SelectedItems.Count -ne 1) { $StatusLabel.Text = 'Select one event row.'; return }
	$Ev = $LvEvents.SelectedItems[0].Tag
	if (-not $Ev -or ($Ev -is [string])) { return }   # placeholder / no data
	if ($Ev.EventType -like 'Smart App Control*') { Show-SacDetailsDialog $Ev }
	else { $StatusLabel.Text = 'Detailed view is available for Smart App Control events only.' }
}
$TsBtnEvDetails.Add_Click($EvShowDetails)
$LvEvents.Add_DoubleClick($EvShowDetails)

# --- Save / Open SAC allow captures. The Verbose channel is cleared each time logging is
# re-enabled, so let the user save a capture to CSV and reload it later for viewing. ---------

# Populate the events grid from an arbitrary array of event objects (used by Open).
function Add-EvRowsToGrid ($Events)
{
	$LvEvents.BeginUpdate()
	$LvEvents.Items.Clear()
	foreach ($Ev in $Events)
	{
		$Li = New-Object System.Windows.Forms.ListViewItem($Ev.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))
		$Li.SubItems.Add([string]$Ev.EventType)   | Out-Null
		$Li.SubItems.Add([string]$Ev.ProcessName) | Out-Null
		$Li.SubItems.Add([string]$Ev.Path)        | Out-Null
		$Li.SubItems.Add([string]$Ev.RuleInfo)    | Out-Null
		$Li.Tag = $Ev
		if ($Ev.EventType -eq 'Smart App Control (allowed)') { $Li.ForeColor = [System.Drawing.Color]::DarkGreen }
		elseif ($Ev.EventType -eq 'Smart App Control') { $Li.ForeColor = [System.Drawing.Color]::DarkRed }
		elseif ($Ev.EventType -eq 'Controlled Folder Access') { $Li.ForeColor = [System.Drawing.Color]::DarkBlue }
		$LvEvents.Items.Add($Li) | Out-Null
	}
	Add-EmptyPlaceholder $LvEvents
	$LvEvents.EndUpdate()
}

# Flatten allow rows (top-level + Details) to CSV via a Save dialog. Returns $true if written.
function Save-SacAllowCapture ($Rows)
{
	if (-not $Rows -or $Rows.Count -eq 0) { $StatusLabel.Text = 'Nothing to save (no SAC allows or blocks this session).'; return $false }
	$Sfd = New-Object System.Windows.Forms.SaveFileDialog
	$Sfd.Title    = 'Save SAC capture (allows + blocks in the same window)'
	$Sfd.Filter   = 'CSV files (*.csv)|*.csv|All files (*.*)|*.*'
	$Sfd.FileName = 'SAC-Capture-{0}.csv' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
	if ($Sfd.ShowDialog($Form) -ne 'OK') { return $false }
	$Keys = New-Object System.Collections.Generic.List[string]
	foreach ($k in 'Time', 'Type', 'Process', 'Path', 'Rule') { $Keys.Add($k) }
	foreach ($r in $Rows) { if ($r.Details) { foreach ($k in $r.Details.Keys) { if (-not $Keys.Contains([string]$k)) { $Keys.Add([string]$k) } } } }
	$Flat = foreach ($r in $Rows)
	{
		$o = [ordered]@{ Time = $r.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'); Type = [string]$r.EventType; Process = [string]$r.ProcessName; Path = [string]$r.Path; Rule = [string]$r.RuleInfo }
		foreach ($k in $Keys) { if ($k -notin 'Time', 'Type', 'Process', 'Path', 'Rule') { $o[$k] = if ($r.Details -and $r.Details.Contains($k)) { [string]$r.Details[$k] } else { '' } } }
		[PSCustomObject]$o
	}
	try
	{
		$Flat | Export-Csv -Path $Sfd.FileName -NoTypeInformation -Encoding UTF8
		$StatusLabel.Text = 'Saved {0} event(s) to {1}' -f $Rows.Count, $Sfd.FileName
		return $true
	}
	catch { $StatusLabel.Text = 'Save failed: ' + $_.Exception.Message; return $false }
}

# Captured allows PLUS the SAC blocks that fall in the same timeframe (earliest..latest allow),
# merged and sorted chronologically so a saved file shows the full allow/block sequence.
function Get-SacCapture
{
	# THROW on a failed read rather than degrading to an empty list. This output is written to a
	# SAVED EVIDENCE FILE, so a swallowed read failure produced a file that looked complete while
	# silently missing events - the worst possible outcome for evidence. Callers are ready for it:
	# the Save button wraps Get-SacCapture in a try/catch that reports to the status line.
	$Allows = @()
	try { $Allows = @(Get-CDEvents -Filter SAC-Allow) }
	catch { throw ('Get-SacCapture: could not read SAC-Allow events - refusing to save a partial capture. {0}' -f $_.Exception.Message) }
	# Include ALL SAC blocks from the current session (Get-CDEvents default = since last boot), so
	# BOOT-TIME blocks - e.g. a service blocked as it started at boot, before logging was even on -
	# appear alongside the allows captured after logging started. That is the "blocked at boot, allowed
	# after a restart" story. Blocks are logged to the Operational log regardless of the Verbose channel,
	# are sparse, and are merged + time-sorted with all the allows captured since logging was enabled.
	$Blocks = @()
	try { $Blocks = @(Get-CDEvents -Filter SAC) }
	catch { throw ('Get-SacCapture: could not read SAC block events - refusing to save a partial capture. {0}' -f $_.Exception.Message) }
	if ($Allows.Count -eq 0 -and $Blocks.Count -eq 0) { return @() }
	return @($Allows + $Blocks) | Sort-Object TimeCreated
}

$script:GridRows   = $null    # full set of rows currently loaded in the grid (live or opened)
$script:GridLoaded = $false   # $true when the grid holds an opened CSV (vs a live query)
$script:EvFindBusy = $false

# Rows from the current grid set (GridRows) matching the Find text in ANY column / detail (empty = all).
function Get-EvFilteredRow
{
	$Src = @($script:GridRows)
	if ($Src.Count -eq 0) { return @() }
	$Find = $TsTxtFind.Text.Trim()
	if (-not $Find) { return $Src }
	return @($Src | Where-Object {
			$Hay = '{0} {1} {2} {3}' -f $_.ProcessName, $_.Path, $_.RuleInfo, (@($_.Details.Values) -join ' ')
			$Hay -ilike "*$Find*"
		})
}

# Re-show the grid from GridRows honouring the current Find text.
function Show-EvGridFilter
{
	if ($null -eq $script:GridRows) { return }
	$Rows = @(Get-EvFilteredRow)
	Add-EvRowsToGrid $Rows
	$Find = $TsTxtFind.Text.Trim()
	$StatusLabel.Text = if ($Find) { 'Showing {0} row(s) matching "{1}".' -f $Rows.Count, $Find } else { 'Showing {0} row(s).' -f $Rows.Count }
}

$TsTxtFind.Add_TextChanged({ if (-not $script:EvFindBusy) { Show-EvGridFilter } })

$TsBtnSaveAllows.Add_Click({
	if ($script:GridLoaded)
	{
		# Save a filtered subset of an opened capture (e.g. one program's entries) as evidence.
		[void](Save-SacAllowCapture (Get-EvFilteredRow))
	}
	else
	{
		$StatusLabel.Text = 'Reading captured allows and blocks...'
		[System.Windows.Forms.Application]::DoEvents()
		$rows = @()
		try { $rows = @(Get-SacCapture) } catch { $StatusLabel.Text = 'Error reading events: ' + $_.Exception.Message; return }
		[void](Save-SacAllowCapture $rows)
	}
})

$TsBtnOpenAllows.Add_Click({
	$Ofd = New-Object System.Windows.Forms.OpenFileDialog
	$Ofd.Title  = 'Open a saved SAC allows CSV'
	$Ofd.Filter = 'CSV files (*.csv)|*.csv|All files (*.*)|*.*'
	if ($Ofd.ShowDialog($Form) -ne 'OK') { return }
	try
	{
		$csv  = @(Import-Csv -Path $Ofd.FileName)
		$rows = foreach ($r in $csv)
		{
			$det = [ordered]@{}
			foreach ($p in $r.PSObject.Properties) { if ($p.Name -notin 'Time', 'Type', 'Process', 'Path', 'Rule' -and $p.Value) { $det[$p.Name] = $p.Value } }
			$tc = [datetime]::Now
			[void][datetime]::TryParse($r.Time, [ref]$tc)
			[PSCustomObject]@{ TimeCreated = $tc; EventType = $r.Type; ProcessName = $r.Process; Path = $r.Path; RuleInfo = $r.Rule; Sha256 = $null; Details = $det }
		}
		$script:GridRows   = @($rows)
		$script:GridLoaded = $true
		$script:EvFindBusy = $true; $TsTxtFind.Text = ''; $script:EvFindBusy = $false
		Add-EvRowsToGrid $rows
		$StatusLabel.Text = 'Loaded {0} row(s) from {1}. Type in Find to isolate a program (matches any column), then Save keeps just those. Refresh reverts to live.' -f $rows.Count, (Split-Path $Ofd.FileName -Leaf)
	}
	catch { $StatusLabel.Text = 'Open failed: ' + $_.Exception.Message }
})

# --- "Log SAC Allows" toggle: enable/disable the CodeIntegrity Verbose channel via the pipe. Auto-off
# after the "Auto-off min" value (0 = manual, stop by clicking Log). Set-CDCIVerbose also registers a
# watchdog task (fires next reboot always, plus the timed one) so the channel is never left on across a
# reboot even if the GUI is killed; on a normal close we disable it too when the pipe is still open.
$script:LogAllowsBusy        = $false
$script:LogAllowsCloseHooked = $false
$script:LogAllowsManual      = $false   # $true when started with Auto-off = 0 (leave running on GUI close)
$script:LogAllowsTimer       = New-Object System.Windows.Forms.Timer

$script:LogAllowsTimer.Add_Tick({
	$script:LogAllowsTimer.Stop()
	# Only claim the channel was turned OFF if it actually was. Previously any failure was
	# swallowed and execution carried straight on to untick the toggle and report "SAC allow
	# logging auto-off" - telling the user CodeIntegrity Verbose logging had stopped when it may
	# still be running. That channel is high-volume, which is the whole reason this auto-off
	# timer and the next-reboot watchdog exist, so a false "it is off" is exactly wrong.
	# NOTE Send-Request reports server-side failure in $DataObject.Error - it does NOT throw - so
	# the catch alone was never sufficient; the returned Error has to be inspected as well.
	$Private:OffOK  = $false
	$Private:OffWhy = ''
	try
	{
		$SRP = Get-CDSRP
		$SRP.DataObject = 'Set-CDCIVerbose -Disable' | Send-Request @SRP -NoExitOnError
		if ([string]::IsNullOrWhiteSpace([string]$SRP.DataObject.Error)) { $Private:OffOK = $true }
		else { $Private:OffWhy = [string]$SRP.DataObject.Error }
	}
	catch { $Private:OffWhy = $_.Exception.Message }
	$script:LogAllowsBusy = $true
	# Leave the toggle showing ON when the disable failed - it then reflects the REAL state.
	$TsBtnLogAllows.Checked = -not $Private:OffOK
	$script:LogAllowsBusy = $false
	if ($Private:OffOK)
	{ $StatusLabel.Text = 'SAC allow logging auto-off. Pick the SAC-Allow filter and Refresh to view captured allows.' }
	else
	{ $StatusLabel.Text = 'WARNING: auto-off FAILED - SAC allow logging may STILL BE ON. Turn it off manually. ' + $Private:OffWhy }
})

$TsBtnLogAllows.Add_CheckedChanged({
	if ($script:LogAllowsBusy) { return }
	if ($TsBtnLogAllows.Checked)
	{
		# Enabling the Verbose channel CLEARS any prior capture - offer to save it first.
		# Distinguish "there is nothing to save" from "we could not tell". Previously a FAILED read
		# left the count at 0, so the save prompt was SKIPPED and enabling logging then CLEARED
		# events the user was never offered the chance to keep - silent loss of captured evidence.
		$LAExisting  = @()
		$LAReadFailed = $false
		try { $LAExisting = @(Get-CDEvents -Filter SAC-Allow) }
		catch { $LAReadFailed = $true }

		if ($LAReadFailed)
		{
			$LARisk = [System.Windows.Forms.MessageBox]::Show(
				("Could not read the existing SAC allow capture, so it is not known whether there is anything to save." +
				 "`n`nStarting logging CLEARS any previous capture. Continue anyway?"),
				'Cannot check existing capture', 'YesNo', 'Warning')
			if ($LARisk -ne 'Yes')
			{ $script:LogAllowsBusy = $true; $TsBtnLogAllows.Checked = $false; $script:LogAllowsBusy = $false; $StatusLabel.Text = 'Logging not started.'; return }
		}

		if ($LAExisting.Count -gt 0)
		{
			$LAAns = [System.Windows.Forms.MessageBox]::Show(
				("There are {0} captured SAC allow event(s) that will be CLEARED when logging restarts.`n`nSave them to a file first?" -f $LAExisting.Count),
				'Save existing capture?', 'YesNoCancel', 'Question')
			if ($LAAns -eq 'Cancel')
			{ $script:LogAllowsBusy = $true; $TsBtnLogAllows.Checked = $false; $script:LogAllowsBusy = $false; $StatusLabel.Text = 'Logging not started.'; return }
			# Get-SacCapture now THROWS on a failed read rather than returning a partial capture,
			# so this call needs a handler: without one the exception would escape into the
			# CheckedChanged event and the user would lose the capture they asked to save.
			if ($LAAns -eq 'Yes')
			{
				$LASaved = $false
				try { $LASaved = [bool](Save-SacAllowCapture (Get-SacCapture)) }
				catch
				{
					$script:LogAllowsBusy = $true; $TsBtnLogAllows.Checked = $false; $script:LogAllowsBusy = $false
					$StatusLabel.Text = 'Logging not started - could not save the existing capture: ' + $_.Exception.Message
					return
				}
				if (-not $LASaved)
				{ $script:LogAllowsBusy = $true; $TsBtnLogAllows.Checked = $false; $script:LogAllowsBusy = $false; $StatusLabel.Text = 'Logging not started (save cancelled).'; return }
			}
		}
		$LAMins = 0
		[void][int]::TryParse($TsTxtAutoOff.Text, [ref]$LAMins)
		if ($LAMins -lt 0) { $LAMins = 0 }
		if ($LAMins -gt 1440) { $LAMins = 1440 }
		$script:LogAllowsManual = ($LAMins -le 0)
		try
		{
			$SRP = Get-CDSRP
			$SRP.DataObject = "Set-CDCIVerbose -WatchdogMinutes $LAMins" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error) { throw $SRP.DataObject.Error }
			if ($LAMins -gt 0)
			{
				$script:LogAllowsTimer.Interval = $LAMins * 60000
				$script:LogAllowsTimer.Start()
				$StatusLabel.Text = "SAC allow logging ON (auto-off in $LAMins min). Launch the app now."
			}
			else
			{ $StatusLabel.Text = 'SAC allow logging ON (manual - stays on after you close the GUI; stop by clicking Log, or it auto-offs at next reboot). Launch the app now.' }
			if (-not $script:LogAllowsCloseHooked)
			{
				$Form.Add_FormClosing({
					# Disable on close ONLY for a timed session. Manual (Auto-off = 0) stays running so
					# you can leave a capture going all day and reopen later - the next-reboot watchdog
					# and the startup check clean it up.
					if ($TsBtnLogAllows.Checked -and -not $script:LogAllowsManual)
					{
						$s = Get-CDSendRequestParams
						if ($s) { try { $s.DataObject = 'Set-CDCIVerbose -Disable' | Send-Request @s -NoExitOnError } catch { $null = $_ } }
					}
				})
				$script:LogAllowsCloseHooked = $true
			}
		}
		catch
		{
			$StatusLabel.Text = 'Log Allows error: ' + $_.Exception.Message
			$script:LogAllowsBusy = $true; $TsBtnLogAllows.Checked = $false; $script:LogAllowsBusy = $false
		}
	}
	else
	{
		$script:LogAllowsTimer.Stop()
		try
		{
			$SRP = Get-CDSRP
			$SRP.DataObject = 'Set-CDCIVerbose -Disable' | Send-Request @SRP -NoExitOnError
			$StatusLabel.Text = 'SAC allow logging OFF.'
		}
		catch { $StatusLabel.Text = 'Log Allows off error: ' + $_.Exception.Message }
	}
})

# On GUI startup (any tab), if SAC allow logging was left on by a previous/killed session, reflect it on
# the Log toggle and offer to turn it off. Runs once via the form's Shown event (reading state needs no
# elevation; disabling opens the pipe only if the user says Yes).
$Form.Add_Shown({
	if ($script:LogAllowsStartupChecked) { return }
	$script:LogAllowsStartupChecked = $true
	try
	{
		$LcVl = Get-WinEvent -ListLog 'Microsoft-Windows-CodeIntegrity/Verbose' -ErrorAction SilentlyContinue
		if ($LcVl -and $LcVl.IsEnabled)
		{
			$script:LogAllowsBusy = $true; $TsBtnLogAllows.Checked = $true; $script:LogAllowsBusy = $false
			$LcAns = [System.Windows.Forms.MessageBox]::Show($Form,
				'SAC allow logging is currently ON (possibly left on from a previous session). Turn it off now?',
				'SAC allow logging is on', 'YesNo', 'Warning')
			if ($LcAns -eq 'Yes')
			{
				try
				{
					$LcSrp = Get-CDSRP
					$LcSrp.DataObject = 'Set-CDCIVerbose -Disable' | Send-Request @LcSrp -NoExitOnError
					$script:LogAllowsBusy = $true; $TsBtnLogAllows.Checked = $false; $script:LogAllowsBusy = $false
					$StatusLabel.Text = 'SAC allow logging turned OFF.'
				}
				catch { $StatusLabel.Text = 'Could not turn off SAC allow logging: ' + $_.Exception.Message }
			}
		}
	}
	catch { $null = $_ }
})
#endregion

