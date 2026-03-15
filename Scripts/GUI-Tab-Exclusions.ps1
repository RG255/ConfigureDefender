#region Tab 2 - Exclusions (ASR / Paths / Extensions / Processes / IPs)
# Dialog and validation functions are in GUI-Helpers.ps1 (dot-sourced before this file).
$TabExcl             = New-Tab 'Exclusions'
$script:ExclCategory = ''

# --- Toolbar ---
$ToolStripExcl      = New-Object System.Windows.Forms.ToolStrip
$ToolStripExcl.Dock = 'Top'

# Category buttons (order: ASR, Paths, Extensions, Processes, IPs)
$TsBtnExclCatASR               = New-Object System.Windows.Forms.ToolStripButton
$TsBtnExclCatASR.Text          = 'ASR'
$TsBtnExclCatASR.DisplayStyle  = 'Text'
$TsBtnExclCatASR.ToolTipText   = 'Show ASR-specific exclusions'
$ToolStripExcl.Items.Add($TsBtnExclCatASR) | Out-Null

$TsBtnExclCatPath              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnExclCatPath.Text         = 'Paths'
$TsBtnExclCatPath.DisplayStyle = 'Text'
$TsBtnExclCatPath.ToolTipText  = 'Show path exclusions'
$ToolStripExcl.Items.Add($TsBtnExclCatPath) | Out-Null

$TsBtnExclCatExt              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnExclCatExt.Text         = 'Extensions'
$TsBtnExclCatExt.DisplayStyle = 'Text'
$TsBtnExclCatExt.ToolTipText  = 'Show file extension exclusions'
$ToolStripExcl.Items.Add($TsBtnExclCatExt) | Out-Null

$TsBtnExclCatProc              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnExclCatProc.Text         = 'Processes'
$TsBtnExclCatProc.DisplayStyle = 'Text'
$TsBtnExclCatProc.ToolTipText  = 'Show process exclusions'
$ToolStripExcl.Items.Add($TsBtnExclCatProc) | Out-Null

$TsBtnExclCatIP              = New-Object System.Windows.Forms.ToolStripButton
$TsBtnExclCatIP.Text         = 'IPs'
$TsBtnExclCatIP.DisplayStyle = 'Text'
$TsBtnExclCatIP.ToolTipText  = 'Show IP address exclusions'
$ToolStripExcl.Items.Add($TsBtnExclCatIP) | Out-Null

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

# --- Panel hosting the 5 ListViews (only active one visible) ---
$PanelExcl      = New-Object System.Windows.Forms.Panel
$PanelExcl.Dock = 'Fill'

$LvExclASR               = New-Object System.Windows.Forms.ListView
$LvExclASR.Dock          = 'Fill'
$LvExclASR.View          = 'Details'
$LvExclASR.FullRowSelect = $true
$LvExclASR.GridLines     = $true
$LvExclASR.MultiSelect   = $true
$LvExclASR.Visible       = $false
$LvExclASR.Columns.Add('ASR Exclusion', 800) | Out-Null
$LvExclASR.Add_SizeChanged({
	$w = $LvExclASR.ClientSize.Width - 22
	if ($w -gt 100) { $LvExclASR.Columns[0].Width = $w }
})
$PanelExcl.Controls.Add($LvExclASR)

$LvProc               = New-Object System.Windows.Forms.ListView
$LvProc.Dock          = 'Fill'
$LvProc.View          = 'Details'
$LvProc.FullRowSelect = $true
$LvProc.GridLines     = $true
$LvProc.MultiSelect   = $true
$LvProc.Visible       = $false
$LvProc.Columns.Add('Process', 800) | Out-Null
$LvProc.Add_SizeChanged({
	$w = $LvProc.ClientSize.Width - 22
	if ($w -gt 100) { $LvProc.Columns[0].Width = $w }
})
$PanelExcl.Controls.Add($LvProc)

