#region Tab 7 - Controlled Folders
$TabCF = New-Tab 'Controlled Folders'

# SplitContainer: top = protected folders, bottom = allowed apps (collapsed by default)
$SplitCF                  = New-Object System.Windows.Forms.SplitContainer
$SplitCF.Dock             = 'Fill'
$SplitCF.Orientation      = 'Horizontal'
$SplitCF.SplitterDistance = 200
$SplitCF.Panel2Collapsed  = $true

$ToolStripCF      = New-Object System.Windows.Forms.ToolStrip
$ToolStripCF.Dock = 'Top'

$TsBtnCFRefresh              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnCFRefresh.Text         = 'Refresh'
$TsBtnCFRefresh.DisplayStyle = 'Text'
$TsBtnCFRefresh.ToolTipText  = 'Refresh protected folders from Windows Defender'
$ToolStripCF.Items.Add($TsBtnCFRefresh) | Out-Null

$TsBtnCFAdd              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnCFAdd.Text         = 'Add'
$TsBtnCFAdd.DisplayStyle = 'Text'
$TsBtnCFAdd.ToolTipText  = 'Add a protected folder'
$ToolStripCF.Items.Add($TsBtnCFAdd) | Out-Null

$TsBtnCFRemove              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnCFRemove.Text         = 'Remove Selected'
$TsBtnCFRemove.DisplayStyle = 'Text'
$TsBtnCFRemove.ToolTipText  = 'Remove selected folder(s)'
$ToolStripCF.Items.Add($TsBtnCFRemove) | Out-Null

$ToolStripCF.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

# Allowed Apps toggle button
$TsBtnAppsToggle              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnAppsToggle.Text         = 'Allowed Apps [+]'
$TsBtnAppsToggle.DisplayStyle = 'Text'
$TsBtnAppsToggle.ToolTipText  = 'Show/hide the Allowed Apps panel'
$TsBtnAppsToggle.Add_Click({
	$SplitCF.Panel2Collapsed = -not $SplitCF.Panel2Collapsed
	$TsBtnAppsToggle.Text = if ($SplitCF.Panel2Collapsed) { 'Allowed Apps [+]' } else { 'Allowed Apps [-]' }
	if (-not $SplitCF.Panel2Collapsed -and -not $script:AllowedAppsCache)
	{ $TsBtnAppsRefresh.PerformClick() }
})
$ToolStripCF.Items.Add($TsBtnAppsToggle) | Out-Null

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

$SplitCF.Panel1.Controls.Add($LvCF)
$SplitCF.Panel1.Controls.Add($ToolStripCF)

$TsBtnCFRefresh.Add_Click({
	$StatusLabel.Text = 'Loading...'
	$Form.UseWaitCursor = $true
	[System.Windows.Forms.Application]::DoEvents()
	$LvCF.Items.Clear()
	try
	{
		$Folders = Get-CDControlledFolders
		foreach ($F in $Folders)
		{ $LvCF.Items.Add((New-Object System.Windows.Forms.ListViewItem($F))) | Out-Null }
		Add-EmptyPlaceholder $LvCF
		$StatusLabel.Text = "Controlled Folders loaded ($(@($Folders).Count) entries)."
	}
	catch { $StatusLabel.Text = 'Error loading Controlled Folders: ' + $_.Exception.Message }
	finally { $Form.UseWaitCursor = $false }
	if (-not $SplitCF.Panel2Collapsed) { $TsBtnAppsRefresh.PerformClick() }
})

$TsBtnCFAdd.Add_Click({
	$FBD = New-Object System.Windows.Forms.FolderBrowserDialog
	$FBD.Description         = 'Select a folder to protect with Controlled Folder Access'
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
			{ $TsBtnCFRefresh.PerformClick() }
		}
		catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
	}
})

$TsBtnCFRemove.Add_Click({
	$Selected = @($LvCF.SelectedItems | Where-Object { $_.Tag -ne '$placeholder' })
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
			{ $Ok++ }
		}
		if ($ErrCount -gt 0) { $StatusLabel.Text = "Removed $Ok, $ErrCount error(s)." }
		if ($Ok -gt 0) { $TsBtnCFRefresh.PerformClick() }
	}
	catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
})

