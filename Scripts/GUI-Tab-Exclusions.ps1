#region Tab 3 - Exclusions (ASR / Paths / Extensions / Processes / IPs)
# The category table ($script:ExclTypes) and every function that works on it (Get-ExclCommand, Get-ExclFiltered,
# Get-ExclValidation, Confirm-ExclValue, Show-ExclDialog) are in GUI-Helpers.ps1, dot-sourced before this file. This file only
# builds the controls from that table and wires them, so a category is added or changed in ONE place.
$TabExcl             = New-Tab 'Exclusions'
$script:ExclCategory = ''
$script:ExclUi       = @{}   # category -> @{ Btn = <category button>; Lv = <list view>; Cache = <entries, or $null until loaded> }

# --- Toolbar ---
$ToolStripExcl      = New-Object System.Windows.Forms.ToolStrip
$ToolStripExcl.Dock = 'Top'

# One category button per table row, in table order (ASR, Paths, Extensions, Processes, IPs)
foreach ($Cat in $script:ExclTypes.Keys)
{
	$Type              = $script:ExclTypes[$Cat]
	$Btn               = New-Object System.Windows.Forms.ToolStripButton
	$Btn.Text          = $Type.Button
	$Btn.DisplayStyle  = 'Text'
	$Btn.ToolTipText   = $Type.Tip
	$Btn.Tag           = $Cat
	$Btn.Add_Click({ Switch-ExclCategory $this.Tag })
	$ToolStripExcl.Items.Add($Btn) | Out-Null
	$script:ExclUi[$Cat] = @{ Btn = $Btn; Lv = $null; Cache = $null }
}

$SepExclActions         = New-Object System.Windows.Forms.ToolStripSeparator
$SepExclActions.Visible = $false
$ToolStripExcl.Items.Add($SepExclActions) | Out-Null

$TsBtnExclRefresh              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnExclRefresh.Text         = 'Refresh'
$TsBtnExclRefresh.DisplayStyle = 'Text'
$TsBtnExclRefresh.ToolTipText  = 'Refresh exclusions from Windows Defender'
$TsBtnExclRefresh.Visible      = $false
$ToolStripExcl.Items.Add($TsBtnExclRefresh) | Out-Null

$TsBtnExclAdd              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnExclAdd.Text         = 'Add'
$TsBtnExclAdd.DisplayStyle = 'Text'
$TsBtnExclAdd.ToolTipText  = 'Add a new exclusion'
$TsBtnExclAdd.Visible      = $false
$ToolStripExcl.Items.Add($TsBtnExclAdd) | Out-Null

$TsBtnExclRemove              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnExclRemove.Text         = 'Remove Selected'
$TsBtnExclRemove.DisplayStyle = 'Text'
$TsBtnExclRemove.ToolTipText  = 'Remove selected exclusion(s)'
$TsBtnExclRemove.Visible      = $false
$ToolStripExcl.Items.Add($TsBtnExclRemove) | Out-Null

$SepExclFilter         = New-Object System.Windows.Forms.ToolStripSeparator
$SepExclFilter.Visible = $false
$ToolStripExcl.Items.Add($SepExclFilter) | Out-Null

$LblExclFilter         = New-Object System.Windows.Forms.ToolStripLabel('Filter:')
$LblExclFilter.Visible = $false
$ToolStripExcl.Items.Add($LblExclFilter) | Out-Null

$ExclFilterBox           = New-Object System.Windows.Forms.TextBox
$ExclFilterHost          = New-Object System.Windows.Forms.ToolStripControlHost($ExclFilterBox)
$ExclFilterHost.AutoSize = $false
$ExclFilterHost.Size     = New-Object System.Drawing.Size(200, 22)
$ExclFilterHost.Visible  = $false
$ToolStripExcl.Items.Add($ExclFilterHost) | Out-Null

# --- Panel hosting one ListView per category (only the active one is visible) ---
$PanelExcl      = New-Object System.Windows.Forms.Panel
$PanelExcl.Dock = 'Fill'