$LvPath               = New-Object System.Windows.Forms.ListView
$LvPath.Dock          = 'Fill'
$LvPath.View          = 'Details'
$LvPath.FullRowSelect = $true
$LvPath.GridLines     = $true
$LvPath.MultiSelect   = $true
$LvPath.Visible       = $false
$LvPath.Columns.Add('Path', 800) | Out-Null
$LvPath.Add_SizeChanged({
	$w = $LvPath.ClientSize.Width - 22
	if ($w -gt 100) { $LvPath.Columns[0].Width = $w }
})
$PanelExcl.Controls.Add($LvPath)

$LvExt               = New-Object System.Windows.Forms.ListView
$LvExt.Dock          = 'Fill'
$LvExt.View          = 'Details'
$LvExt.FullRowSelect = $true
$LvExt.GridLines     = $true
$LvExt.MultiSelect   = $true
$LvExt.Visible       = $false
$LvExt.Columns.Add('Extension', 800) | Out-Null
$LvExt.Add_SizeChanged({
	$w = $LvExt.ClientSize.Width - 22
	if ($w -gt 100) { $LvExt.Columns[0].Width = $w }
})
$PanelExcl.Controls.Add($LvExt)

$LvIP               = New-Object System.Windows.Forms.ListView
$LvIP.Dock          = 'Fill'
$LvIP.View          = 'Details'
$LvIP.FullRowSelect = $true
$LvIP.GridLines     = $true
$LvIP.MultiSelect   = $true
$LvIP.Visible       = $false
$LvIP.Columns.Add('IP Address', 800) | Out-Null
$LvIP.Add_SizeChanged({
	$w = $LvIP.ClientSize.Width - 22
	if ($w -gt 100) { $LvIP.Columns[0].Width = $w }
})
$PanelExcl.Controls.Add($LvIP)

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
	$script:ExclCategory      = $Cat
	$LblExclPrompt.Visible    = $false
	$LvExclASR.Visible        = ($Cat -eq 'ASR')
	$LvProc.Visible           = ($Cat -eq 'Proc')
	$LvPath.Visible           = ($Cat -eq 'Path')
	$LvExt.Visible            = ($Cat -eq 'Ext')
	$LvIP.Visible             = ($Cat -eq 'IP')
	$TsBtnExclCatASR.Checked  = ($Cat -eq 'ASR')
	$TsBtnExclCatProc.Checked = ($Cat -eq 'Proc')
	$TsBtnExclCatPath.Checked = ($Cat -eq 'Path')
	$TsBtnExclCatExt.Checked  = ($Cat -eq 'Ext')
	$TsBtnExclCatIP.Checked   = ($Cat -eq 'IP')
	$ExclFilterBox.Clear()
	Invoke-ExclRefresh
}

$TsBtnExclCatASR.Add_Click({  Switch-ExclCategory 'ASR' })
$TsBtnExclCatProc.Add_Click({ Switch-ExclCategory 'Proc' })
$TsBtnExclCatPath.Add_Click({ Switch-ExclCategory 'Path' })
$TsBtnExclCatExt.Add_Click({  Switch-ExclCategory 'Ext' })
$TsBtnExclCatIP.Add_Click({   Switch-ExclCategory 'IP' })

function Show-ExclActionBar
{
	$SepExclActions.Visible  = $true
	$TsBtnExclRefresh.Visible = $true
	$TsBtnExclAdd.Visible     = $true
	$TsBtnExclRemove.Visible  = $true
	$SepExclFilter.Visible    = $true
	$LblExclFilter.Visible    = $true
	$ExclFilterHost.Visible   = $true
}

# --- Update / filter functions ---
function Update-ExclASRView
{
	$LvExclASR.Items.Clear()
	if ($null -eq $script:ASRExclCache) { Add-EmptyPlaceholder $LvExclASR '(nothing requested yet)'; return }
	if (-not $script:ASRExclCache) { Add-EmptyPlaceholder $LvExclASR; return }
	$Filter = $ExclFilterBox.Text.Trim()
	$ToShow = if ($Filter) { $script:ASRExclCache | Where-Object { $_ -ilike "*$Filter*" } } else { $script:ASRExclCache }
	foreach ($P in $ToShow)
	{ $LvExclASR.Items.Add((New-Object System.Windows.Forms.ListViewItem($P))) | Out-Null }
	$Count = @($ToShow).Count; $Total = $script:ASRExclCache.Count
	Add-EmptyPlaceholder $LvExclASR
	$StatusLabel.Text = if ($Filter) { "ASR Exclusions: $Count of $Total shown." } else { "ASR Exclusions loaded ($Total entries)." }
}

