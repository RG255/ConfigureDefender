#requires -Version 5.0
<#
	.SYNOPSIS
	Windows Forms GUI for the ConfigureDefender module.

	.DESCRIPTION
	Provides a tabbed graphical interface to view and manage Microsoft Defender
	configuration.  Read operations run directly in this (non-elevated) process.
	Write operations are dispatched via a persistent elevated NamedPipe server
	opened on first use and kept alive until this window closes.

	Tabs
	----
	  1. ASR Rules         - view and toggle all ASR rules per-rule
	  2. ASR Exclusions    - list / add / remove ASR exclusion paths
	  3. Controlled Folders- list / add / remove protected folders
	  4. Allowed Apps      - list / add / remove / remove-missing allowed applications
	  5. Network Protection- view and set mode (Disabled / Audit / Enabled)
	  6. CFA State         - enable / audit / disable Controlled Folder Access
	  7. Events            - view recent ASR and CFA events from the event log

	.NOTES
	Elevation pattern
	-----------------
	  # On first admin operation:
	  Open-CDPipeSession

	  # Send a command to the elevated server:
	  $Mod = Get-Module ConfigureDefender
	  $SRP = $Mod.Invoke({ $script:CDSendRequestParams })
	  $SRP.DataObject = 'Set-CDASRRule -GUID "{0}" -Action Blocked' -f $GUID
	  Send-Request @SRP -NoExitOnError
	  $Result = $SRP.DataObject.Result
	  $Err    = $SRP.DataObject.Error

	  # On GUI close:
	  Close-CDPipeSession
#>

#region Module Load
Remove-Module ConfigureDefender -Force -ErrorAction SilentlyContinue
Import-Module ConfigureDefender -RequiredVersion 0.1 -ErrorAction Stop
#endregion

#region Assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
#endregion

#region Helpers
function Get-CDSRP
{
	# Returns the SendRequestParams hashtable, opening the pipe session if needed
	$Mod = Get-Module ConfigureDefender
	$SRP = $Mod.Invoke({ $script:CDSendRequestParams })
	if (-not $SRP)
	{
		$StatusLabel.Text = 'Opening elevated session...'
		[System.Windows.Forms.Application]::DoEvents()
		Open-CDPipeSession
		$SRP = $Mod.Invoke({ $script:CDSendRequestParams })
	}
	$SRP
}

function Get-ASRItemColor ([string]$Action)
{
	switch ($Action)
	{
		'Blocked'  { [System.Drawing.Color]::DarkRed }
		'Audit'    { [System.Drawing.Color]::DarkGoldenrod }
		'Warn'     { [System.Drawing.Color]::DarkOrange }
		'Disabled' { [System.Drawing.Color]::Gray }
		default    { [System.Drawing.Color]::LightGray }
	}
}
#endregion

#region Main Form
$Form                 = New-Object System.Windows.Forms.Form
$Form.Text            = 'Configure Defender  v0.1'
$Form.Size            = New-Object System.Drawing.Size(900, 650)
$Form.StartPosition   = 'CenterScreen'
$Form.FormBorderStyle = 'Sizable'
$Form.MaximizeBox     = $true

# Close handler - always shut down the pipe session cleanly
$Form.Add_FormClosing({
	Close-CDPipeSession
})
#endregion

#region Status Bar
$StatusBar    = New-Object System.Windows.Forms.StatusStrip
$StatusLabel  = New-Object System.Windows.Forms.ToolStripStatusLabel
$StatusLabel.Text = 'Ready'
$StatusBar.Items.Add($StatusLabel) | Out-Null
$Form.Controls.Add($StatusBar)
#endregion

#region Tab Control
$TabControl      = New-Object System.Windows.Forms.TabControl
$TabControl.Dock = 'Fill'
$TabControl.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$Form.Controls.Add($TabControl)

function New-Tab ([string]$Title)
{
	$Tab      = New-Object System.Windows.Forms.TabPage
	$Tab.Text = $Title
	$TabControl.TabPages.Add($Tab)
	$Tab
}
#endregion

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
$ToolStripASR.Items.Add($TsBtnRefresh) | Out-Null

$TsBtnSelectAll              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnSelectAll.Text         = 'Select All'
$TsBtnSelectAll.DisplayStyle = 'Text'
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

# Stretch Description column to fill available width on resize
$LvASR.Add_SizeChanged({
	$w = $LvASR.ClientSize.Width - 80 - 280 - 22  # Action + GUID + scrollbar
	if ($w -gt 100) { $LvASR.Columns[2].Width = $w }
})