foreach ($Cat in $script:ExclTypes.Keys)
{
	$Type              = $script:ExclTypes[$Cat]
	$Lv                = New-Object System.Windows.Forms.ListView
	$Lv.Dock           = 'Fill'
	$Lv.View           = 'Details'
	$Lv.FullRowSelect  = $true
	$Lv.GridLines      = $true
	$Lv.MultiSelect    = $true
	$Lv.Visible        = $false
	$Lv.Tag            = $Cat
	$Lv.Columns.Add($Type.Column, 800) | Out-Null
	$Lv.Add_SizeChanged({
			$w = $this.ClientSize.Width - 22
			if ($w -gt 100) { $this.Columns[0].Width = $w }
		})
	$Lv.Add_DoubleClick({ Edit-ExclEntry $this.Tag })
	$PanelExcl.Controls.Add($Lv)
	$script:ExclUi[$Cat].Lv = $Lv
}

$LblExclPrompt           = New-Object System.Windows.Forms.Label
$LblExclPrompt.Dock      = 'Fill'
$LblExclPrompt.Text      = 'Select an option'
$LblExclPrompt.TextAlign = 'MiddleCenter'
$LblExclPrompt.Font      = New-Object System.Drawing.Font('Segoe UI', 12)
$LblExclPrompt.ForeColor = [System.Drawing.Color]::Gray
$PanelExcl.Controls.Add($LblExclPrompt)

$TabExcl.Controls.Add($PanelExcl)
$TabExcl.Controls.Add($ToolStripExcl)

# --- Category switcher ---
function Switch-ExclCategory ([string]$Cat)
{
	$script:ExclCategory   = $Cat
	$LblExclPrompt.Visible = $false
	foreach ($Key in $script:ExclTypes.Keys)
	{
		$script:ExclUi[$Key].Lv.Visible  = ($Key -eq $Cat)
		$script:ExclUi[$Key].Btn.Checked = ($Key -eq $Cat)
	}
	$ExclFilterBox.Clear()
	Invoke-ExclRefresh
}

function Show-ExclActionBar
{
	$SepExclActions.Visible   = $true
	$TsBtnExclRefresh.Visible = $true
	$TsBtnExclAdd.Visible     = $true
	$TsBtnExclRemove.Visible  = $true
	$SepExclFilter.Visible    = $true
	$LblExclFilter.Visible    = $true
	$ExclFilterHost.Visible   = $true
}

# --- Update / filter ---
function Update-ExclView
{
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
		Justification = 'GUI helper that only refreshes an in-memory WinForms control''s displayed state; changes no system/Defender state.')]
	Param ([string]$Cat)
	$Type = $script:ExclTypes[$Cat]
	$Ui   = $script:ExclUi[$Cat]
	$Lv   = $Ui.Lv
	$Lv.BeginUpdate()
	try
	{
		$Lv.Items.Clear()
		if ($null -eq $Ui.Cache) { Add-EmptyPlaceholder $Lv '(nothing requested yet)'; return }
		if (-not $Ui.Cache) { Add-EmptyPlaceholder $Lv; $StatusLabel.Text = "$($Type.Label) loaded (0 entries)."; return }
		$Filter = $ExclFilterBox.Text.Trim()
		$ToShow = @(Get-ExclFiltered $Ui.Cache $Filter)
		foreach ($Item in $ToShow)
		{ $Lv.Items.Add((New-Object System.Windows.Forms.ListViewItem([string]$Item))) | Out-Null }
		Add-EmptyPlaceholder $Lv
	}
	finally { $Lv.EndUpdate() }
	$Count = $ToShow.Count; $Total = @($Ui.Cache).Count
	$StatusLabel.Text = if ($Filter) { "$($Type.Label): $Count of $Total shown." } else { "$($Type.Label) loaded ($Total entries)." }
}