function Update-ExclProcView
{
	$LvProc.Items.Clear()
	if ($null -eq $script:ExclProcCache) { Add-EmptyPlaceholder $LvProc '(nothing requested yet)'; return }
	if (-not $script:ExclProcCache) { Add-EmptyPlaceholder $LvProc; return }
	$Filter = $ExclFilterBox.Text.Trim()
	$ToShow = if ($Filter) { $script:ExclProcCache | Where-Object { $_ -ilike "*$Filter*" } } else { $script:ExclProcCache }
	foreach ($P in $ToShow)
	{ $LvProc.Items.Add((New-Object System.Windows.Forms.ListViewItem($P))) | Out-Null }
	$Count = @($ToShow).Count; $Total = $script:ExclProcCache.Count
	Add-EmptyPlaceholder $LvProc
	$StatusLabel.Text = if ($Filter) { "Exclusion Processes: $Count of $Total shown." } else { "Exclusion Processes loaded ($Total entries)." }
}

function Update-ExclPathView
{
	$LvPath.Items.Clear()
	if ($null -eq $script:ExclPathCache) { Add-EmptyPlaceholder $LvPath '(nothing requested yet)'; return }
	if (-not $script:ExclPathCache) { Add-EmptyPlaceholder $LvPath; return }
	$Filter = $ExclFilterBox.Text.Trim()
	$ToShow = if ($Filter) { $script:ExclPathCache | Where-Object { $_ -ilike "*$Filter*" } } else { $script:ExclPathCache }
	foreach ($P in $ToShow)
	{ $LvPath.Items.Add((New-Object System.Windows.Forms.ListViewItem($P))) | Out-Null }
	$Count = @($ToShow).Count; $Total = $script:ExclPathCache.Count
	Add-EmptyPlaceholder $LvPath
	$StatusLabel.Text = if ($Filter) { "Exclusion Paths: $Count of $Total shown." } else { "Exclusion Paths loaded ($Total entries)." }
}

function Update-ExclExtView
{
	$LvExt.Items.Clear()
	if ($null -eq $script:ExclExtCache) { Add-EmptyPlaceholder $LvExt '(nothing requested yet)'; return }
	if (-not $script:ExclExtCache) { Add-EmptyPlaceholder $LvExt; return }
	$Filter = $ExclFilterBox.Text.Trim()
	$ToShow = if ($Filter) { $script:ExclExtCache | Where-Object { $_ -ilike "*$Filter*" } } else { $script:ExclExtCache }
	foreach ($E in $ToShow)
	{ $LvExt.Items.Add((New-Object System.Windows.Forms.ListViewItem($E))) | Out-Null }
	$Count = @($ToShow).Count; $Total = $script:ExclExtCache.Count
	Add-EmptyPlaceholder $LvExt
	$StatusLabel.Text = if ($Filter) { "Exclusion Extensions: $Count of $Total shown." } else { "Exclusion Extensions loaded ($Total entries)." }
}

function Update-ExclIPView
{
	$LvIP.Items.Clear()
	if ($null -eq $script:ExclIPCache) { Add-EmptyPlaceholder $LvIP '(nothing requested yet)'; return }
	if (-not $script:ExclIPCache) { Add-EmptyPlaceholder $LvIP; return }
	$Filter = $ExclFilterBox.Text.Trim()
	$ToShow = if ($Filter) { $script:ExclIPCache | Where-Object { $_ -ilike "*$Filter*" } } else { $script:ExclIPCache }
	foreach ($IP in $ToShow)
	{ $LvIP.Items.Add((New-Object System.Windows.Forms.ListViewItem($IP))) | Out-Null }
	$Count = @($ToShow).Count; $Total = $script:ExclIPCache.Count
	Add-EmptyPlaceholder $LvIP
	$StatusLabel.Text = if ($Filter) { "Exclusion IPs: $Count of $Total shown." } else { "Exclusion IPs loaded ($Total entries)." }
}

