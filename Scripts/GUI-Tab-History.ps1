#region History Tab (Tab 6 - index 6)
$TabHist = New-Tab 'History'

#region ToolStrip
$TsHist            = New-Object System.Windows.Forms.ToolStrip
$TsHist.GripStyle  = 'Hidden'

$TsBtnHistRefresh       = New-Object System.Windows.Forms.ToolStripButton
$TsBtnHistRefresh.Text  = 'Refresh'
$TsHist.Items.Add($TsBtnHistRefresh) | Out-Null

$TsHist.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$TsLblHistFilter       = New-Object System.Windows.Forms.ToolStripLabel
$TsLblHistFilter.Text  = 'Filter:'
$TsHist.Items.Add($TsLblHistFilter) | Out-Null

$TsCbHistFilter               = New-Object System.Windows.Forms.ToolStripComboBox
$TsCbHistFilter.DropDownStyle = 'DropDownList'
$TsCbHistFilter.Items.AddRange(@('All', 'Active', 'Remediated', 'Failed'))
$TsCbHistFilter.SelectedIndex = 0
$TsCbHistFilter.Width         = 100
$TsHist.Items.Add($TsCbHistFilter) | Out-Null

$TsHist.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$TsLblHistSince       = New-Object System.Windows.Forms.ToolStripLabel
$TsLblHistSince.Text  = 'Since:'
$TsHist.Items.Add($TsLblHistSince) | Out-Null

$TsCbHistSince               = New-Object System.Windows.Forms.ToolStripComboBox
$TsCbHistSince.DropDownStyle = 'DropDownList'
$TsCbHistSince.Items.AddRange(@('All Time', 'Last 7 Days', 'Last 30 Days', 'Last Year', 'Custom Date...'))
$TsCbHistSince.SelectedIndex = 0
$TsCbHistSince.Width         = 120
$TsHist.Items.Add($TsCbHistSince) | Out-Null

$TsHist.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$TsBtnHistRes       = New-Object System.Windows.Forms.ToolStripButton
$TsBtnHistRes.Text  = 'Resources [+]'
$TsHist.Items.Add($TsBtnHistRes) | Out-Null
#endregion

#region SplitContainer
$ScHist                    = New-Object System.Windows.Forms.SplitContainer
$ScHist.Dock               = 'Fill'
$ScHist.Orientation        = 'Horizontal'
$ScHist.SplitterDistance   = 320
$ScHist.Panel2Collapsed    = $true
# SplitContainer must be added first so the ToolStrip (added second/back) is
# processed first by the docking layout engine and correctly claims the top edge.
$TabHist.Controls.Add($ScHist)
$TabHist.Controls.Add($TsHist)
#endregion

#region Main ListView
$LvHist                = New-Object System.Windows.Forms.ListView
$LvHist.Dock           = 'Fill'
$LvHist.View           = 'Details'
$LvHist.FullRowSelect  = $true
$LvHist.GridLines      = $true
$LvHist.MultiSelect    = $false
$LvHist.Columns.Add('Detected',    140) | Out-Null
$LvHist.Columns.Add('Threat Name', 210) | Out-Null
$LvHist.Columns.Add('Severity',     70) | Out-Null
$LvHist.Columns.Add('Status',      120) | Out-Null
$LvHist.Columns.Add('Action',       90) | Out-Null
$LvHist.Columns.Add('Source',      110) | Out-Null
$LvHist.Columns.Add('User',        130) | Out-Null
$LvHist.Columns.Add('Process',     180) | Out-Null
$ScHist.Panel1.Controls.Add($LvHist)
#endregion

#region Resources ListView
$PnlHistRes            = New-Object System.Windows.Forms.Panel
$PnlHistRes.Dock       = 'Fill'
$ScHist.Panel2.Controls.Add($PnlHistRes)

$LblHistRes            = New-Object System.Windows.Forms.Label
$LblHistRes.Text       = 'Resources'
$LblHistRes.Dock       = 'Top'
$LblHistRes.Height     = 18
$LblHistRes.Font       = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Bold)
$PnlHistRes.Controls.Add($LblHistRes)

$LvHistRes             = New-Object System.Windows.Forms.ListView
$LvHistRes.Dock        = 'Fill'
$LvHistRes.View        = 'Details'
$LvHistRes.FullRowSelect = $true
$LvHistRes.GridLines   = $true
$LvHistRes.Columns.Add('Type',  55) | Out-Null
$LvHistRes.Columns.Add('Path', 700) | Out-Null
$PnlHistRes.Controls.Add($LvHistRes)
#endregion

#region Helpers
function Get-HistItemColor ([string]$Status, [bool]$ActionSuccess, [bool]$IsActive)
{
	if ($IsActive)                                                              { return [System.Drawing.Color]::DarkOrange }
	if ($Status -match 'Failed')                                                { return [System.Drawing.Color]::DarkRed }
	if ($Status -in 'Cleaned', 'Quarantined', 'Removed' -and $ActionSuccess)   { return [System.Drawing.Color]::DarkGreen }
	if ($Status -in 'Allowed', 'NoAction')                                      { return [System.Drawing.Color]::Gray }
	[System.Drawing.Color]::Black
}

function ConvertTo-HistResourceRow ([string]$Raw)
{
	if      ($Raw -match '^webfile:_(.+?)\|') { [PSCustomObject]@{ Type = 'Web';  Path = $Matches[1] } }
	elseif  ($Raw -match '^file:_(.+)')       { [PSCustomObject]@{ Type = 'File'; Path = $Matches[1] } }
	else                                      { [PSCustomObject]@{ Type = '';     Path = $Raw } }
}

