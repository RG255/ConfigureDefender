#region Shared helpers - dialog functions and input validation
# Dot-sourced before all GUI-Tab-*.ps1 files so every tab can call these.

# ---------------------------------------------------------------------------
# Dialog functions
# ---------------------------------------------------------------------------

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
	$Lbl.Text     = 'Path to exclude - wildcards allowed (e.g. C:\Temp\*.tmp):'
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

function Show-ExclProcessDialog ([string]$Title, [string]$Initial = '')
{
	$Dlg                 = New-Object System.Windows.Forms.Form
	$Dlg.Text            = $Title
	$Dlg.Size            = New-Object System.Drawing.Size(640, 130)
	$Dlg.StartPosition   = 'CenterParent'
	$Dlg.FormBorderStyle = 'FixedDialog'
	$Dlg.MaximizeBox     = $false
	$Dlg.MinimizeBox     = $false

	$Lbl          = New-Object System.Windows.Forms.Label
	$Lbl.Text     = 'Process name or full path (e.g. notepad.exe or C:\App\app.exe):'
	$Lbl.Location = New-Object System.Drawing.Point(10, 10)
	$Lbl.Size     = New-Object System.Drawing.Size(605, 18)
	$Dlg.Controls.Add($Lbl)

	$Txt          = New-Object System.Windows.Forms.TextBox
	$Txt.Text     = $Initial
	$Txt.Location = New-Object System.Drawing.Point(10, 30)
	$Txt.Size     = New-Object System.Drawing.Size(360, 22)
	$Dlg.Controls.Add($Txt)

	$BtnBrowse          = New-Object System.Windows.Forms.Button
	$BtnBrowse.Text     = 'Browse...'
	$BtnBrowse.Location = New-Object System.Drawing.Point(375, 28)
	$BtnBrowse.Size     = New-Object System.Drawing.Size(70, 25)
	$BtnBrowse.Add_Click({
		$OFD        = New-Object System.Windows.Forms.OpenFileDialog
		$OFD.Title  = 'Select a process executable to exclude'
		$OFD.Filter = 'Executable files (*.exe)|*.exe|All files (*.*)|*.*'
		if ($OFD.ShowDialog() -eq 'OK') { $Txt.Text = $OFD.FileName }
	})
	$Dlg.Controls.Add($BtnBrowse)

	$BtnRunning          = New-Object System.Windows.Forms.Button
	$BtnRunning.Text     = 'Running...'
	$BtnRunning.Location = New-Object System.Drawing.Point(450, 28)
	$BtnRunning.Size     = New-Object System.Drawing.Size(75, 25)
	$BtnRunning.Add_Click({
		$Picker                 = New-Object System.Windows.Forms.Form
		$Picker.Text            = 'Select Running Process'
		$Picker.Size            = New-Object System.Drawing.Size(340, 500)
		$Picker.StartPosition   = 'CenterParent'
		$Picker.FormBorderStyle = 'Sizable'
		$Picker.MinimumSize     = New-Object System.Drawing.Size(260, 300)

		$PnlTop          = New-Object System.Windows.Forms.Panel
		$PnlTop.Dock     = 'Top'
		$PnlTop.Height   = 32
		$PnlTop.Padding  = New-Object System.Windows.Forms.Padding(4, 4, 4, 0)

		$ProcFilter          = New-Object System.Windows.Forms.TextBox
		$ProcFilter.Dock     = 'Fill'
		$ProcFilter.Text     = ''
		$PnlTop.Controls.Add($ProcFilter)

		$LvPicker               = New-Object System.Windows.Forms.ListView
		$LvPicker.Dock          = 'Fill'
		$LvPicker.View          = 'Details'
		$LvPicker.FullRowSelect = $true
		$LvPicker.HeaderStyle   = 'None'
		$LvPicker.MultiSelect   = $false
		$LvPicker.Columns.Add('Process', -2) | Out-Null

		# Collect unique process names with .exe suffix
		$AllProcs = @(Get-Process | Select-Object -ExpandProperty Name -Unique | Sort-Object | ForEach-Object { "$($_).exe" })

		$ProcFilter.Add_TextChanged({
			$F = $ProcFilter.Text.Trim()
			$LvPicker.Items.Clear()
			$AllProcs | Where-Object { -not $F -or $_ -ilike "*$F*" } | ForEach-Object {
				$LvPicker.Items.Add((New-Object System.Windows.Forms.ListViewItem($_))) | Out-Null
			}
			if ($LvPicker.Items.Count -gt 0) { $LvPicker.Columns[0].Width = -2 }
		})

		# Initial population
		$AllProcs | ForEach-Object { $LvPicker.Items.Add((New-Object System.Windows.Forms.ListViewItem($_))) | Out-Null }
		if ($LvPicker.Items.Count -gt 0) { $LvPicker.Columns[0].Width = -2 }

		$LvPicker.Add_DoubleClick({
			if ($LvPicker.SelectedItems.Count -gt 0)
			{ $Txt.Text = $LvPicker.SelectedItems[0].Text; $Picker.Close() }
		})

		$PnlBot         = New-Object System.Windows.Forms.Panel
		$PnlBot.Dock    = 'Bottom'
		$PnlBot.Height  = 35

		$BtnSel          = New-Object System.Windows.Forms.Button
		$BtnSel.Text     = 'Select'
		$BtnSel.Size     = New-Object System.Drawing.Size(75, 25)
		$BtnSel.Location = New-Object System.Drawing.Point(4, 5)
		$BtnSel.Add_Click({
			if ($LvPicker.SelectedItems.Count -gt 0)
			{ $Txt.Text = $LvPicker.SelectedItems[0].Text; $Picker.Close() }
		})
		$PnlBot.Controls.Add($BtnSel)

		# Fill must be added first so WinForms lays out Top/Bottom panels before expanding Fill
		$Picker.Controls.Add($LvPicker)
		$Picker.Controls.Add($PnlTop)
		$Picker.Controls.Add($PnlBot)

		$Picker.ShowDialog($Dlg) | Out-Null
	})
	$Dlg.Controls.Add($BtnRunning)

	$BtnOK              = New-Object System.Windows.Forms.Button
	$BtnOK.Text         = 'OK'
	$BtnOK.DialogResult = 'OK'
	$BtnOK.Location     = New-Object System.Drawing.Point(450, 62)
	$BtnOK.Size         = New-Object System.Drawing.Size(70, 25)
	$Dlg.Controls.Add($BtnOK)
	$Dlg.AcceptButton   = $BtnOK

	$BtnCnl              = New-Object System.Windows.Forms.Button
	$BtnCnl.Text         = 'Cancel'
	$BtnCnl.DialogResult = 'Cancel'
	$BtnCnl.Location     = New-Object System.Drawing.Point(525, 62)
	$BtnCnl.Size         = New-Object System.Drawing.Size(75, 25)
	$Dlg.Controls.Add($BtnCnl)
	$Dlg.CancelButton    = $BtnCnl

	if ($Dlg.ShowDialog($Form) -eq 'OK' -and $Txt.Text.Trim()) { $Txt.Text.Trim() } else { $null }
}

