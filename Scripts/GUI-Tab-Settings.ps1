#region Tab 9 - Settings

$TabSettings = New-Tab 'Settings'

$ToolStripSettings      = New-Object System.Windows.Forms.ToolStrip
$ToolStripSettings.Dock = 'Top'

$TsBtnSettingsRefresh              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnSettingsRefresh.Text         = 'Refresh'
$TsBtnSettingsRefresh.DisplayStyle = 'Text'
$TsBtnSettingsRefresh.ToolTipText  = 'Refresh all settings from Windows Defender'
$ToolStripSettings.Items.Add($TsBtnSettingsRefresh) | Out-Null

$LvSettings               = New-Object System.Windows.Forms.ListView
$LvSettings.Dock          = 'Fill'
$LvSettings.View          = 'Details'
$LvSettings.FullRowSelect = $true
$LvSettings.GridLines     = $true
$LvSettings.MultiSelect   = $false
$LvSettings.Columns.Add('Setting',  220) | Out-Null
$LvSettings.Columns.Add('Value',    100) | Out-Null
$LvSettings.Columns.Add('Description', 500) | Out-Null
$LvSettings.Add_SizeChanged({
	$w = $LvSettings.ClientSize.Width - 220 - 100 - 22
	if ($w -gt 100) { $LvSettings.Columns[2].Width = $w }
})

$TabSettings.Controls.Add($LvSettings)
$TabSettings.Controls.Add($ToolStripSettings)

function Update-SettingsView
{
	$LvSettings.Items.Clear()
	if (-not $script:SettingsCache) { return }
	foreach ($S in $script:SettingsCache)
	{
		try
		{
			$DisplayVal = if ($S.Type -eq 'Bool') {
				if ($S.Value) { 'True' } else { 'False' }
			} elseif ($S.Type -eq 'Enum' -and $S.Options) {
				$IntVal = try { [int]$S.Value } catch { 0 }
				$OptEntry = $S.Options.GetEnumerator() | Where-Object { [int]$_.Key -eq $IntVal } | Select-Object -First 1
				if ($OptEntry) { "$($OptEntry.Value) ($IntVal)" } else { "$($S.Value)" }
			} else {
				"$($S.Value)"
			}
			$Li = New-Object System.Windows.Forms.ListViewItem($S.FriendlyName)
			$Li.SubItems.Add($DisplayVal)    | Out-Null
			$Li.SubItems.Add($S.Description) | Out-Null
			$Li.Tag = $S
			$LvSettings.Items.Add($Li) | Out-Null
		}
		catch
		{
			$Li = New-Object System.Windows.Forms.ListViewItem($S.FriendlyName)
			$Li.SubItems.Add("(error: $($_.Exception.Message))") | Out-Null
			$Li.SubItems.Add($S.Description) | Out-Null
			$LvSettings.Items.Add($Li) | Out-Null
		}
	}
	$StatusLabel.Text = "Settings loaded ($($script:SettingsCache.Count) entries)."
}