function Get-HistSinceDate
{
	switch ($TsCbHistSince.SelectedItem)
	{
		'Last 7 Days'    { return (Get-Date).AddDays(-7) }
		'Last 30 Days'   { return (Get-Date).AddDays(-30) }
		'Last Year'      { return (Get-Date).AddYears(-1) }
		'Custom Date...'
		{
			$Dlg                 = New-Object System.Windows.Forms.Form
			$Dlg.Text            = 'Select Start Date'
			$Dlg.Size            = New-Object System.Drawing.Size(300, 130)
			$Dlg.StartPosition   = 'CenterParent'
			$Dlg.FormBorderStyle = 'FixedDialog'
			$Dlg.MaximizeBox     = $false
			$Dlg.MinimizeBox     = $false

			$Dtp          = New-Object System.Windows.Forms.DateTimePicker
			$Dtp.Format   = 'Short'
			$Dtp.Location = New-Object System.Drawing.Point(20, 20)
			$Dtp.Width    = 240

			$BtnOk              = New-Object System.Windows.Forms.Button
			$BtnOk.Text         = 'OK'
			$BtnOk.DialogResult = 'OK'
			$BtnOk.Location     = New-Object System.Drawing.Point(100, 55)

			$Dlg.Controls.AddRange(@($Dtp, $BtnOk))
			$Dlg.AcceptButton = $BtnOk

			if ($Dlg.ShowDialog($Form) -eq 'OK') { return $Dtp.Value.Date }
			return $null
		}
		default { return $null }
	}
}
#endregion

#region State
$script:HistLoaded = $false
#endregion

#region Refresh handler
$TsBtnHistRefresh.Add_Click({
	$StatusLabel.Text   = 'Loading...'
	$Form.UseWaitCursor = $true
	[System.Windows.Forms.Application]::DoEvents()
	try
	{
		$Since  = Get-HistSinceDate
		$Filter = $TsCbHistFilter.SelectedItem.ToString()
		$Params = @{ Filter = $Filter }
		if ($Since) { $Params.Since = $Since }

		$Rows = @(Get-CDThreatDetections @Params)

		$LvHist.BeginUpdate()
		$LvHist.Items.Clear()
		$LvHistRes.Items.Clear()

		foreach ($D in $Rows)
		{
			$DetStr  = if ($D.Detected) { $D.Detected.ToString('yyyy-MM-dd HH:mm') } else { '' }
			$ProcStr = if ($D.ProcessName) { Split-Path $D.ProcessName -Leaf } else { '' }

			$Li = New-Object System.Windows.Forms.ListViewItem($DetStr)
			$Li.SubItems.Add([string]$D.ThreatName) | Out-Null
			$Li.SubItems.Add([string]$D.Severity)   | Out-Null
			$Li.SubItems.Add([string]$D.Status)     | Out-Null
			$Li.SubItems.Add([string]$D.Action)     | Out-Null
			$Li.SubItems.Add([string]$D.Source)     | Out-Null
			$Li.SubItems.Add($(if ($D.User) { [string]$D.User } else { 'Unknown' })) | Out-Null
			$Li.SubItems.Add($ProcStr)              | Out-Null
			$Li.ForeColor = Get-HistItemColor -Status $D.Status -ActionSuccess $D.ActionSuccess -IsActive $D.IsActive
			$Li.Tag       = $D
			$LvHist.Items.Add($Li) | Out-Null
		}

		$LvHist.EndUpdate()
		Add-EmptyPlaceholder $LvHist 'No detections found'
		$script:HistLoaded = $true
		$StatusLabel.Text  = "History: $($Rows.Count) detection(s)"
	}
	catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
	finally
	{
		$Form.UseWaitCursor = $false
		[System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::Default
	}
})
#endregion

#region Resources toggle
$TsBtnHistRes.Add_Click({
	if ($ScHist.Panel2Collapsed)
	{
		$ScHist.Panel2Collapsed = $false
		$TsBtnHistRes.Text      = 'Resources [-]'
	}
	else
	{
		$ScHist.Panel2Collapsed = $true
		$TsBtnHistRes.Text      = 'Resources [+]'
	}
})
#endregion

#region Selection change - populate Resources panel
$LvHist.Add_SelectedIndexChanged({
	$LvHistRes.Items.Clear()
	if ($LvHist.SelectedItems.Count -eq 0) { return }
	$Li = $LvHist.SelectedItems[0]
	if (-not $Li.Tag -or $Li.Tag -eq '$placeholder') { return }
	$D = $Li.Tag
	foreach ($R in $D.Resources)
	{
		$Row  = ConvertTo-HistResourceRow $R
		$RLi  = New-Object System.Windows.Forms.ListViewItem($Row.Type)
		$RLi.SubItems.Add($Row.Path) | Out-Null
		$LvHistRes.Items.Add($RLi) | Out-Null
	}
})
#endregion

#region Filter/Since combo - auto-refresh when already loaded
$TsCbHistFilter.Add_SelectedIndexChanged({ if ($script:HistLoaded) { $TsBtnHistRefresh.PerformClick() } })
$TsCbHistSince.Add_SelectedIndexChanged({ if ($script:HistLoaded) { $TsBtnHistRefresh.PerformClick() } })
#endregion

#endregion