# Ctrl+A to select all
$LvASR.Add_KeyDown({
	if ($_.Control -and $_.KeyCode -eq 'A')
	{ $LvASR.Items | ForEach-Object { $_.Selected = $true } }
})

# Add controls - ListView first so Fill docking works, then ToolStrip on top
$TabASR.Controls.Add($LvASR)
$TabASR.Controls.Add($ToolStripASR)

# Refresh handler - also called on initial load
$TsBtnRefresh.Add_Click({
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
		$StatusLabel.Text = "ASR Rules loaded ($($Rules.Count) rules)."
	}
	catch { $StatusLabel.Text = 'Error loading ASR Rules: ' + $_.Exception.Message }
})
#endregion

#region Tab 2 - ASR Exclusions
$TabExcl = New-Tab 'ASR Exclusions'

$ToolStripExcl      = New-Object System.Windows.Forms.ToolStrip
$ToolStripExcl.Dock = 'Top'

$TsBtnExclRefresh              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnExclRefresh.Text         = 'Refresh'
$TsBtnExclRefresh.DisplayStyle = 'Text'
$ToolStripExcl.Items.Add($TsBtnExclRefresh) | Out-Null

$TsBtnExclAdd              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnExclAdd.Text         = 'Add'
$TsBtnExclAdd.DisplayStyle = 'Text'
$ToolStripExcl.Items.Add($TsBtnExclAdd) | Out-Null

$TsBtnExclRemove              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnExclRemove.Text         = 'Remove Selected'
$TsBtnExclRemove.DisplayStyle = 'Text'
$ToolStripExcl.Items.Add($TsBtnExclRemove) | Out-Null

$ToolStripExcl.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
$ToolStripExcl.Items.Add((New-Object System.Windows.Forms.ToolStripLabel('Filter:'))) | Out-Null

$ExclFilterBox          = New-Object System.Windows.Forms.TextBox
$ExclFilterHost         = New-Object System.Windows.Forms.ToolStripControlHost($ExclFilterBox)
$ExclFilterHost.AutoSize = $false
$ExclFilterHost.Size    = New-Object System.Drawing.Size(200, 22)
$ToolStripExcl.Items.Add($ExclFilterHost) | Out-Null

$LvExcl               = New-Object System.Windows.Forms.ListView
$LvExcl.Dock          = 'Fill'
$LvExcl.View          = 'Details'
$LvExcl.FullRowSelect = $true
$LvExcl.GridLines     = $true
$LvExcl.MultiSelect   = $true
$LvExcl.Columns.Add('Path', 800) | Out-Null
$LvExcl.Add_SizeChanged({
	$w = $LvExcl.ClientSize.Width - 22
	if ($w -gt 100) { $LvExcl.Columns[0].Width = $w }
})

$TabExcl.Controls.Add($LvExcl)
$TabExcl.Controls.Add($ToolStripExcl)

function Update-ASRExclView
{
	$LvExcl.Items.Clear()
	if (-not $script:ASRExclCache) { return }
	$Filter = $ExclFilterBox.Text.Trim()
	$ToShow = if ($Filter) { $script:ASRExclCache | Where-Object { $_ -ilike "*$Filter*" } } else { $script:ASRExclCache }
	foreach ($P in $ToShow)
	{ $LvExcl.Items.Add((New-Object System.Windows.Forms.ListViewItem($P))) | Out-Null }
	$Count = @($ToShow).Count
	$Total = $script:ASRExclCache.Count
	$StatusLabel.Text = if ($Filter) { "ASR Exclusions: $Count of $Total shown." } else { "ASR Exclusions loaded ($Total entries)." }
}

$TsBtnExclRefresh.Add_Click({
	try
	{
		$SRP = Get-CDSRP
		$SRP.DataObject = 'Get-CDASRExclusions' | Send-Request @SRP -NoExitOnError
		if ($SRP.DataObject.Error)
		{ $StatusLabel.Text = "Error: $($SRP.DataObject.Error)"; return }
		$script:ASRExclCache = @($SRP.DataObject.Result)
		Update-ASRExclView
	}
	catch { $StatusLabel.Text = 'Error loading ASR Exclusions: ' + $_.Exception.Message }
})

$ExclFilterBox.Add_TextChanged({ Update-ASRExclView })