$TsBtnSettingsRefresh.Add_Click({
	$StatusLabel.Text = 'Loading...'
	$Form.UseWaitCursor = $true
	[System.Windows.Forms.Application]::DoEvents()
	try
	{
		$script:SettingsCache = @(Get-CDSettings)
		Update-SettingsView
	}
	catch { Write-OperationError -Operation 'Get-CDSettings' -ErrorInfo $_ }
	finally
	{
		$Form.UseWaitCursor = $false
		[System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::Default
	}
})

# Edit dialog - adapts controls to Bool/Enum/Int type
function Show-SettingEditDialog ([PSCustomObject]$Setting)
{
	$Dlg                 = New-Object System.Windows.Forms.Form
	$Dlg.Text            = "Edit: $($Setting.FriendlyName)"
	$Dlg.Size            = New-Object System.Drawing.Size(420, 210)
	$Dlg.StartPosition   = 'CenterParent'
	$Dlg.FormBorderStyle = 'FixedDialog'
	$Dlg.MaximizeBox     = $false
	$Dlg.MinimizeBox     = $false

	$LblDesc          = New-Object System.Windows.Forms.Label
	$LblDesc.Text     = $Setting.Description
	$LblDesc.Location = New-Object System.Drawing.Point(10, 10)
	$LblDesc.Size     = New-Object System.Drawing.Size(390, 36)
	$LblDesc.ForeColor = [System.Drawing.Color]::DimGray
	$Dlg.Controls.Add($LblDesc)

	$ResultValue = $null

	if ($Setting.Type -eq 'Bool')
	{
		$RbTrue          = New-Object System.Windows.Forms.RadioButton
		$RbTrue.Text     = 'True'
		$RbTrue.Location = New-Object System.Drawing.Point(10, 55)
		$RbTrue.AutoSize = $true
		$RbTrue.Checked  = [bool]$Setting.Value

		$RbFalse          = New-Object System.Windows.Forms.RadioButton
		$RbFalse.Text     = 'False'
		$RbFalse.Location = New-Object System.Drawing.Point(10, 80)
		$RbFalse.AutoSize = $true
		$RbFalse.Checked  = -not [bool]$Setting.Value

		$Dlg.Controls.AddRange(@($RbTrue, $RbFalse))

		$BtnOK              = New-Object System.Windows.Forms.Button
		$BtnOK.Text         = 'OK'
		$BtnOK.DialogResult = 'OK'
		$BtnOK.Location     = New-Object System.Drawing.Point(240, 135)
		$BtnOK.Size         = New-Object System.Drawing.Size(70, 25)
		$Dlg.Controls.Add($BtnOK)
		$Dlg.AcceptButton   = $BtnOK

		$BtnCnl              = New-Object System.Windows.Forms.Button
		$BtnCnl.Text         = 'Cancel'
		$BtnCnl.DialogResult = 'Cancel'
		$BtnCnl.Location     = New-Object System.Drawing.Point(320, 135)
		$BtnCnl.Size         = New-Object System.Drawing.Size(70, 25)
		$Dlg.Controls.Add($BtnCnl)
		$Dlg.CancelButton    = $BtnCnl

		if ($Dlg.ShowDialog($Form) -eq 'OK')
		{ $ResultValue = $RbTrue.Checked }
	}
	elseif ($Setting.Type -eq 'Enum')
	{
		$Cmb          = New-Object System.Windows.Forms.ComboBox
		$Cmb.Location = New-Object System.Drawing.Point(10, 55)
		$Cmb.Size     = New-Object System.Drawing.Size(380, 22)
		$Cmb.DropDownStyle = 'DropDownList'

		# Populate using GetEnumerator to avoid positional int-indexer on OrderedDictionary
		$CurrentIdx = 0; $Idx = 0
		foreach ($Entry in $Setting.Options.GetEnumerator())
		{
			$Cmb.Items.Add("$($Entry.Value) ($($Entry.Key))") | Out-Null
			if ([int]$Entry.Key -eq [int]$Setting.Value) { $CurrentIdx = $Idx }
			$Idx++
		}
		$Cmb.SelectedIndex = $CurrentIdx
		$Dlg.Controls.Add($Cmb)

		$BtnOK              = New-Object System.Windows.Forms.Button
		$BtnOK.Text         = 'OK'
		$BtnOK.DialogResult = 'OK'
		$BtnOK.Location     = New-Object System.Drawing.Point(240, 135)
		$BtnOK.Size         = New-Object System.Drawing.Size(70, 25)
		$Dlg.Controls.Add($BtnOK)
		$Dlg.AcceptButton   = $BtnOK

		$BtnCnl              = New-Object System.Windows.Forms.Button
		$BtnCnl.Text         = 'Cancel'
		$BtnCnl.DialogResult = 'Cancel'
		$BtnCnl.Location     = New-Object System.Drawing.Point(320, 135)
		$BtnCnl.Size         = New-Object System.Drawing.Size(70, 25)
		$Dlg.Controls.Add($BtnCnl)
		$Dlg.CancelButton    = $BtnCnl

		if ($Dlg.ShowDialog($Form) -eq 'OK')
		{
			# Get the integer key for the selected item
			$SelIdx = $Cmb.SelectedIndex
			$Keys   = @($Setting.Options.Keys)
			$ResultValue = [int]$Keys[$SelIdx]
		}
	}
	elseif ($Setting.Type -eq 'Int')
	{
		$Nud          = New-Object System.Windows.Forms.NumericUpDown
		$Nud.Location = New-Object System.Drawing.Point(10, 55)
		$Nud.Size     = New-Object System.Drawing.Size(120, 22)
		$Nud.Minimum  = $Setting.Min
		$Nud.Maximum  = $Setting.Max
		$Nud.Value    = [Math]::Max($Setting.Min, [Math]::Min($Setting.Max, [int]$Setting.Value))
		$Dlg.Controls.Add($Nud)

		$BtnOK              = New-Object System.Windows.Forms.Button
		$BtnOK.Text         = 'OK'
		$BtnOK.DialogResult = 'OK'
		$BtnOK.Location     = New-Object System.Drawing.Point(240, 135)
		$BtnOK.Size         = New-Object System.Drawing.Size(70, 25)
		$Dlg.Controls.Add($BtnOK)
		$Dlg.AcceptButton   = $BtnOK

		$BtnCnl              = New-Object System.Windows.Forms.Button
		$BtnCnl.Text         = 'Cancel'
		$BtnCnl.DialogResult = 'Cancel'
		$BtnCnl.Location     = New-Object System.Drawing.Point(320, 135)
		$BtnCnl.Size         = New-Object System.Drawing.Size(70, 25)
		$Dlg.Controls.Add($BtnCnl)
		$Dlg.CancelButton    = $BtnCnl

		if ($Dlg.ShowDialog($Form) -eq 'OK')
		{ $ResultValue = [int]$Nud.Value }
	}

	$ResultValue
}

$LvSettings.Add_DoubleClick({
	$Li = $LvSettings.FocusedItem
	if (-not $Li) { return }
	$Setting = $Li.Tag
	$NewVal  = Show-SettingEditDialog $Setting
	if ($null -ne $NewVal)
	{
		try
		{
			$SRP    = Get-CDSRP
			$Name   = $Setting.Name
			$ValStr = if ($NewVal -is [bool]) { if ($NewVal) { '`$true' } else { '`$false' } } else { "$NewVal" }
			$SRP.DataObject = "Set-CDSetting -Name '$Name' -Value $ValStr" | Send-Request @SRP
			if ($SRP.DataObject.Error)
			{ $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" }
			else
			{
				$Setting.Value = $NewVal
				$StatusLabel.Text = "Set $($Setting.FriendlyName) = $ValStr"
				Update-SettingsView
			}
		}
		catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
	}
})
#endregion

