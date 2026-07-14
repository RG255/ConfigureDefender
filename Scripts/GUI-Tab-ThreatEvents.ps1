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

$ToolStripEvents.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
$ToolStripEvents.Items.Add((New-Object System.Windows.Forms.ToolStripLabel('  Filter:'))) | Out-Null

$TsCmbEvFilter               = New-Object System.Windows.Forms.ToolStripComboBox
$TsCmbEvFilter.DropDownStyle = 'DropDownList'
$TsCmbEvFilter.Width         = 70
$TsCmbEvFilter.Items.AddRange(@('All', 'ASR', 'CFA'))
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
		$LvEvents.BeginUpdate()
		foreach ($Ev in $Events)
		{
			$Li = New-Object System.Windows.Forms.ListViewItem($Ev.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))
			$Li.SubItems.Add($Ev.EventType)                                           | Out-Null
			$Li.SubItems.Add($(if ($Ev.ProcessName) { $Ev.ProcessName } else { '' })) | Out-Null
			$Li.SubItems.Add($(if ($Ev.Path)        { $Ev.Path }        else { '' })) | Out-Null
			$Li.SubItems.Add($(if ($Ev.RuleInfo)    { $Ev.RuleInfo }    else { '' })) | Out-Null
			if ($Ev.EventType -eq 'Controlled Folder Access') { $Li.ForeColor = [System.Drawing.Color]::DarkBlue }
			$LvEvents.Items.Add($Li) | Out-Null
		}
		Add-EmptyPlaceholder $LvEvents
		$LvEvents.EndUpdate()
		$StatusLabel.Text = "Events loaded ($($Events.Count) events)."
	}
	catch { $StatusLabel.Text = 'Error loading Events: ' + $_.Exception.Message }
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
#endregion