function Show-SimpleTextDialog ([string]$Title, [string]$LabelText, [string]$Initial = '')
{
	$Dlg                 = New-Object System.Windows.Forms.Form
	$Dlg.Text            = $Title
	$Dlg.Size            = New-Object System.Drawing.Size(480, 125)
	$Dlg.StartPosition   = 'CenterParent'
	$Dlg.FormBorderStyle = 'FixedDialog'
	$Dlg.MaximizeBox     = $false
	$Dlg.MinimizeBox     = $false

	$Lbl          = New-Object System.Windows.Forms.Label
	$Lbl.Text     = $LabelText
	$Lbl.Location = New-Object System.Drawing.Point(10, 10)
	$Lbl.Size     = New-Object System.Drawing.Size(450, 18)
	$Dlg.Controls.Add($Lbl)

	$Txt          = New-Object System.Windows.Forms.TextBox
	$Txt.Text     = $Initial
	$Txt.Location = New-Object System.Drawing.Point(10, 30)
	$Txt.Size     = New-Object System.Drawing.Size(450, 22)
	$Dlg.Controls.Add($Txt)

	$BtnOK              = New-Object System.Windows.Forms.Button
	$BtnOK.Text         = 'OK'
	$BtnOK.DialogResult = 'OK'
	$BtnOK.Location     = New-Object System.Drawing.Point(295, 58)
	$BtnOK.Size         = New-Object System.Drawing.Size(70, 25)
	$Dlg.Controls.Add($BtnOK)
	$Dlg.AcceptButton   = $BtnOK

	$BtnCnl              = New-Object System.Windows.Forms.Button
	$BtnCnl.Text         = 'Cancel'
	$BtnCnl.DialogResult = 'Cancel'
	$BtnCnl.Location     = New-Object System.Drawing.Point(370, 58)
	$BtnCnl.Size         = New-Object System.Drawing.Size(70, 25)
	$Dlg.Controls.Add($BtnCnl)
	$Dlg.CancelButton    = $BtnCnl

	if ($Dlg.ShowDialog($Form) -eq 'OK' -and $Txt.Text.Trim()) { $Txt.Text.Trim() } else { $null }
}