# Shared dialog for Add and Edit - returns the entered path or $null
function Show-ExclPathDialog ([string]$Title, [string]$Initial = '')
{
	$Dlg                 = New-Object System.Windows.Forms.Form
	$Dlg.Text            = $Title
	$Dlg.Size            = New-Object System.Drawing.Size(580, 130)
	$Dlg.StartPosition   = 'CenterParent'
	$Dlg.FormBorderStyle = 'FixedDialog'
	$Dlg.MaximizeBox     = $false
	$Dlg.MinimizeBox     = $false

	$Lbl          = New-Object System.Windows.Forms.Label
	$Lbl.Text     = 'Path to exclude — wildcards allowed (e.g. C:\Temp\*.tmp):'
	$Lbl.Location = New-Object System.Drawing.Point(10, 10)
	$Lbl.Size     = New-Object System.Drawing.Size(545, 18)
	$Dlg.Controls.Add($Lbl)

	$Txt          = New-Object System.Windows.Forms.TextBox
	$Txt.Text     = $Initial
	$Txt.Location = New-Object System.Drawing.Point(10, 30)
	$Txt.Size     = New-Object System.Drawing.Size(340, 22)
	$Dlg.Controls.Add($Txt)

	$BtnFile          = New-Object System.Windows.Forms.Button
	$BtnFile.Text     = 'File...'
	$BtnFile.Location = New-Object System.Drawing.Point(355, 28)
	$BtnFile.Size     = New-Object System.Drawing.Size(55, 25)
	$BtnFile.Add_Click({
		$OFD        = New-Object System.Windows.Forms.OpenFileDialog
		$OFD.Title  = 'Select a file to exclude'
		$OFD.Filter = 'All files (*.*)|*.*'
		if ($OFD.ShowDialog() -eq 'OK') { $Txt.Text = $OFD.FileName }
	})
	$Dlg.Controls.Add($BtnFile)

	$BtnFolder          = New-Object System.Windows.Forms.Button
	$BtnFolder.Text     = 'Folder...'
	$BtnFolder.Location = New-Object System.Drawing.Point(415, 28)
	$BtnFolder.Size     = New-Object System.Drawing.Size(60, 25)
	$BtnFolder.Add_Click({
		$FBD             = New-Object System.Windows.Forms.FolderBrowserDialog
		$FBD.Description = 'Select a folder to exclude'
		if ($FBD.ShowDialog() -eq 'OK') { $Txt.Text = $FBD.SelectedPath }
	})
	$Dlg.Controls.Add($BtnFolder)

	$BtnOK              = New-Object System.Windows.Forms.Button
	$BtnOK.Text         = 'OK'
	$BtnOK.DialogResult = 'OK'
	$BtnOK.Location     = New-Object System.Drawing.Point(380, 62)
	$BtnOK.Size         = New-Object System.Drawing.Size(70, 25)
	$Dlg.Controls.Add($BtnOK)
	$Dlg.AcceptButton   = $BtnOK

	$BtnCnl              = New-Object System.Windows.Forms.Button
	$BtnCnl.Text         = 'Cancel'
	$BtnCnl.DialogResult = 'Cancel'
	$BtnCnl.Location     = New-Object System.Drawing.Point(455, 62)
	$BtnCnl.Size         = New-Object System.Drawing.Size(70, 25)
	$Dlg.Controls.Add($BtnCnl)
	$Dlg.CancelButton    = $BtnCnl

	if ($Dlg.ShowDialog($Form) -eq 'OK' -and $Txt.Text.Trim())
	{ $Txt.Text.Trim() }
	else
	{ $null }
}

$TsBtnExclAdd.Add_Click({
	$P = Show-ExclPathDialog 'Add ASR Exclusion'
	if ($P)
	{
		try
		{
			$SRP     = Get-CDSRP
			$Escaped = $P -replace "'", "''"
			$SRP.DataObject = "Set-CDASRExclusion -Path '$Escaped' -Add" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error)
			{ $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" }
			else
			{
				$script:ASRExclCache += $P
				Update-ASRExclView
				$StatusLabel.Text = "Added exclusion: $P"
			}
		}
		catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
	}
})