$ExclFilterBox.Add_TextChanged({
	switch ($script:ExclCategory)
	{
		'ASR'  { Update-ExclASRView }
		'Proc' { Update-ExclProcView }
		'Path' { Update-ExclPathView }
		'Ext'  { Update-ExclExtView }
		'IP'   { Update-ExclIPView }
	}
})

# --- Refresh ---
function Invoke-ExclRefresh
{
	if ($script:ExclRefreshing) { return }
	$script:ExclRefreshing = $true
	$StatusLabel.Text = 'Loading...'
	$Form.UseWaitCursor = $true
	[System.Windows.Forms.Application]::DoEvents()
	try
	{
		switch ($script:ExclCategory)
		{
			'ASR'  {
				# AttackSurfaceReductionOnlyExclusions requires elevation
				$SRP = Get-CDSRP
				$SRP.DataObject = 'Get-CDASRExclusions' | Send-Request @SRP -NoExitOnError
				if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error: $($SRP.DataObject.Error)"; return }
				$script:ASRExclCache = @($SRP.DataObject.Result)
				Update-ExclASRView
				Show-ExclActionBar
			}
			'Proc' {
				# ExclusionProcess requires elevation
				$SRP = Get-CDSRP
				$SRP.DataObject = 'Get-CDExclusionProcesses' | Send-Request @SRP -NoExitOnError
				if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error: $($SRP.DataObject.Error)"; return }
				$script:ExclProcCache = @($SRP.DataObject.Result)
				Update-ExclProcView
				Show-ExclActionBar
			}
			'Path' {
				$SRP = Get-CDSRP
				$SRP.DataObject = 'Get-CDExclusionPaths' | Send-Request @SRP -NoExitOnError
				if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error: $($SRP.DataObject.Error)"; return }
				$script:ExclPathCache = @($SRP.DataObject.Result)
				Update-ExclPathView
				Show-ExclActionBar
			}
			'Ext'  {
				$SRP = Get-CDSRP
				$SRP.DataObject = 'Get-CDExclusionExtensions' | Send-Request @SRP -NoExitOnError
				if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error: $($SRP.DataObject.Error)"; return }
				$script:ExclExtCache = @($SRP.DataObject.Result)
				Update-ExclExtView
				Show-ExclActionBar
			}
			'IP'   {
				$SRP = Get-CDSRP
				$SRP.DataObject = 'Get-CDExclusionIpAddresses' | Send-Request @SRP -NoExitOnError
				if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error: $($SRP.DataObject.Error)"; return }
				$script:ExclIPCache = @($SRP.DataObject.Result)
				Update-ExclIPView
				Show-ExclActionBar
			}
		}
	}
	catch { $StatusLabel.Text = 'Error loading exclusions: ' + $_.Exception.Message }
	finally
	{
		$script:ExclRefreshing = $false
		$Form.UseWaitCursor = $false
		[System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::Default
	}
}

$TsBtnExclRefresh.Add_Click({ Invoke-ExclRefresh })

# --- Add ---
$TsBtnExclAdd.Add_Click({
	$Val = switch ($script:ExclCategory)
	{
		'ASR'  { Show-ExclPathDialog 'Add ASR Exclusion' }
		'Proc' { Show-ExclProcessDialog 'Add Exclusion Process' }
		'Path' { Show-ExclPathDialog 'Add Exclusion Path' }
		'Ext'  { Show-SimpleTextDialog 'Add Exclusion Extension' 'File extension to exclude (e.g. .tmp or tmp):' }
		'IP'   { Show-SimpleTextDialog 'Add Exclusion IP Address' 'IP address to exclude (IPv4 or IPv6):' }
	}
	if ($Val)
	{
		if ($script:ExclCategory -eq 'ASR' -and -not (Test-CDExclusionPath $Val))
		{
			[System.Windows.Forms.MessageBox]::Show(
				"'$Val' is not a valid exclusion path.`n`nPath must be absolute and start with a drive letter (C:\), UNC path (\\server\share\), or environment variable (%APPDATA%\).`nInvalid characters: < > `" |",
				'Invalid Path', 'OK', 'Warning') | Out-Null
			return
		}
		if ($script:ExclCategory -eq 'Proc' -and -not (Test-CDExclusionProcess $Val))
		{
			[System.Windows.Forms.MessageBox]::Show(
				"'$Val' is not a valid process exclusion.`n`nEnter a bare process name (e.g. app.exe) or an absolute path (e.g. C:\Folder\app.exe or \\server\share\app.exe).`nInvalid characters: < > `" |",
				'Invalid Process', 'OK', 'Warning') | Out-Null
			return
		}
		if ($script:ExclCategory -eq 'Ext' -and -not (Test-CDExclusionExtension $Val))
		{
			[System.Windows.Forms.MessageBox]::Show(
				"'$Val' is not a valid file extension.`n`nEnter an extension with or without a leading dot (e.g. tmp or .tmp). No spaces, wildcards, or path characters.",
				'Invalid Extension', 'OK', 'Warning') | Out-Null
			return
		}
		if ($script:ExclCategory -eq 'Path' -and -not (Test-CDExclusionPath $Val))
		{
			[System.Windows.Forms.MessageBox]::Show(
				"'$Val' is not a valid exclusion path.`n`nPath must be absolute and start with a drive letter (C:\), UNC path (\\server\share\), or environment variable (%APPDATA%\).`nInvalid characters: < > `" |",
				'Invalid Path', 'OK', 'Warning') | Out-Null
			return
		}
		if ($script:ExclCategory -eq 'IP' -and -not (Test-CDIPAddress $Val))
		{
			[System.Windows.Forms.MessageBox]::Show("'$Val' is not a valid IP address or CIDR range (e.g. 192.168.1.1 or 10.0.0.0/8).", 'Invalid IP Address', 'OK', 'Warning') | Out-Null
			return
		}
		try
		{
			$SRP     = Get-CDSRP
			$Escaped = $Val -replace "'", "''"
			switch ($script:ExclCategory)
			{
				'ASR'  {
					$SRP.DataObject = "Set-CDASRExclusion -Path '$Escaped' -Add" | Send-Request @SRP -NoExitOnError
					if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" } else { $TsBtnExclRefresh.PerformClick() }
				}
				'Proc' {
					$SRP.DataObject = "Set-CDExclusionProcess -Process '$Escaped' -Add" | Send-Request @SRP -NoExitOnError
					if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" } else { $TsBtnExclRefresh.PerformClick() }
				}
				'Path' {
					$SRP.DataObject = "Set-CDExclusionPath -Path '$Escaped' -Add" | Send-Request @SRP -NoExitOnError
					if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" } else { $TsBtnExclRefresh.PerformClick() }
				}
				'Ext'  {
					$SRP.DataObject = "Set-CDExclusionExtension -Extension '$Escaped' -Add" | Send-Request @SRP -NoExitOnError
					if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" } else { $TsBtnExclRefresh.PerformClick() }
				}
				'IP'   {
					$SRP.DataObject = "Set-CDExclusionIpAddress -IpAddress '$Escaped' -Add" | Send-Request @SRP -NoExitOnError
					if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" } else { $TsBtnExclRefresh.PerformClick() }
				}
			}
		}
		catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
	}
})

# --- DoubleClick (edit) ---
$LvExclASR.Add_DoubleClick({
	$Li = $LvExclASR.FocusedItem
	if (-not $Li -or $Li.Tag -eq '$placeholder') { return }
	$OldVal = $Li.Text
	$NewVal = Show-ExclPathDialog 'Edit ASR Exclusion' $OldVal
	if ($NewVal -and $NewVal -ne $OldVal)
	{
		if (-not (Test-CDExclusionPath $NewVal))
		{
			[System.Windows.Forms.MessageBox]::Show(
				"'$NewVal' is not a valid exclusion path.`n`nPath must be absolute and start with a drive letter (C:\), UNC path (\\server\share\), or environment variable (%APPDATA%\).`nInvalid characters: < > `" |",
				'Invalid Path', 'OK', 'Warning') | Out-Null
			return
		}
		try
		{
			$SRP = Get-CDSRP; $EscOld = $OldVal -replace "'","''"; $EscNew = $NewVal -replace "'","''"
			$SRP.DataObject = "Set-CDASRExclusion -Path '$EscOld' -Remove" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error removing old path: $($SRP.DataObject.Error)"; return }
			$SRP.DataObject = "Set-CDASRExclusion -Path '$EscNew' -Add" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error adding new path: $($SRP.DataObject.Error)"; return }
			$TsBtnExclRefresh.PerformClick()
		}
		catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
	}
})

$LvProc.Add_DoubleClick({
	$Li = $LvProc.FocusedItem
	if (-not $Li -or $Li.Tag -eq '$placeholder') { return }
	$OldVal = $Li.Text
	$NewVal = Show-ExclProcessDialog 'Edit Exclusion Process' $OldVal
	if ($NewVal -and $NewVal -ne $OldVal)
	{
		if (-not (Test-CDExclusionProcess $NewVal))
		{
			[System.Windows.Forms.MessageBox]::Show(
				"'$NewVal' is not a valid process exclusion.`n`nEnter a bare process name (e.g. app.exe) or an absolute path (e.g. C:\Folder\app.exe or \\server\share\app.exe).`nInvalid characters: < > `" |",
				'Invalid Process', 'OK', 'Warning') | Out-Null
			return
		}
		try
		{
			$SRP = Get-CDSRP; $EscOld = $OldVal -replace "'","''"; $EscNew = $NewVal -replace "'","''"
			$SRP.DataObject = "Set-CDExclusionProcess -Process '$EscOld' -Remove" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error removing old entry: $($SRP.DataObject.Error)"; return }
			$SRP.DataObject = "Set-CDExclusionProcess -Process '$EscNew' -Add" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error adding new entry: $($SRP.DataObject.Error)"; return }
			$TsBtnExclRefresh.PerformClick()
		}
		catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
	}
})

$LvPath.Add_DoubleClick({
	$Li = $LvPath.FocusedItem
	if (-not $Li -or $Li.Tag -eq '$placeholder') { return }
	$OldVal = $Li.Text
	$NewVal = Show-ExclPathDialog 'Edit Exclusion Path' $OldVal
	if ($NewVal -and $NewVal -ne $OldVal)
	{
		if (-not (Test-CDExclusionPath $NewVal))
		{
			[System.Windows.Forms.MessageBox]::Show(
				"'$NewVal' is not a valid exclusion path.`n`nPath must be absolute and start with a drive letter (C:\), UNC path (\\server\share\), or environment variable (%APPDATA%\).`nInvalid characters: < > `" |",
				'Invalid Path', 'OK', 'Warning') | Out-Null
			return
		}
		try
		{
			$SRP = Get-CDSRP; $EscOld = $OldVal -replace "'","''"; $EscNew = $NewVal -replace "'","''"
			$SRP.DataObject = "Set-CDExclusionPath -Path '$EscOld' -Remove" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error removing old path: $($SRP.DataObject.Error)"; return }
			$SRP.DataObject = "Set-CDExclusionPath -Path '$EscNew' -Add" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error adding new path: $($SRP.DataObject.Error)"; return }
			$TsBtnExclRefresh.PerformClick()
		}
		catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
	}
})

$LvExt.Add_DoubleClick({
	$Li = $LvExt.FocusedItem
	if (-not $Li -or $Li.Tag -eq '$placeholder') { return }
	$OldVal = $Li.Text
	$NewVal = Show-SimpleTextDialog 'Edit Exclusion Extension' 'File extension to exclude (e.g. .tmp or tmp):' $OldVal
	if ($NewVal -and $NewVal -ne $OldVal)
	{
		if (-not (Test-CDExclusionExtension $NewVal))
		{
			[System.Windows.Forms.MessageBox]::Show(
				"'$NewVal' is not a valid file extension.`n`nEnter an extension with or without a leading dot (e.g. tmp or .tmp). No spaces, wildcards, or path characters.",
				'Invalid Extension', 'OK', 'Warning') | Out-Null
			return
		}
		try
		{
			$SRP = Get-CDSRP; $EscOld = $OldVal -replace "'","''"; $EscNew = $NewVal -replace "'","''"
			$SRP.DataObject = "Set-CDExclusionExtension -Extension '$EscOld' -Remove" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error removing old extension: $($SRP.DataObject.Error)"; return }
			$SRP.DataObject = "Set-CDExclusionExtension -Extension '$EscNew' -Add" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error adding new extension: $($SRP.DataObject.Error)"; return }
			$TsBtnExclRefresh.PerformClick()
		}
		catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
	}
})

$LvIP.Add_DoubleClick({
	$Li = $LvIP.FocusedItem
	if (-not $Li -or $Li.Tag -eq '$placeholder') { return }
	$OldVal = $Li.Text
	$NewVal = Show-SimpleTextDialog 'Edit Exclusion IP Address' 'IP address to exclude (IPv4 or IPv6):' $OldVal
	if ($NewVal -and $NewVal -ne $OldVal)
	{
		if (-not (Test-CDIPAddress $NewVal))
		{
			[System.Windows.Forms.MessageBox]::Show("'$NewVal' is not a valid IP address or CIDR range (e.g. 192.168.1.1 or 10.0.0.0/8).", 'Invalid IP Address', 'OK', 'Warning') | Out-Null
			return
		}
		try
		{
			$SRP = Get-CDSRP; $EscOld = $OldVal -replace "'","''"; $EscNew = $NewVal -replace "'","''"
			$SRP.DataObject = "Set-CDExclusionIpAddress -IpAddress '$EscOld' -Remove" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error removing old IP: $($SRP.DataObject.Error)"; return }
			$SRP.DataObject = "Set-CDExclusionIpAddress -IpAddress '$EscNew' -Add" | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error) { $StatusLabel.Text = "Error adding new IP: $($SRP.DataObject.Error)"; return }
			$TsBtnExclRefresh.PerformClick()
		}
		catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
	}
})

