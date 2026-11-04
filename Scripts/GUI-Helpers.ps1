#region Shared helpers - dialog functions and input validation
# Dot-sourced before all GUI-Tab-*.ps1 files so every tab can call these.

# ---------------------------------------------------------------------------
# Forwarders for module-INTERNAL functions that the GUI calls
# ---------------------------------------------------------------------------
# ConfigureDefenderGUI.ps1 removes and re-imports the module as its very first step, so everything in the GUI (this file, the
# tab scripts, every event handler) can see only the module's EXPORTED functions. Write-MyCatchAudit and Test-CDEntryMissing are
# internal. Calling them directly failed with "The term '...' is not recognized" - the Allowed Applications list showed it, and
# every GUI catch block that tried to audit would have failed the same way. The two functions below carry the SAME names and are
# defined in the GUI scope; they forward into the module's own scope, where the real ones live (inside that scope the module's
# function is found first, so there is no recursion). Call sites stay as they were, and the silent-failure sweep still sees a
# Write-MyCatchAudit call. A GUI script that needs another internal function needs a forwarder here too - a Pester test checks.

function Write-MyCatchAudit
{
	<#
		.SYNOPSIS
		GUI-scope forwarder to the module's internal Write-MyCatchAudit (same parameters).
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)][String]$Source,
		[Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord,
		[Switch]$Teardown
	)

	try
	{
		$Mod = Get-Module ConfigureDefender
		if (-not $Mod) { return }
		& $Mod { param($S, $E, $T) if ($T) { Write-MyCatchAudit -Source $S -ErrorRecord $E -Teardown } else { Write-MyCatchAudit -Source $S -ErrorRecord $E } } $Source $ErrorRecord ([bool]$Teardown)
	}
	catch
	{
		# The audit itself failed. Do not throw from a catch block's audit call; make it visible instead.
		Write-Warning ('Could not write to the catch audit: ' + $_.Exception.Message)
	}
}

function Test-CDEntryMissing
{
	<#
		.SYNOPSIS
		GUI-scope forwarder to the module's internal Test-CDEntryMissing (True only when the path is certainly gone).
	#>
	[CmdletBinding()]
	[OutputType([bool])]
	param([AllowEmptyString()][AllowNull()][string]$Entry)

	try
	{
		$Mod = Get-Module ConfigureDefender
		if (-not $Mod) { return $false }
		return [bool](& $Mod { param($E) Test-CDEntryMissing $E } $Entry)
	}
	catch
	{
		Write-MyCatchAudit -Source 'GUI Test-CDEntryMissing forwarder: asking the module whether a stored path is missing' -ErrorRecord $_
		return $false   # doubt never marks an entry as missing
	}
}

# ---------------------------------------------------------------------------
# Busy cursor: one place for what every load handler used to repeat
# ---------------------------------------------------------------------------
# Handlers call Enter-GuiBusy first and Exit-GuiBusy in their finally block (the try/catch/finally stays in the handler, so a
# return inside it behaves exactly as before). Two handlers used to forget to reset the real cursor; now none can.

function Enter-GuiBusy
{
	<#
		.SYNOPSIS
		Shows the busy cursor and a status message, and lets the window repaint before the slow work starts.
	#>
	[CmdletBinding()]
	param([string]$Text = 'Loading...')

	$StatusLabel.Text   = $Text
	$Form.UseWaitCursor = $true
	[System.Windows.Forms.Application]::DoEvents()
}