# Double-click to edit an existing exclusion
$LvExcl.Add_DoubleClick({
	$Li = $LvExcl.FocusedItem
	if (-not $Li) { return }
	$OldPath = $Li.Text
	$NewPath = Show-ExclPathDialog 'Edit ASR Exclusion' $OldPath
	if ($NewPath -and $NewPath -ne $OldPath)
	{
		try
		{
			$SRP        = Get-CDSRP
			$EscOld     = $OldPath -replace "'", "''"
			$EscNew     = $NewPath -replace "'", "''"
			$SRP.DataObject = "Set-CDASRExclusion -Path '$EscOld' -Remove" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error)
			{ $StatusLabel.Text = "Error removing old path: $($SRP.DataObject.Error)"; return }
			$SRP.DataObject = "Set-CDASRExclusion -Path '$EscNew' -Add" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error)
			{ $StatusLabel.Text = "Error adding new path: $($SRP.DataObject.Error)"; return }
			# Update cache and view
			$script:ASRExclCache = $script:ASRExclCache | Where-Object { $_ -ne $OldPath }
			$script:ASRExclCache += $NewPath
			Update-ASRExclView
			$StatusLabel.Text = "Updated exclusion: $NewPath"
		}
		catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
	}
})

$TsBtnExclRemove.Add_Click({
	$Selected = @($LvExcl.SelectedItems)
	if ($Selected.Count -eq 0) { $StatusLabel.Text = 'No items selected.'; return }
	try
	{
		$SRP      = Get-CDSRP
		$Ok       = 0
		$ErrCount = 0
		foreach ($Li in $Selected)
		{
			$P       = $Li.Text
			$Escaped = $P -replace "'", "''"
			$SRP.DataObject = "Set-CDASRExclusion -Path '$Escaped' -Remove" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error)
			{ $ErrCount++; $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" }
			else
			{ $LvExcl.Items.Remove($Li); $Ok++ }
		}
		if ($ErrCount -eq 0) { $StatusLabel.Text = "Removed $Ok exclusion(s)." }
		else { $StatusLabel.Text = "Removed $Ok, $ErrCount error(s)." }
	}
	catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
})
#endregion

#region Tab 3 - Controlled Folders
$TabCF = New-Tab 'Controlled Folders'

$ToolStripCF      = New-Object System.Windows.Forms.ToolStrip
$ToolStripCF.Dock = 'Top'

$TsBtnCFRefresh              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnCFRefresh.Text         = 'Refresh'
$TsBtnCFRefresh.DisplayStyle = 'Text'
$ToolStripCF.Items.Add($TsBtnCFRefresh) | Out-Null

$TsBtnCFAdd              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnCFAdd.Text         = 'Add'
$TsBtnCFAdd.DisplayStyle = 'Text'
$ToolStripCF.Items.Add($TsBtnCFAdd) | Out-Null

$TsBtnCFRemove              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnCFRemove.Text         = 'Remove Selected'
$TsBtnCFRemove.DisplayStyle = 'Text'
$ToolStripCF.Items.Add($TsBtnCFRemove) | Out-Null

$LvCF               = New-Object System.Windows.Forms.ListView
$LvCF.Dock          = 'Fill'
$LvCF.View          = 'Details'
$LvCF.FullRowSelect = $true
$LvCF.GridLines     = $true
$LvCF.MultiSelect   = $true
$LvCF.Columns.Add('Folder', 800) | Out-Null
$LvCF.Add_SizeChanged({
	$w = $LvCF.ClientSize.Width - 22
	if ($w -gt 100) { $LvCF.Columns[0].Width = $w }
})

$TabCF.Controls.Add($LvCF)
$TabCF.Controls.Add($ToolStripCF)

$TsBtnCFRefresh.Add_Click({
	$LvCF.Items.Clear()
	try
	{
		$Folders = Get-CDControlledFolders
		foreach ($F in $Folders)
		{ $LvCF.Items.Add((New-Object System.Windows.Forms.ListViewItem($F))) | Out-Null }
		$StatusLabel.Text = "Controlled Folders loaded ($(@($Folders).Count) entries)."
	}
	catch { $StatusLabel.Text = 'Error loading Controlled Folders: ' + $_.Exception.Message }
})

$TsBtnCFAdd.Add_Click({
	$FBD = New-Object System.Windows.Forms.FolderBrowserDialog
	$FBD.Description      = 'Select a folder to protect with Controlled Folder Access'
	$FBD.ShowNewFolderButton = $false
	if ($FBD.ShowDialog($Form) -eq 'OK')
	{
		$F = $FBD.SelectedPath
		try
		{
			$SRP     = Get-CDSRP
			$Escaped = $F -replace "'", "''"
			$SRP.DataObject = "Set-CDControlledFolder -Folder '$Escaped' -Add" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error)
			{ $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" }
			else
			{
				$LvCF.Items.Add((New-Object System.Windows.Forms.ListViewItem($F))) | Out-Null
				$StatusLabel.Text = "Added protected folder: $F"
			}
		}
		catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
	}
})

