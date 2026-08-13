#region Tab 1 - ASR Rules

$TabASR = New-Tab 'ASR Rules'

# Shared action handler - used by both toolbar dropdown and right-click context menu
$ASRActionHandler = {
	$Action   = $this.Tag
	$Selected = @($LvASR.SelectedItems)
	if ($Selected.Count -eq 0) { $StatusLabel.Text = 'No rules selected.'; return }
	try
	{
		$SRP      = Get-CDSRP
		$Ok       = 0
		$ErrCount = 0
		foreach ($Li in $Selected)
		{
			$GUID = $Li.Tag
			$SRP.DataObject = "Set-CDASRRule -GUID '$GUID' -Action $Action" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error)
			{
				$ErrCount++
				$StatusLabel.Text = "Error on $GUID : $($SRP.DataObject.Error)"
			}
			else
			{
				$Li.Text      = $Action
				$Li.ForeColor = Get-ASRItemColor $Action
				$Ok++
			}
		}
		if ($ErrCount -eq 0)
		{ $StatusLabel.Text = "$Ok rule(s) set to $Action." }
		else
		{ $StatusLabel.Text = "$Ok set to $Action, $ErrCount error(s)." }
	}
	catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
}

# ToolStrip toolbar
$ToolStripASR      = New-Object System.Windows.Forms.ToolStrip
$ToolStripASR.Dock = 'Top'

$TsBtnRefresh              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnRefresh.Text         = 'Refresh'
$TsBtnRefresh.DisplayStyle = 'Text'
$TsBtnRefresh.ToolTipText  = 'Refresh ASR rules from Windows Defender'
$ToolStripASR.Items.Add($TsBtnRefresh) | Out-Null

$TsBtnSelectAll              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnSelectAll.Text         = 'Select All'
$TsBtnSelectAll.DisplayStyle = 'Text'
$TsBtnSelectAll.ToolTipText  = 'Select all rules in the list'
$TsBtnSelectAll.Add_Click({ $LvASR.Items | ForEach-Object { $_.Selected = $true } })
$ToolStripASR.Items.Add($TsBtnSelectAll) | Out-Null

$ToolStripASR.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

# Set Action dropdown button
$TsBtnSetAction                   = New-Object System.Windows.Forms.ToolStripDropDownButton
$TsBtnSetAction.Text              = 'Set Action'
$TsBtnSetAction.DisplayStyle      = 'Text'
$TsBtnSetAction.ShowDropDownArrow = $true
foreach ($ActionName in @('Disabled', 'Audit', 'Blocked', 'Warn'))
{
	$Item     = New-Object System.Windows.Forms.ToolStripMenuItem($ActionName)
	$Item.Tag = $ActionName
	$Item.Add_Click($ASRActionHandler)
	$TsBtnSetAction.DropDownItems.Add($Item) | Out-Null
}
$ToolStripASR.Items.Add($TsBtnSetAction) | Out-Null

# ListView
$LvASR               = New-Object System.Windows.Forms.ListView
$LvASR.Dock          = 'Fill'
$LvASR.View          = 'Details'
$LvASR.FullRowSelect = $true
$LvASR.GridLines     = $true
$LvASR.MultiSelect   = $true
$LvASR.Columns.Add('Action',       80) | Out-Null
$LvASR.Columns.Add('GUID',        280) | Out-Null
$LvASR.Columns.Add('Description', 470) | Out-Null

# Right-click context menu (same actions as toolbar dropdown)
$CtxASR = New-Object System.Windows.Forms.ContextMenuStrip
foreach ($ActionName in @('Disabled', 'Audit', 'Blocked', 'Warn'))
{
	$MenuItem     = New-Object System.Windows.Forms.ToolStripMenuItem($ActionName)
	$MenuItem.Tag = $ActionName
	$MenuItem.Add_Click($ASRActionHandler)
	$CtxASR.Items.Add($MenuItem) | Out-Null
}
$LvASR.ContextMenuStrip = $CtxASR

$LvASR.Add_SizeChanged({
	$w = $LvASR.ClientSize.Width - 80 - 280 - 22
	if ($w -gt 100) { $LvASR.Columns[2].Width = $w }
})

$LvASR.Add_KeyDown({
	if ($_.Control -and $_.KeyCode -eq 'A')
	{ $LvASR.Items | ForEach-Object { $_.Selected = $true } }
})

$TabASR.Controls.Add($LvASR)
$TabASR.Controls.Add($ToolStripASR)

$TsBtnRefresh.Add_Click({
	$StatusLabel.Text = 'Loading...'
	$Form.UseWaitCursor = $true
	[System.Windows.Forms.Application]::DoEvents()
	$LvASR.Items.Clear()
	try
	{
		$Rules = Get-CDASRRules
		foreach ($Rule in $Rules)
		{
			$Li = New-Object System.Windows.Forms.ListViewItem($Rule.Action)
			$Li.SubItems.Add($Rule.GUID)        | Out-Null
			$Li.SubItems.Add($Rule.Description) | Out-Null
			$Li.Tag       = $Rule.GUID
			$Li.ForeColor = Get-ASRItemColor $Rule.Action
			$LvASR.Items.Add($Li) | Out-Null
		}
		Add-EmptyPlaceholder $LvASR
		$StatusLabel.Text = "ASR Rules loaded ($($Rules.Count) rules)."
	}
	catch { $StatusLabel.Text = 'Error loading ASR Rules: ' + $_.Exception.Message }
	finally
	{
		$Form.UseWaitCursor = $false
		[System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::Default
	}
})
#endregion