# ---------------------------------------------------------------------------
# Validation functions
# ---------------------------------------------------------------------------

function Test-CDExclusionProcess ([string]$Value)
{
	if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
	# Disallowed characters (wildcards * and ? are permitted by Defender)
	if ($Value -match '[<>"|]') { return $false }
	# Colon only valid as drive separator at position 1
	$ColonIdx = $Value.IndexOf(':')
	if ($ColonIdx -eq 0 -or $ColonIdx -gt 1) { return $false }
	if ($ColonIdx -eq 1 -and $Value[0] -notmatch '[A-Za-z]') { return $false }
	# If it contains a backslash it must be an absolute path (drive or UNC)
	if ($Value.Contains('\'))
	{ return ($Value -match '^[A-Za-z]:\\' -or $Value -match '^\\\\') }
	# Bare process name - no forward slashes
	return (-not $Value.Contains('/'))
}

function Test-CDExclusionExtension ([string]$Value)
{
	if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
	# Optional leading dot then only valid extension characters - no path chars, wildcards, or spaces
	return ($Value -match '^\.?[^\s\\/:*?"<>|]+$')
}

function Test-CDExclusionPath ([string]$Value)
{
	if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
	# Disallowed characters (wildcards * and ? are permitted by Defender)
	if ($Value -match '[<>"|]') { return $false }
	# Colon is only valid as drive separator (must be exactly at position 1)
	$ColonIdx = $Value.IndexOf(':')
	if ($ColonIdx -gt 1) { return $false }          # colon after position 1
	if ($ColonIdx -eq 0) { return $false }           # leading colon
	if ($ColonIdx -eq 1 -and $Value[0] -notmatch '[A-Za-z]') { return $false }
	# Must be absolute: drive-letter path, UNC, or %EnvVar% prefix
	return ($Value -match '^[A-Za-z]:\\' -or $Value -match '^\\\\' -or $Value -match '^%[^%]+%\\')
}

function Test-CDIPAddress ([string]$Value)
{
	# Plain IPv4 or IPv6
	$Addr = $null
	if ([System.Net.IPAddress]::TryParse($Value, [ref]$Addr)) { return $true }
	# CIDR notation: x.x.x.x/n or ipv6addr/n
	if ($Value -match '^(.+)/(\d+)$')
	{
		$IpPart    = $Matches[1]
		$PrefixLen = [int]$Matches[2]
		if ([System.Net.IPAddress]::TryParse($IpPart, [ref]$Addr))
		{
			$MaxPrefix = if ($Addr.AddressFamily -eq 'InterNetwork') { 32 } else { 128 }
			return ($PrefixLen -ge 0 -and $PrefixLen -le $MaxPrefix)
		}
	}
	return $false
}
#endregion