$TsBtnCFRemove.Add_Click({
	$Selected = @($LvCF.SelectedItems)
	if ($Selected.Count -eq 0) { $StatusLabel.Text = 'No items selected.'; return }
	try
	{
		$SRP      = Get-CDSRP
		$Ok       = 0
		$ErrCount = 0
		foreach ($Li in $Selected)
		{
			$F       = $Li.Text
			$Escaped = $F -replace "'", "''"
			$SRP.DataObject = "Set-CDControlledFolder -Folder '$Escaped' -Remove" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error)
			{ $ErrCount++; $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" }
			else
			{ $LvCF.Items.Remove($Li); $Ok++ }
		}
		if ($ErrCount -eq 0) { $StatusLabel.Text = "Removed $Ok folder(s)." }
		else { $StatusLabel.Text = "Removed $Ok, $ErrCount error(s)." }
	}
	catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
})
#endregion

#region Tab 4 - Allowed Applications
$TabApps = New-Tab 'Allowed Apps'

$ToolStripApps      = New-Object System.Windows.Forms.ToolStrip
$ToolStripApps.Dock = 'Top'

$TsBtnAppsRefresh              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnAppsRefresh.Text         = 'Refresh'
$TsBtnAppsRefresh.DisplayStyle = 'Text'
$ToolStripApps.Items.Add($TsBtnAppsRefresh) | Out-Null

$TsBtnAppsAdd              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnAppsAdd.Text         = 'Add'
$TsBtnAppsAdd.DisplayStyle = 'Text'
$ToolStripApps.Items.Add($TsBtnAppsAdd) | Out-Null

$TsBtnAppsRemove              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnAppsRemove.Text         = 'Remove'
$TsBtnAppsRemove.DisplayStyle = 'Text'
$ToolStripApps.Items.Add($TsBtnAppsRemove) | Out-Null

$TsBtnAppsRemoveMissing              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnAppsRemoveMissing.Text         = 'Rm Missing'
$TsBtnAppsRemoveMissing.DisplayStyle = 'Text'
$ToolStripApps.Items.Add($TsBtnAppsRemoveMissing) | Out-Null

$ToolStripApps.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
$ToolStripApps.Items.Add((New-Object System.Windows.Forms.ToolStripLabel('Filter:'))) | Out-Null

$AppsFilterBox           = New-Object System.Windows.Forms.TextBox
$AppsFilterHost          = New-Object System.Windows.Forms.ToolStripControlHost($AppsFilterBox)
$AppsFilterHost.AutoSize = $false
$AppsFilterHost.Size     = New-Object System.Drawing.Size(160, 22)
$ToolStripApps.Items.Add($AppsFilterHost) | Out-Null

$LvApps               = New-Object System.Windows.Forms.ListView
$LvApps.Dock          = 'Fill'
$LvApps.View          = 'Details'
$LvApps.FullRowSelect = $true
$LvApps.GridLines     = $true
$LvApps.MultiSelect   = $true
$LvApps.Columns.Add('Status',  60) | Out-Null
$LvApps.Columns.Add('Path',   700) | Out-Null
$LvApps.Add_SizeChanged({
	$w = $LvApps.ClientSize.Width - 60 - 22
	if ($w -gt 100) { $LvApps.Columns[1].Width = $w }
})

$TabApps.Controls.Add($LvApps)
$TabApps.Controls.Add($ToolStripApps)

function Update-AllowedAppsView
{
	$LvApps.Items.Clear()
	if (-not $script:AllowedAppsCache) { return }
	$Filter  = $AppsFilterBox.Text.Trim()
	$ToShow  = if ($Filter) { $script:AllowedAppsCache | Where-Object { $_ -ilike "*$Filter*" } } else { $script:AllowedAppsCache }
	foreach ($A in $ToShow)
	{
		$Exists = Test-Path -Path $A
		$Li     = New-Object System.Windows.Forms.ListViewItem($(if ($Exists) { 'OK' } else { 'Missing' }))
		$Li.SubItems.Add($A) | Out-Null
		$Li.ForeColor = if ($Exists) { [System.Drawing.Color]::Black } else { [System.Drawing.Color]::Red }
		$LvApps.Items.Add($Li) | Out-Null
	}
	$Count = @($ToShow).Count
	$Total = $script:AllowedAppsCache.Count
	$StatusLabel.Text = if ($Filter) { "Allowed Applications: $Count of $Total shown." } else { "Allowed Applications loaded ($Total entries)." }
}