function Exit-GuiBusy
{
	<#
		.SYNOPSIS
		Puts the cursor back: clears the form's busy flag AND resets the live cursor (clearing only the flag can leave it spinning).
	#>
	[CmdletBinding()]
	param()

	$Form.UseWaitCursor = $false
	[System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::Default
}
# ---------------------------------------------------------------------------
# Quoting helper for command strings sent to the elevated server
# ---------------------------------------------------------------------------

function ConvertTo-CDEscapedArg
{
	<#
		.SYNOPSIS
		Escapes a value so it can sit between single quotes in a command string sent to the elevated server.

		.DESCRIPTION
		The server turns the request string into a script block. PowerShell treats U+2018, U+2019, U+201A and
		U+201B as single quotes as well as the ASCII apostrophe, so ALL of them are doubled here. Doubling only
		the ASCII one lets a path such as Bob(curly quote)s\app.exe end the quoted string early. Control
		characters are refused: no valid path, process name, extension or IP address contains one.

		.EXAMPLE
		$SRP.DataObject = ("Set-CDExclusionPath -Path '{0}' -Add" -f (ConvertTo-CDEscapedArg $Val)) | Send-Request @SRP
	#>
	[CmdletBinding()]
	[OutputType([string])]
	param([AllowEmptyString()][string]$Value)

	if ($Value -match '[\x00-\x1F]') { throw 'The value contains control characters and cannot be sent to the elevated server.' }
	[regex]::Replace($Value, "(['‘’‚‛])", '$1$1')
}

# ---------------------------------------------------------------------------
# Status bar text helper
# ---------------------------------------------------------------------------

function Get-CDStatusSummary
{
	<#
		.SYNOPSIS
		Reduces a status message to one short line that is safe to show in the status bar.

		.DESCRIPTION
		A request that fails on the server returns the whole error history as text (thousands of characters over
		more than a hundred lines). Put in the status bar as it stands, that text made the auto-sizing status strip
		taller than the window and covered the entire GUI. Short single-line text is returned unchanged. Anything
		else is cut down to the text before the first line break, followed by the most useful 'Message :' line of
		the error dump (the last one that is not a wrapper such as 'Exception calling ...'), on one line and at most
		MaxLength characters.

		.PARAMETER Text
		The message as assigned to the status label.

		.PARAMETER MaxLength
		Text up to this length on a single line is returned unchanged. Default 220 characters.

		.PARAMETER ShortenTo
		Longest result when the text does have to be shortened. Default is MaxLength. The GUI passes a smaller value
		so that a hint can be appended without running off the right-hand edge of the window.
	#>
	[CmdletBinding()]
	[OutputType([string])]
	param([AllowEmptyString()][AllowNull()][string]$Text, [int]$MaxLength = 220, [int]$ShortenTo = 0)

	if ([string]::IsNullOrEmpty($Text)) { return '' }
	if ($Text.Length -le $MaxLength -and $Text -notmatch "[\r\n]") { return $Text }
	if ($ShortenTo -le 0) { $ShortenTo = $MaxLength }

	$Lines  = @($Text -split "\r?\n")
	$Prefix = ($Lines[0]).Trim()

	$Cause = ''
	$Found = [regex]::Matches($Text, '(?ms)^\s*Message\s*:\s*(.*?)(?=^\s*(?:Command Path|Exception Type|Target Object|Full Error ID|Full Error Reason|Stack Trace|Line No\.|Offset|Line)\s*:|^\s*_{5,}|\z)')
	$Messages = @($Found | ForEach-Object { ($_.Groups[1].Value -replace '\s+', ' ').Trim() } | Where-Object { $_ })
	if ($Messages.Count -gt 0)
	{
		$Direct = @($Messages | Where-Object { $_ -notmatch '^Exception calling' })
		$Cause  = if ($Direct.Count -gt 0) { $Direct[-1] } else { $Messages[-1] }
	}
	else
	{
		$Next  = [string]($Lines | Select-Object -Skip 1 | Where-Object { $_.Trim() } | Select-Object -First 1)
		$Cause = ($Next -replace '\s+', ' ').Trim()
	}

	$Summary = (($Prefix, $Cause | Where-Object { $_ }) -join ' ').Trim()
	if ($Summary.Length -gt $ShortenTo) { $Summary = $Summary.Substring(0, $ShortenTo - 3) + '...' }
	$Summary
}

function Get-CDStatusDetail
{
	<#
		.SYNOPSIS
		Builds the hover text for a status message that had to be shortened: the caller's message and a numbered list
		of every error message in the dump.

		.DESCRIPTION
		The raw dump is hundreds of lines of stack traces, which as a tooltip would run off the screen. This keeps
		what is useful - each error's 'Message :' text, in order, one line each (cut at 400 characters), the whole
		thing capped at 3000 characters. The full dump is still printed to the console. Text with no 'Message :'
		lines is returned cut to 3000 characters.
	#>
	[CmdletBinding()]
	[OutputType([string])]
	param([AllowEmptyString()][AllowNull()][string]$Text)

	if ([string]::IsNullOrEmpty($Text)) { return '' }
	$Lines  = @($Text -split "\r?\n")
	$Found  = [regex]::Matches($Text, '(?ms)^\s*Message\s*:\s*(.*?)(?=^\s*(?:Command Path|Exception Type|Target Object|Full Error ID|Full Error Reason|Stack Trace|Line No\.|Offset|Line)\s*:|^\s*_{5,}|\z)')
	$Messages = @($Found | ForEach-Object { ($_.Groups[1].Value -replace '\s+', ' ').Trim() } | Where-Object { $_ })

	if ($Messages.Count -eq 0)
	{
		if ($Text.Length -gt 3000) { return $Text.Substring(0, 3000) }
		return $Text
	}

	$Out = [System.Collections.Generic.List[string]]::new()
	$Head = ($Lines[0]).Trim()
	if ($Head) { $Out.Add($Head) }
	$Out.Add('Errors reported (full dump is in the console):')
	$N = 0
	foreach ($M in $Messages)
	{
		$N++
		$One = if ($M.Length -gt 400) { $M.Substring(0, 397) + '...' } else { $M }
		$Out.Add(('{0}. {1}' -f $N, $One))
	}
	$Detail = $Out -join "`r`n"
	if ($Detail.Length -gt 3000) { $Detail = $Detail.Substring(0, 2997) + '...' }
	$Detail
}

# ---------------------------------------------------------------------------
# Setting comparison helper
# ---------------------------------------------------------------------------

function Test-CDSettingMatch
{
	<#
		.SYNOPSIS
		True when a value read back from Defender equals the value that was asked for.

		.DESCRIPTION
		Booleans compare as booleans, integers and enums as integers, anything else as text. A value that cannot be
		compared counts as a match, so an odd type never raises a false 'not applied' warning. (Set-CDSetting does the
		same check on the server side; the GUI repeats it on the re-read value so it never trusts what it typed.)
	#>
	[CmdletBinding()]
	[OutputType([bool])]
	param($Actual, $Wanted)

	try
	{
		if ($Wanted -is [bool])      { return ([bool]$Actual -eq $Wanted) }
		if ($Wanted -is [ValueType]) { return ([int64]$Actual -eq [int64]$Wanted) }
		return ([string]$Actual -eq [string]$Wanted)
	}
	catch { return $true }
}

# ---------------------------------------------------------------------------
# Path validation helper
# ---------------------------------------------------------------------------

function Test-ExclusionPath ([string]$Path)
{
	# One rule for every entry point (typed, edited, or picked with Browse): Test-CDExclusionPath. This used to be a
	# third, different rule set that rejected UNC paths and '?' wildcards the typed-in route accepts, and it set the
	# status bar from inside a modal dialog where nobody could see it.
	if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
	$Path = $Path.Trim()

	if ($Path.Length -gt 260)
	{
		[System.Windows.Forms.MessageBox]::Show("That path is too long (maximum 260 characters):`n`n$Path", 'Path too long', 'OK', 'Warning') | Out-Null
		return $false
	}
	if (-not (Test-CDExclusionPath $Path))
	{
		[System.Windows.Forms.MessageBox]::Show("'$Path' is not a valid exclusion path.`n`nPath must be absolute and start with a drive letter (C:\), UNC path (\\server\share\), or environment variable (%APPDATA%\).`nInvalid characters: < > `" |", 'Invalid Path', 'OK', 'Warning') | Out-Null
		return $false
	}

	return $true
}

# ---------------------------------------------------------------------------
# Error logging helper (sanitizes console, logs details)
# ---------------------------------------------------------------------------

function Write-OperationError ([string]$Operation, [object]$ErrorInfo)
{
	$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
	$logPath = Join-Path $env:TEMP "ConfigureDefender-$(Get-Date -Format 'yyyyMMdd').log"

	$logMessage = "$timestamp | $Operation | $($ErrorInfo.Exception.Message) | $($ErrorInfo.InvocationInfo.ScriptName):$($ErrorInfo.InvocationInfo.ScriptLineNumber)"
	Add-Content -LiteralPath $logPath -Value $logMessage -ErrorAction SilentlyContinue

	$StatusLabel.Text = "Operation failed. Details are in $logPath"
}

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
			$OfdOk = $false; $OfdName = $null
			try { $OfdOk = ($OFD.ShowDialog() -eq 'OK'); $OfdName = $OFD.FileName } finally { $OFD.Dispose() }
			if ($OfdOk) {
				$FileName = $OfdName
				if (Test-ExclusionPath -Path $FileName) {
					$Txt.Text = $FileName
				}
			}
		})
	$Dlg.Controls.Add($BtnFile)

	$BtnFolder          = New-Object System.Windows.Forms.Button
	$BtnFolder.Text     = 'Folder...'
	$BtnFolder.Location = New-Object System.Drawing.Point(415, 28)
	$BtnFolder.Size     = New-Object System.Drawing.Size(60, 25)
	$BtnFolder.Add_Click({
			$FBD             = New-Object System.Windows.Forms.FolderBrowserDialog
			$FBD.Description = 'Select a folder to exclude'
			$FbdOk = $false; $FbdPath = $null
			try { $FbdOk = ($FBD.ShowDialog() -eq 'OK'); $FbdPath = $FBD.SelectedPath } finally { $FBD.Dispose() }
			if ($FbdOk) {
				$FolderPath = $FbdPath
				if (Test-ExclusionPath -Path $FolderPath) {
					$Txt.Text = $FolderPath
				}
			}
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

	try
	{
		if ($Dlg.ShowDialog($Form) -eq 'OK' -and $Txt.Text.Trim())
		{ $Txt.Text.Trim() }
		else
		{ $null }
	}
	finally { $Dlg.Dispose() }
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
			try { if ($OFD.ShowDialog() -eq 'OK') { $Txt.Text = $OFD.FileName } } finally { $OFD.Dispose() }
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
					$AllProcs | Where-Object { -not $F -or ([string]$_).IndexOf($F, [StringComparison]::OrdinalIgnoreCase) -ge 0 } | ForEach-Object {
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

			try { $Picker.ShowDialog($Dlg) | Out-Null } finally { $Picker.Dispose() }
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

	try { if ($Dlg.ShowDialog($Form) -eq 'OK' -and $Txt.Text.Trim()) { $Txt.Text.Trim() } else { $null } } finally { $Dlg.Dispose() }
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

	try { if ($Dlg.ShowDialog($Form) -eq 'OK' -and $Txt.Text.Trim()) { $Txt.Text.Trim() } else { $null } } finally { $Dlg.Dispose() }
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
# ---------------------------------------------------------------------------
# Exclusions tab: one table describes every category (ASR / Paths / Extensions / Processes / IPs)
# ---------------------------------------------------------------------------
# The tab used to carry five copies of the same view, refresh, add, edit and remove code. Everything that differs between the
# categories is a row here; the logic below it is written once. Kind picks the dialog and the validator.
$script:ExclTypes = [ordered]@{
	ASR  = @{ Button = 'ASR';        Tip = 'Show ASR-specific exclusions';        Label = 'ASR Exclusions';       Column = 'ASR Exclusion'; Get = 'Get-CDASRExclusion';       Set = 'Set-CDASRExclusion';       Param = 'Path';      Kind = 'Path';      AddTitle = 'Add ASR Exclusion';            EditTitle = 'Edit ASR Exclusion' }
	Path = @{ Button = 'Paths';      Tip = 'Show path exclusions';                Label = 'Exclusion Paths';      Column = 'Path';          Get = 'Get-CDExclusionPath';      Set = 'Set-CDExclusionPath';      Param = 'Path';      Kind = 'Path';      AddTitle = 'Add Exclusion Path';           EditTitle = 'Edit Exclusion Path' }
	Ext  = @{ Button = 'Extensions'; Tip = 'Show file extension exclusions';      Label = 'Exclusion Extensions'; Column = 'Extension';     Get = 'Get-CDExclusionExtension'; Set = 'Set-CDExclusionExtension'; Param = 'Extension'; Kind = 'Extension'; AddTitle = 'Add Exclusion Extension';      EditTitle = 'Edit Exclusion Extension'; Prompt = 'File extension to exclude (e.g. .tmp or tmp):' }
	Proc = @{ Button = 'Processes';  Tip = 'Show process exclusions';             Label = 'Exclusion Processes';  Column = 'Process';       Get = 'Get-CDExclusionProcess';   Set = 'Set-CDExclusionProcess';   Param = 'Process';   Kind = 'Process';   AddTitle = 'Add Exclusion Process';        EditTitle = 'Edit Exclusion Process' }
	IP   = @{ Button = 'IPs';        Tip = 'Show IP address exclusions';          Label = 'Exclusion IPs';        Column = 'IP Address';    Get = 'Get-CDExclusionIpAddress'; Set = 'Set-CDExclusionIpAddress'; Param = 'IpAddress'; Kind = 'IP';        AddTitle = 'Add Exclusion IP Address';     EditTitle = 'Edit Exclusion IP Address'; Prompt = 'IP address to exclude (IPv4 or IPv6):' }
}

function Get-ExclCommand
{
	<#
		.SYNOPSIS
		Builds the command string sent to the elevated server to add or remove one exclusion entry.

		.DESCRIPTION
		The value is quoted with ConvertTo-CDEscapedArg, which doubles every character PowerShell treats as a single quote
		(including the curly ones) and refuses control characters.
	#>
	[CmdletBinding()]
	[OutputType([string])]
	param
	(
		[Parameter(Mandatory)][ValidateScript({ $script:ExclTypes.Contains($_) })][string]$Category,
		[Parameter(Mandatory)][string]$Value,
		[Parameter(Mandatory)][ValidateSet('Add', 'Remove')][string]$Verb
	)

	$Type = $script:ExclTypes[$Category]
	"{0} -{1} '{2}' -{3}" -f $Type.Set, $Type.Param, (ConvertTo-CDEscapedArg $Value), $Verb
}

function Get-ExclFiltered
{
	<#
		.SYNOPSIS
		The entries whose text contains the typed filter, compared literally and ignoring case.
	#>
	[CmdletBinding()]
	param($Items, [AllowEmptyString()][string]$Filter)

	if (-not $Filter) { return $Items }
	@($Items | Where-Object { ([string]$_).IndexOf($Filter, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 })
}

function Get-ExclValidation
{
	<#
		.SYNOPSIS
		$null when the value is acceptable for the category; otherwise an object with the Title and Message to show.
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)][ValidateScript({ $script:ExclTypes.Contains($_) })][string]$Category,
		[AllowEmptyString()][string]$Value
	)

	switch ($script:ExclTypes[$Category].Kind)
	{
		'Path'
		{
			if (-not (Test-CDExclusionPath $Value))
			{ return [PSCustomObject]@{ Title = 'Invalid Path'; Message = "'$Value' is not a valid exclusion path.`n`nPath must be absolute and start with a drive letter (C:\), UNC path (\\server\share\), or environment variable (%APPDATA%\).`nInvalid characters: < > `" |" } }
		}
		'Process'
		{
			if (-not (Test-CDExclusionProcess $Value))
			{ return [PSCustomObject]@{ Title = 'Invalid Process'; Message = "'$Value' is not a valid process exclusion.`n`nEnter a bare process name (e.g. app.exe) or an absolute path (e.g. C:\Folder\app.exe or \\server\share\app.exe).`nInvalid characters: < > `" |" } }
		}
		'Extension'
		{
			if (-not (Test-CDExclusionExtension $Value))
			{ return [PSCustomObject]@{ Title = 'Invalid Extension'; Message = "'$Value' is not a valid file extension.`n`nEnter an extension with or without a leading dot (e.g. tmp or .tmp). No spaces, wildcards, or path characters." } }
		}
		'IP'
		{
			if (-not (Test-CDIPAddress $Value))
			{ return [PSCustomObject]@{ Title = 'Invalid IP Address'; Message = "'$Value' is not a valid IP address or CIDR range (e.g. 192.168.1.1 or 10.0.0.0/8)." } }
		}
	}
	return $null
}

function Confirm-ExclValue
{
	<#
		.SYNOPSIS
		True when the value is valid for the category; otherwise shows why in a message box and returns False.
	#>
	[CmdletBinding()]
	[OutputType([bool])]
	param([Parameter(Mandatory)][string]$Category, [AllowEmptyString()][string]$Value)

	$Problem = Get-ExclValidation -Category $Category -Value $Value
	if ($null -eq $Problem) { return $true }
	[System.Windows.Forms.MessageBox]::Show($Problem.Message, $Problem.Title, 'OK', 'Warning') | Out-Null
	return $false
}

function Show-ExclDialog
{
	<#
		.SYNOPSIS
		Shows the add or edit dialog that suits the category and returns what was typed ($null if cancelled).
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)][string]$Category,
		[Parameter(Mandatory)][ValidateSet('Add', 'Edit')][string]$Mode,
		[string]$Initial = ''
	)

	$Type  = $script:ExclTypes[$Category]
	$Title = if ($Mode -eq 'Edit') { $Type.EditTitle } else { $Type.AddTitle }
	switch ($Type.Kind)
	{
		'Path'    { Show-ExclPathDialog $Title $Initial }
		'Process' { Show-ExclProcessDialog $Title $Initial }
		default   { Show-SimpleTextDialog $Title $Type.Prompt $Initial }
	}
}

#endregion