# --- Allowed Applications (bottom panel) ---
$ToolStripApps      = New-Object System.Windows.Forms.ToolStrip
$ToolStripApps.Dock = 'Top'

$TsBtnAppsRefresh              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnAppsRefresh.Text         = 'Refresh'
$TsBtnAppsRefresh.DisplayStyle = 'Text'
$TsBtnAppsRefresh.ToolTipText  = 'Refresh allowed apps from Windows Defender'
$ToolStripApps.Items.Add($TsBtnAppsRefresh) | Out-Null

$TsBtnAppsAdd              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnAppsAdd.Text         = 'Add'
$TsBtnAppsAdd.DisplayStyle = 'Text'
$TsBtnAppsAdd.ToolTipText  = 'Add an allowed application'
$ToolStripApps.Items.Add($TsBtnAppsAdd) | Out-Null

$TsBtnAppsRemove              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnAppsRemove.Text         = 'Remove'
$TsBtnAppsRemove.DisplayStyle = 'Text'
$TsBtnAppsRemove.ToolTipText  = 'Remove selected app(s)'
$ToolStripApps.Items.Add($TsBtnAppsRemove) | Out-Null

$TsBtnAppsRemoveMissing              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnAppsRemoveMissing.Text         = 'Rm Missing'
$TsBtnAppsRemoveMissing.DisplayStyle = 'Text'
$TsBtnAppsRemoveMissing.ToolTipText  = 'Remove entries where the application file no longer exists'
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

$SplitCF.Panel2.Controls.Add($LvApps)
$SplitCF.Panel2.Controls.Add($ToolStripApps)
$TabCF.Controls.Add($SplitCF)

function Update-AllowedAppsView
{
	$LvApps.Items.Clear()
	if (-not $script:AllowedAppsCache) { Add-EmptyPlaceholder $LvApps; return }
	$Filter = $AppsFilterBox.Text.Trim()
	$ToShow = if ($Filter) { $script:AllowedAppsCache | Where-Object { $_ -ilike "*$Filter*" } } else { $script:AllowedAppsCache }
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
	Add-EmptyPlaceholder $LvApps
	$StatusLabel.Text = if ($Filter) { "Allowed Applications: $Count of $Total shown." } else { "Allowed Applications loaded ($Total entries)." }
}

$TsBtnAppsRefresh.Add_Click({
	$StatusLabel.Text = 'Loading...'
	$Form.UseWaitCursor = $true
	[System.Windows.Forms.Application]::DoEvents()
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
	finally { $Form.UseWaitCursor = $false }
})

$AppsFilterBox.Add_TextChanged({ Update-AllowedAppsView })

function Show-AllowedAppDialog ([string]$Title, [string]$Initial = '')
{
	$Dlg                 = New-Object System.Windows.Forms.Form
	$Dlg.Text            = $Title
	$Dlg.Size            = New-Object System.Drawing.Size(620, 130)
	$Dlg.StartPosition   = 'CenterParent'
	$Dlg.FormBorderStyle = 'FixedDialog'
	$Dlg.MaximizeBox     = $false
	$Dlg.MinimizeBox     = $false

	$Lbl          = New-Object System.Windows.Forms.Label
	$Lbl.Text     = 'Application path (wildcards permitted, e.g. C:\App\app.exe or C:\App\*):'
	$Lbl.Location = New-Object System.Drawing.Point(10, 10)
	$Lbl.Size     = New-Object System.Drawing.Size(590, 18)
	$Dlg.Controls.Add($Lbl)

	$Txt          = New-Object System.Windows.Forms.TextBox
	$Txt.Text     = $Initial
	$Txt.Location = New-Object System.Drawing.Point(10, 30)
	$Txt.Size     = New-Object System.Drawing.Size(440, 22)
	$Dlg.Controls.Add($Txt)

	$BtnBrowse          = New-Object System.Windows.Forms.Button
	$BtnBrowse.Text     = 'Browse...'
	$BtnBrowse.Location = New-Object System.Drawing.Point(455, 28)
	$BtnBrowse.Size     = New-Object System.Drawing.Size(75, 25)
	$BtnBrowse.Add_Click({
		$OFD        = New-Object System.Windows.Forms.OpenFileDialog
		$OFD.Title  = 'Select an application'
		$OFD.Filter = 'Executable files (*.exe)|*.exe|All files (*.*)|*.*'
		if ($OFD.ShowDialog() -eq 'OK') { $Txt.Text = $OFD.FileName }
	})
	$Dlg.Controls.Add($BtnBrowse)

	$BtnOK              = New-Object System.Windows.Forms.Button
	$BtnOK.Text         = 'OK'
	$BtnOK.DialogResult = 'OK'
	$BtnOK.Location     = New-Object System.Drawing.Point(420, 62)
	$BtnOK.Size         = New-Object System.Drawing.Size(70, 25)
	$Dlg.Controls.Add($BtnOK)
	$Dlg.AcceptButton   = $BtnOK

	$BtnCnl              = New-Object System.Windows.Forms.Button
	$BtnCnl.Text         = 'Cancel'
	$BtnCnl.DialogResult = 'Cancel'
	$BtnCnl.Location     = New-Object System.Drawing.Point(495, 62)
	$BtnCnl.Size         = New-Object System.Drawing.Size(70, 25)
	$Dlg.Controls.Add($BtnCnl)
	$Dlg.CancelButton    = $BtnCnl

	if ($Dlg.ShowDialog($Form) -eq 'OK' -and $Txt.Text.Trim()) { $Txt.Text.Trim() } else { $null }
}

