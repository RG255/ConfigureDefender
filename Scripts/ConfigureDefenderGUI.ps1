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
	  1. ASR Rules         - view and toggle rules; toolbar toggle reveals ASR Exclusions panel
	  2. Exclusions        - toolbar selects: ASR / Paths / Extensions / Processes / IPs
	  3. Controlled Folders- list / add / remove protected folders; toolbar toggle reveals Allowed Apps
	  4. Settings          - view and edit Defender settings incl. Network Protection & CFA State
	  5. Threat Actions    - set default action per threat severity level
	  6. Events            - view recent ASR and CFA events from the event log
	  7. History           - view threat detection history with filter and date range controls

	Source files (dot-sourced from this entry point)
	-------------------------------------------------
	  GUI-Helpers.ps1          - Shared dialog functions (Show-ExclPathDialog, etc.) and
	                             input validators (Test-CDExclusionPath, Test-CDIPAddress, etc.)
	  GUI-Tab-ASR.ps1          - Tab 1: ASR Rules + ASR Exclusions split panel
	  GUI-Tab-Exclusions.ps1   - Tab 2: unified Exclusions tab (ASR/Path/Ext/Proc/IP)
	  GUI-Tab-CFA.ps1          - Tab 3: Controlled Folders + Allowed Apps split panel
	  GUI-Tab-Settings.ps1     - Tab 4: Settings
	  GUI-Tab-ThreatEvents.ps1 - Tabs 5-6: Threat Actions + Events
	  GUI-Tab-History.ps1      - Tab 7: Threat Detection History

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
Import-Module ConfigureDefender -RequiredVersion 0.3 -Force -ErrorAction Stop
#endregion

#region Assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
#endregion