$ExclFilterBox.Add_TextChanged({ if ($script:ExclCategory) { Update-ExclView $script:ExclCategory } })

# --- Refresh ---
function Invoke-ExclRefresh
{
	if ($script:ExclRefreshing) { return }
	$Cat = $script:ExclCategory
	if (-not $Cat) { return }
	$script:ExclRefreshing = $true
	Enter-GuiBusy
	try
	{
		# Reading the ASR and process exclusion lists needs elevation, so every category is read through the elevated server
		$SRP = Get-CDSRP
		$SRP.DataObject = $script:ExclTypes[$Cat].Get | Send-Request @SRP
		if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error: $($SRP.DataObject.Error)"; return }
		$script:ExclUi[$Cat].Cache = @($SRP.DataObject.Result)
		Update-ExclView $Cat
		Show-ExclActionBar
	}
	catch { $StatusLabel.Text = 'Error loading exclusions: ' + $_.Exception.Message }
	finally
	{
		$script:ExclRefreshing = $false
		Exit-GuiBusy
	}
}

$TsBtnExclRefresh.Add_Click({ Invoke-ExclRefresh })

# --- Add ---
$TsBtnExclAdd.Add_Click({
		$Cat = $script:ExclCategory
		if (-not $Cat) { return }
		$Val = Show-ExclDialog $Cat 'Add'
		if (-not $Val) { return }
		if (-not (Confirm-ExclValue $Cat $Val)) { return }
		try
		{
			$SRP = Get-CDSRP
			$SRP.DataObject = (Get-ExclCommand $Cat $Val 'Add') | Send-Request @SRP
			if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" } else { $TsBtnExclRefresh.PerformClick() }
		}
		catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
	})

# --- Edit (double-click an entry) ---
function Edit-ExclEntry ([string]$Cat)
{
	$Li = $script:ExclUi[$Cat].Lv.FocusedItem
	if (-not $Li -or $Li.Tag -eq '$placeholder') { return }
	$OldVal = $Li.Text
	$NewVal = Show-ExclDialog $Cat 'Edit' $OldVal
	if (-not $NewVal -or $NewVal -eq $OldVal) { return }
	if (-not (Confirm-ExclValue $Cat $NewVal)) { return }
	try
	{
		$SRP = Get-CDSRP
		# Add the new entry FIRST: if it fails the original is untouched.
		$SRP.DataObject = (Get-ExclCommand $Cat $NewVal 'Add') | Send-Request @SRP
		if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error adding the new entry (old entry left as it was): $($SRP.DataObject.Error)"; return }
		$SRP.DataObject = (Get-ExclCommand $Cat $OldVal 'Remove') | Send-Request @SRP
		if ($SRP.DataObject.Error) { $StatusLabel.Text = "New entry added, but the old one could not be removed: $($SRP.DataObject.Error)" }
		$TsBtnExclRefresh.PerformClick()
	}
	catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
}

# --- Remove ---
$TsBtnExclRemove.Add_Click({
		$Cat = $script:ExclCategory
		if (-not $Cat) { return }
		$Selected = @($script:ExclUi[$Cat].Lv.SelectedItems | Where-Object { $_.Tag -ne '$placeholder' })
		if ($Selected.Count -eq 0) { $StatusLabel.Text = 'No items selected.'; return }
		try
		{
			$SRP = Get-CDSRP; $Ok = 0; $ErrCount = 0
			foreach ($Li in $Selected)
			{
				$SRP.DataObject = (Get-ExclCommand $Cat $Li.Text 'Remove') | Send-Request @SRP
				if ($SRP.DataObject.Error) { $ErrCount++; $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" }
				else { $Ok++ }
			}
			if ($ErrCount -gt 0) { $StatusLabel.Text = "Removed $Ok, $ErrCount error(s)." }
			if ($Ok -gt 0) { $TsBtnExclRefresh.PerformClick() }
		}
		catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
	})
#endregion