$TsBtnAppsAdd.Add_Click({
	$A = Show-AllowedAppDialog 'Add Allowed Application'
	if ($A)
	{
		if (-not (Test-CDExclusionPath $A))
		{
			[System.Windows.Forms.MessageBox]::Show(
				"'$A' is not a valid application path.`n`nPath must be absolute and start with a drive letter (C:\) or UNC path (\\server\share\). Wildcards are permitted (e.g. C:\App\*).`nInvalid characters: < > `" |",
				'Invalid Path', 'OK', 'Warning') | Out-Null
			return
		}
		try
		{
			$SRP     = Get-CDSRP
			$Escaped = $A -replace "'", "''"
			$SRP.DataObject = "Set-CDAllowedApplication -Path '$Escaped' -Add" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error)
			{ $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" }
			else
			{ $TsBtnAppsRefresh.PerformClick() }
		}
		catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
	}
})

$LvApps.Add_DoubleClick({
	$Li = $LvApps.FocusedItem
	if (-not $Li -or $Li.Tag -eq '$placeholder') { return }
	$OldPath = $Li.SubItems[1].Text
	$NewPath = Show-AllowedAppDialog 'Edit Allowed Application' $OldPath
	if ($NewPath -and $NewPath -ne $OldPath)
	{
		if (-not (Test-CDExclusionPath $NewPath))
		{
			[System.Windows.Forms.MessageBox]::Show(
				"'$NewPath' is not a valid application path.`n`nPath must be absolute and start with a drive letter (C:\) or UNC path (\\server\share\). Wildcards are permitted (e.g. C:\App\*).`nInvalid characters: < > `" |",
				'Invalid Path', 'OK', 'Warning') | Out-Null
			return
		}
		try
		{
			$SRP    = Get-CDSRP
			$EscOld = $OldPath -replace "'", "''"
			$EscNew = $NewPath -replace "'", "''"
			$SRP.DataObject = "Set-CDAllowedApplication -Path '$EscOld' -Remove" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error removing old entry: $($SRP.DataObject.Error)"; return }
			$SRP.DataObject = "Set-CDAllowedApplication -Path '$EscNew' -Add" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error adding new entry: $($SRP.DataObject.Error)"; return }
			$TsBtnAppsRefresh.PerformClick()
		}
		catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
	}
})

$TsBtnAppsRemove.Add_Click({
	$Selected = @($LvApps.SelectedItems | Where-Object { $_.Tag -ne '$placeholder' })
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
			{ $Ok++ }
		}
		if ($ErrCount -gt 0) { $StatusLabel.Text = "Removed $Ok, $ErrCount error(s)." }
		if ($Ok -gt 0) { $TsBtnAppsRefresh.PerformClick() }
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