#region Helpers
function Get-CDSRP
{
	# Returns the SendRequestParams hashtable, opening the pipe session if needed.
	# Uses Get-CDSendRequestParams (a ConfigureDefender module function) rather than
	# $Mod.Invoke() because Invoke() does not reliably resolve $script: variables
	# from a scriptblock defined outside the module.
	$SRP = Get-CDSendRequestParams
	if (-not $SRP)
	{
		# Show a non-modal wait dialog - pipe open is slow (UAC + process start)
		$WaitDlg                 = New-Object System.Windows.Forms.Form
		$WaitDlg.Text            = 'Configure Defender'
		$WaitDlg.Size            = New-Object System.Drawing.Size(340, 90)
		$WaitDlg.StartPosition   = 'Manual'
		$WaitDlg.Location        = New-Object System.Drawing.Point(
			[int]($Form.Left + ($Form.Width  - 340) / 2),
			[int]($Form.Top  + ($Form.Height -  90) / 2)
		)
		$WaitDlg.FormBorderStyle = 'FixedDialog'
		$WaitDlg.MaximizeBox     = $false
		$WaitDlg.MinimizeBox     = $false
		$WaitDlg.ControlBox      = $false

		$WaitLbl           = New-Object System.Windows.Forms.Label
		$WaitLbl.Text      = 'Initialising...'
		$WaitLbl.Location  = New-Object System.Drawing.Point(10, 22)
		$WaitLbl.Size      = New-Object System.Drawing.Size(310, 22)
		$WaitLbl.TextAlign = 'MiddleCenter'
		$WaitDlg.Controls.Add($WaitLbl)

		$WaitDlg.Show($Form)
		[System.Windows.Forms.Application]::DoEvents()

		try
		{
			$StatusLabel.Text = 'Opening elevated session...'
			Open-CDPipeSession
			$SRP = Get-CDSendRequestParams
		}
		catch
		{
			throw
		}
		finally
		{
			$WaitDlg.Close()
			$WaitDlg.Dispose()
		}
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

function Show-CDHelp
{
	if ($script:HelpForm -and -not $script:HelpForm.IsDisposed)
	{
		$script:HelpForm.BringToFront()
		return
	}

	$script:HelpForm                 = New-Object System.Windows.Forms.Form
	$script:HelpForm.Text            = 'Configure Defender - Help'
	$script:HelpForm.Size            = New-Object System.Drawing.Size(520, 620)
	$script:HelpForm.MinimumSize     = New-Object System.Drawing.Size(400, 400)
	$script:HelpForm.FormBorderStyle = 'Sizable'
	$script:HelpForm.StartPosition   = 'Manual'

	# Position to the right of the main form; fall back to the left if off-screen
	$Screen   = [System.Windows.Forms.Screen]::FromControl($Form).WorkingArea
	$HelpLeft = $Form.Right + 10
	if ($HelpLeft + 520 -gt $Screen.Right) { $HelpLeft = [Math]::Max($Screen.Left, $Form.Left - 530) }
	$HelpTop  = [Math]::Max($Screen.Top, [Math]::Min($Form.Top, $Screen.Bottom - 620))
	$script:HelpForm.Location = New-Object System.Drawing.Point($HelpLeft, $HelpTop)

	$HelpRtb              = New-Object System.Windows.Forms.RichTextBox
	$HelpRtb.Dock         = 'Fill'
	$HelpRtb.ReadOnly     = $true
	$HelpRtb.BackColor    = [System.Drawing.SystemColors]::Window
	$HelpRtb.BorderStyle  = 'None'
	$HelpRtb.Font         = New-Object System.Drawing.Font('Segoe UI', 9)
	$HelpRtb.ScrollBars   = 'Vertical'
	$HelpRtb.Text         = @"
CONFIGURE DEFENDER - QUICK GUIDE
=================================

GENERAL
-------
The GUI connects to an elevated Defender management service via a named
pipe.  The first operation that requires administrative access will prompt
for UAC elevation; subsequent operations in the same session reuse the
elevated connection without further prompting.  Read (Refresh) operations
do not require elevation.

ASR RULES TAB
-------------
Lists all Attack Surface Reduction rules and their current action
(Blocked / Audit / Warn / Disabled).

  - Right-click one or more selected rules to change their action via
    the Set Action drop-down on the toolbar.
  - To manage ASR exclusions use the Exclusions tab (ASR category).
    ASR exclusions apply globally to all ASR rules.

EXCLUSIONS TAB
--------------
Manages Defender-wide exclusions grouped by category.

  - Click a category button (ASR / Paths / Extensions / Processes / IPs)
    to view and manage that exclusion type.  Each click fetches fresh
    data from Windows Defender.
  - Double-click an exclusion to edit it.
  - Use Remove Selected to delete one or more highlighted exclusions.

CONTROLLED FOLDERS (CFA) TAB
-----------------------------
Lists folders protected by Controlled Folder Access.

  - Use Add / Remove Selected to manage protected folders.
  - Click Allowed Apps [+] to show the Allowed Applications panel below.
  - The divider between the folders list and the apps panel can be
    dragged up or down to adjust the split.
  - In the Apps panel, double-click an app path to edit it.
  - Rm Missing removes entries whose application file no longer exists.

SETTINGS TAB
------------
Shows all configurable Windows Defender settings.

  - Double-click a setting row to change its value.
  - Changes take effect immediately via the elevated service.

THREAT ACTIONS TAB
------------------
Sets the default remediation action per threat severity level
(Low / Moderate / High / Severe).

  - Select one or more rows, then use Set Action to apply an action.

EVENTS TAB
----------
Displays recent ASR, CFA and Smart App Control (SAC) events. ASR/CFA come
from the Windows Defender log; SAC comes from the Code Integrity log.

  - Use the Filter combo to show All, ASR, CFA or SAC events.
  - Use the Since combo to limit results by date; choose Custom Date to
    pick a specific day. Note: SAC blocks only occur when a blocked app
    is launched, so the default "Since Boot" is often empty - widen it to
    Last 7 Days to see recent SAC blocks.
  - Select one ASR/CFA row, then click Add as Exclusion to add that file
    path as an exclusion. (SAC blocks cannot be fixed with an exclusion;
    they need the Smart App Control on/off toggle or a WDAC allow rule.)
  - Select a SAC row and click Details (or double-click it) to see the
    full block record - reason, SHA256, requested/validated signing level,
    signer, reputation and SAC policy. The dialog text is selectable and
    has Copy All / Copy SHA256 buttons.
  - "Why did an app PASS?" SAC only logs blocks by default; allow
    decisions live in the disabled CodeIntegrity/Verbose channel. To
    capture them, run Scripts\Trace-SmartAppControl.ps1 from an elevated
    PowerShell (it enables Verbose, captures, and disables it again).
    Then choose the SAC-Allow filter here and Refresh to see the allow
    decisions (green) with the validated signing level / reputation that
    earned trust - compare these against the red block rows.
"@
	$script:HelpForm.Controls.Add($HelpRtb)
	$script:HelpForm.Show($Form)
}
#endregion

#region Main Form
$Form                 = New-Object System.Windows.Forms.Form
$Form.Text            = 'Configure Defender  v0.3'
$Form.Size            = New-Object System.Drawing.Size(1080, 650)
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
$StatusLabel.Text      = 'Ready'
$StatusLabel.Spring    = $true
$StatusBar.Items.Add($StatusLabel) | Out-Null

$HelpStatusLbl            = New-Object System.Windows.Forms.ToolStripStatusLabel
$HelpStatusLbl.Text       = 'Help'
$HelpStatusLbl.Alignment  = 'Right'
$HelpStatusLbl.ForeColor  = [System.Drawing.Color]::Blue
$HelpStatusLbl.ToolTipText = 'Open Help window'
$HelpStatusLbl.Add_Click({ Show-CDHelp })
$StatusBar.Items.Add($HelpStatusLbl) | Out-Null

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

function Add-EmptyPlaceholder ([System.Windows.Forms.ListView]$Lv, [string]$Text = '(nothing configured)')
{
	if ($Lv.Items.Count -eq 0)
	{
		$Pi           = New-Object System.Windows.Forms.ListViewItem($Text)
		$Pi.ForeColor = [System.Drawing.Color]::Gray
		$Pi.Tag       = '$placeholder'
		$Lv.Items.Add($Pi) | Out-Null
	}
}
#endregion


# Shared helpers (dialogs + validators) - must be first
. "$PSScriptRoot\GUI-Helpers.ps1"

# Tab sections - Settings is first (leftmost, default tab)
. "$PSScriptRoot\GUI-Tab-Settings.ps1"
. "$PSScriptRoot\GUI-Tab-ASR.ps1"
. "$PSScriptRoot\GUI-Tab-Exclusions.ps1"
. "$PSScriptRoot\GUI-Tab-CFA.ps1"
. "$PSScriptRoot\GUI-Tab-ThreatEvents.ps1"
. "$PSScriptRoot\GUI-Tab-History.ps1"

#region Initial Load
$TabControl.Add_SelectedIndexChanged({
	$StatusLabel.Text = 'Loading...'
	$Form.UseWaitCursor = $true
	[System.Windows.Forms.Application]::DoEvents()
	try
	{
		switch ($TabControl.SelectedIndex)
		{
			0 { $TsBtnSettingsRefresh.PerformClick() }
			1 { $TsBtnRefresh.PerformClick() }
			2 {
				# Exclusions: update view from cache only - do not open the pipe until
				# the user explicitly clicks a category button or Refresh
				switch ($script:ExclCategory)
				{
					'ASR'  { Update-ExclASRView }
					'Proc' { Update-ExclProcView }
					'Path' { Update-ExclPathView }
					'Ext'  { Update-ExclExtView }
					'IP'   { Update-ExclIPView }
				}
			}
			3 { $TsBtnCFRefresh.PerformClick() }
			4 { $TsBtnThreatRefresh.PerformClick() }
			5 { $TsBtnEvRefresh.PerformClick() }
			6 { $TsBtnHistRefresh.PerformClick() }
		}
	}
	finally
	{
		$Form.UseWaitCursor = $false
		[System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::Default
	}
})
$Form.Add_Shown({ $TsBtnSettingsRefresh.PerformClick() })
#endregion

# Show the form
[System.Windows.Forms.Application]::Run($Form)