$TsBtnAppsRefresh.Add_Click({
	try
	{
		$SRP = Get-CDSRP
		$SRP.DataObject = 'Get-CDAllowedApplications' | Send-Request @SRP -NoExitOnError
		if ($SRP.DataObject.Error)
		{ $StatusLabel.Text = "Error: $($SRP.DataObject.Error)"; return }
		$script:AllowedAppsCache = @($SRP.DataObject.Result)
		Update-AllowedAppsView
	}
	catch { $StatusLabel.Text = 'Error loading Allowed Applications: ' + $_.Exception.Message }
})

$AppsFilterBox.Add_TextChanged({ Update-AllowedAppsView })

$TsBtnAppsAdd.Add_Click({
	$OFD        = New-Object System.Windows.Forms.OpenFileDialog
	$OFD.Title  = 'Select an application to allow through Controlled Folder Access'
	$OFD.Filter = 'Executable files (*.exe)|*.exe|All files (*.*)|*.*'
	if ($OFD.ShowDialog($Form) -eq 'OK')
	{
		$A = $OFD.FileName
		try
		{
			$SRP     = Get-CDSRP
			$Escaped = $A -replace "'", "''"
			$SRP.DataObject = "Set-CDAllowedApplication -Path '$Escaped' -Add" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error)
			{ $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" }
			else
			{
				$Li = New-Object System.Windows.Forms.ListViewItem('OK')
				$Li.SubItems.Add($A) | Out-Null
				$LvApps.Items.Add($Li) | Out-Null
				$StatusLabel.Text = "Added allowed application: $A"
			}
		}
		catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
	}
})

$TsBtnAppsRemove.Add_Click({
	$Selected = @($LvApps.SelectedItems)
	if ($Selected.Count -eq 0) { $StatusLabel.Text = 'No items selected.'; return }
	try
	{
		$SRP      = Get-CDSRP
		$Ok       = 0
		$ErrCount = 0
		foreach ($Li in $Selected)
		{
			$A       = $Li.SubItems[1].Text
			$Escaped = $A -replace "'", "''"
			$SRP.DataObject = "Set-CDAllowedApplication -Path '$Escaped' -Remove" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error)
			{ $ErrCount++; $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" }
			else
			{ $LvApps.Items.Remove($Li); $Ok++ }
		}
		if ($ErrCount -eq 0) { $StatusLabel.Text = "Removed $Ok application(s)." }
		else { $StatusLabel.Text = "Removed $Ok, $ErrCount error(s)." }
	}
	catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
})