# --- Remove ---
$TsBtnExclRemove.Add_Click({
	$Lv = switch ($script:ExclCategory) { 'ASR' { $LvExclASR } 'Proc' { $LvProc } 'Path' { $LvPath } 'Ext' { $LvExt } 'IP' { $LvIP } }
	$Selected = @($Lv.SelectedItems | Where-Object { $_.Tag -ne '$placeholder' })
	if ($Selected.Count -eq 0) { $StatusLabel.Text = 'No items selected.'; return }
	try
	{
		$SRP = Get-CDSRP; $Ok = 0; $ErrCount = 0
		foreach ($Li in $Selected)
		{
			$Val = $Li.Text; $Escaped = $Val -replace "'", "''"
			$Cmd = switch ($script:ExclCategory)
			{
				'ASR'  { "Set-CDASRExclusion -Path '$Escaped' -Remove" }
				'Proc' { "Set-CDExclusionProcess -Process '$Escaped' -Remove" }
				'Path' { "Set-CDExclusionPath -Path '$Escaped' -Remove" }
				'Ext'  { "Set-CDExclusionExtension -Extension '$Escaped' -Remove" }
				'IP'   { "Set-CDExclusionIpAddress -IpAddress '$Escaped' -Remove" }
			}
			$SRP.DataObject = $Cmd | Send-Request @SRP -NoExitOnError
			if ($SRP.DataObject.Error) { $ErrCount++; $StatusLabel.Text = "Error: $($SRP.DataObject.Error)" }
			else { $Ok++ }
		}
		if ($ErrCount -gt 0) { $StatusLabel.Text = "Removed $Ok, $ErrCount error(s)." }
		if ($Ok -gt 0) { $TsBtnExclRefresh.PerformClick() }
	}
	catch { $StatusLabel.Text = 'Error: ' + $_.Exception.Message }
})
#endregion