$TsBtnAppsRemoveMissing.Add_Click({
	try
	{
		$SRP = Get-CDSRP
		$SRP.DataObject = 'Set-CDAllowedApplication -RemoveMissing' | Send-Request @SRP -NoExitOnError
		if ($SRP.DataObject.Error)
		{ $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" }
		else
		{
			$StatusLabel.Text = 'Missing applications removed.'
			$TsBtnAppsRefresh.PerformClick()
		}
	}
	catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
})
#endregion

#region Tab 5 - Network Protection
$TabNP   = New-Tab 'Network Protection'
$PanelNP = New-Object System.Windows.Forms.Panel
$PanelNP.Dock = 'Fill'
$TabNP.Controls.Add($PanelNP)

$LblNPState           = New-Object System.Windows.Forms.Label
$LblNPState.Text      = 'Current state: (click Refresh)'
$LblNPState.Font      = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$LblNPState.Location  = New-Object System.Drawing.Point(16, 16)
$LblNPState.AutoSize  = $true

$RbNPDisabled          = New-Object System.Windows.Forms.RadioButton
$RbNPDisabled.Text     = 'Disabled'
$RbNPDisabled.Tag      = 'Disable'
$RbNPDisabled.Location = New-Object System.Drawing.Point(16, 50)
$RbNPDisabled.AutoSize = $true

$RbNPAudit          = New-Object System.Windows.Forms.RadioButton
$RbNPAudit.Text     = 'Audit Mode'
$RbNPAudit.Tag      = 'Audit'
$RbNPAudit.Location = New-Object System.Drawing.Point(16, 75)
$RbNPAudit.AutoSize = $true

$RbNPEnabled          = New-Object System.Windows.Forms.RadioButton
$RbNPEnabled.Text     = 'Enabled'
$RbNPEnabled.Tag      = 'Enable'
$RbNPEnabled.Location = New-Object System.Drawing.Point(16, 100)
$RbNPEnabled.AutoSize = $true

$BtnNPRefresh          = New-Object System.Windows.Forms.Button
$BtnNPRefresh.Text     = 'Refresh'
$BtnNPRefresh.Location = New-Object System.Drawing.Point(16, 135)
$BtnNPRefresh.Size     = New-Object System.Drawing.Size(80, 28)

$BtnNPApply          = New-Object System.Windows.Forms.Button
$BtnNPApply.Text     = 'Apply'
$BtnNPApply.Location = New-Object System.Drawing.Point(104, 135)
$BtnNPApply.Size     = New-Object System.Drawing.Size(80, 28)

$PanelNP.Controls.AddRange(@($LblNPState, $RbNPDisabled, $RbNPAudit, $RbNPEnabled, $BtnNPRefresh, $BtnNPApply))

# Map NP integer value -> RadioButton
$NPRadioMap = @{ 0 = $RbNPDisabled; 1 = $RbNPEnabled; 2 = $RbNPAudit }

$BtnNPRefresh.Add_Click({
	try
	{
		$State = Get-CDNetworkProtection
		$LblNPState.Text = "Current state: $($State.Description)"
		$Rb = $NPRadioMap[$State.Value]
		if ($Rb) { $Rb.Checked = $true }
		else { foreach ($R in $NPRadioMap.Values) { $R.Checked = $false } }
		$StatusLabel.Text = "Network Protection: $($State.Description)"
	}
	catch { $StatusLabel.Text = 'Error loading Network Protection: ' + $_.Exception.Message }
})

$BtnNPApply.Add_Click({
	$Rb = @($RbNPDisabled, $RbNPAudit, $RbNPEnabled) | Where-Object { $_.Checked } | Select-Object -First 1
	if (-not $Rb) { $StatusLabel.Text = 'No option selected.'; return }
	try
	{
		$SRP = Get-CDSRP
		$SRP.DataObject = "Set-CDNetworkProtection -$($Rb.Tag)" | Send-Request @SRP -NoExitOnError
		if ($SRP.DataObject.Error)
		{ $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" }
		else
		{
			$StatusLabel.Text = "Network Protection set to: $($Rb.Text)"
			$BtnNPRefresh.PerformClick()
		}
	}
	catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
})
#endregion

#region Tab 6 - CFA State
$TabCFA   = New-Tab 'CFA State'
$PanelCFA = New-Object System.Windows.Forms.Panel
$PanelCFA.Dock = 'Fill'
$TabCFA.Controls.Add($PanelCFA)

$LblCFAState           = New-Object System.Windows.Forms.Label
$LblCFAState.Text      = 'Current state: (click Refresh)'
$LblCFAState.Font      = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$LblCFAState.Location  = New-Object System.Drawing.Point(16, 16)
$LblCFAState.AutoSize  = $true

$RbCFADisabled          = New-Object System.Windows.Forms.RadioButton
$RbCFADisabled.Text     = 'Disabled'
$RbCFADisabled.Tag      = 'Disable'
$RbCFADisabled.Location = New-Object System.Drawing.Point(16, 50)
$RbCFADisabled.AutoSize = $true

$RbCFAAudit          = New-Object System.Windows.Forms.RadioButton
$RbCFAAudit.Text     = 'Audit Mode'
$RbCFAAudit.Tag      = 'Audit'
$RbCFAAudit.Location = New-Object System.Drawing.Point(16, 75)
$RbCFAAudit.AutoSize = $true

$RbCFAEnabled          = New-Object System.Windows.Forms.RadioButton
$RbCFAEnabled.Text     = 'Enabled'
$RbCFAEnabled.Tag      = 'Enable'
$RbCFAEnabled.Location = New-Object System.Drawing.Point(16, 100)
$RbCFAEnabled.AutoSize = $true

$LblCFANote           = New-Object System.Windows.Forms.Label
$LblCFANote.Text      = 'Note: Block/Audit Disk Modification states (values 3/4) are shown read-only when active.'
$LblCFANote.ForeColor = [System.Drawing.Color]::DimGray
$LblCFANote.Location  = New-Object System.Drawing.Point(16, 126)
$LblCFANote.AutoSize  = $true

$BtnCFARefresh          = New-Object System.Windows.Forms.Button
$BtnCFARefresh.Text     = 'Refresh'
$BtnCFARefresh.Location = New-Object System.Drawing.Point(16, 150)
$BtnCFARefresh.Size     = New-Object System.Drawing.Size(80, 28)

$BtnCFAApply          = New-Object System.Windows.Forms.Button
$BtnCFAApply.Text     = 'Apply'
$BtnCFAApply.Location = New-Object System.Drawing.Point(104, 150)
$BtnCFAApply.Size     = New-Object System.Drawing.Size(80, 28)

$PanelCFA.Controls.AddRange(@($LblCFAState, $RbCFADisabled, $RbCFAAudit, $RbCFAEnabled, $LblCFANote, $BtnCFARefresh, $BtnCFAApply))

# Map CFA integer value -> RadioButton (only values 0-2 are settable)
$CFARadioMap = @{ 0 = $RbCFADisabled; 1 = $RbCFAEnabled; 2 = $RbCFAAudit }

$BtnCFARefresh.Add_Click({
	try
	{
		$State = Get-CDControlledFolderAccess
		$LblCFAState.Text = "Current state: $($State.Description)"
		$Rb = $CFARadioMap[$State.Value]
		if ($Rb) { $Rb.Checked = $true }
		else { foreach ($R in $CFARadioMap.Values) { $R.Checked = $false } }
		$StatusLabel.Text = "CFA State: $($State.Description)"
	}
	catch { $StatusLabel.Text = 'Error loading CFA State: ' + $_.Exception.Message }
})

$BtnCFAApply.Add_Click({
	$Rb = @($RbCFADisabled, $RbCFAAudit, $RbCFAEnabled) | Where-Object { $_.Checked } | Select-Object -First 1
	if (-not $Rb) { $StatusLabel.Text = 'No option selected.'; return }
	try
	{
		$SRP = Get-CDSRP
		$SRP.DataObject = "Set-CDControlledFolderAccess -$($Rb.Tag)" | Send-Request @SRP -NoExitOnError
		if ($SRP.DataObject.Error)
		{ $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" }
		else
		{
			$StatusLabel.Text = "CFA State set to: $($Rb.Text)"
			$BtnCFARefresh.PerformClick()
		}
	}
	catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
})
#endregion

#region Tab 7 - Events
$TabEvents = New-Tab 'Events'

$ToolStripEvents      = New-Object System.Windows.Forms.ToolStrip
$ToolStripEvents.Dock = 'Top'

$TsBtnEvRefresh              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnEvRefresh.Text         = 'Refresh'
$TsBtnEvRefresh.DisplayStyle = 'Text'
$ToolStripEvents.Items.Add($TsBtnEvRefresh) | Out-Null

$ToolStripEvents.Items.Add(
	(New-Object System.Windows.Forms.ToolStripLabel('  Filter:'))
) | Out-Null

$TsCmbEvFilter               = New-Object System.Windows.Forms.ToolStripComboBox
$TsCmbEvFilter.DropDownStyle = 'DropDownList'
$TsCmbEvFilter.Width         = 70
$TsCmbEvFilter.Items.AddRange(@('All', 'ASR', 'CFA'))
$TsCmbEvFilter.SelectedIndex = 0
$ToolStripEvents.Items.Add($TsCmbEvFilter) | Out-Null

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
	$LvEvents.Items.Clear()
	try
	{
		$FilterVal = $TsCmbEvFilter.SelectedItem.ToString()
		$Events    = Get-CDEvents -Filter $FilterVal
		foreach ($Ev in $Events)
		{
			$Li = New-Object System.Windows.Forms.ListViewItem($Ev.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))
			$Li.SubItems.Add($Ev.EventType)                                       | Out-Null
			$Li.SubItems.Add($(if ($Ev.ProcessName) { $Ev.ProcessName } else { '' })) | Out-Null
			$Li.SubItems.Add($(if ($Ev.Path)        { $Ev.Path }        else { '' })) | Out-Null
			$Li.SubItems.Add($(if ($Ev.RuleInfo)    { $Ev.RuleInfo }    else { '' })) | Out-Null
			if ($Ev.EventID -eq '1123') { $Li.ForeColor = [System.Drawing.Color]::DarkBlue }
			$LvEvents.Items.Add($Li) | Out-Null
		}
		$StatusLabel.Text = "Events loaded ($(@($Events).Count) events)."
	}
	catch { $StatusLabel.Text = 'Error loading Events: ' + $_.Exception.Message }
})
#endregion

#region Initial Load
$Form.Add_Shown({
	$TsBtnRefresh.PerformClick()
})
#endregion

# Show the form
[System.Windows.Forms.Application]::Run($Form)
