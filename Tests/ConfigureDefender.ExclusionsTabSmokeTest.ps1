<#
	.SYNOPSIS
	Smoke test for the Exclusions tab: loads the REAL GUI-Helpers.ps1 and GUI-Tab-Exclusions.ps1 into a real (invisible) WinForms
	form, replaces only the elevated-server calls and the dialogs with stubs, and drives the tab the way the GUI does.

	.DESCRIPTION
	Unit tests cannot show that the loop-built list views, the category buttons and the event handlers are wired correctly, so this
	does. It checks what is SENT to the server and what the lists show for: loading each category, the literal filter, add,
	edit (the new entry must be added BEFORE the old one is removed, and nothing removed when the add fails), remove, the placeholder
	row, an empty list and a server error.

	Needs an interactive desktop (it creates a form for a moment) and nothing elevated; it never contacts Defender.
	It is NOT a Pester file on purpose. Run it under either host:
	  pwsh.exe -NoProfile -File .\ConfigureDefender.ExclusionsTabSmokeTest.ps1
	  powershell.exe -NoProfile -File .\ConfigureDefender.ExclusionsTabSmokeTest.ps1
	Exit code 0 = every check passed, 1 = a check failed.
#>$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $PSScriptRoot   # the module version folder this test sits in
Import-Module "$base\ConfigureDefender.psd1" -Force -WarningAction SilentlyContinue
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:Results = [System.Collections.Generic.List[string]]::new()
function Check ([string]$Name, [bool]$Ok, [string]$Detail = '') { $script:Results.Add(('{0}  {1}{2}' -f $(if ($Ok) { 'PASS' } else { 'FAIL' }), $Name, $(if (-not $Ok -and $Detail) { "   <- $Detail" } else { '' }))) }

# --- the little the main script provides ---
$Form = New-Object System.Windows.Forms.Form
$Form.Size = New-Object System.Drawing.Size(900, 500); $Form.Opacity = 0; $Form.ShowInTaskbar = $false
$StatusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$TabControl = New-Object System.Windows.Forms.TabControl; $TabControl.Dock = 'Fill'
$Form.Controls.Add($TabControl)
function New-Tab
{
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test stand-in that only builds an in-memory TabPage')]
	Param ([string]$Title)
	$Tab = New-Object System.Windows.Forms.TabPage; $Tab.Text = $Title; $TabControl.TabPages.Add($Tab); $Tab
}
function Add-EmptyPlaceholder ([System.Windows.Forms.ListView]$Lv, [string]$Text = '(nothing configured)')
{
	if ($Lv.Items.Count -eq 0) { $Pi = New-Object System.Windows.Forms.ListViewItem($Text); $Pi.Tag = '$placeholder'; $Lv.Items.Add($Pi) | Out-Null }
}
# --- server and dialogs replaced by stubs ---
$script:Sent = [System.Collections.Generic.List[string]]::new()
$script:Fake = @{}
$script:FakeError = $null
function Get-CDSRP { @{ DataObject = $null } }
function Send-Request { param([Parameter(ValueFromPipeline)]$In, $DataObject) process { $script:Sent.Add([string]$In); [PSCustomObject]@{ Error = $script:FakeError; Result = $script:Fake[[string]$In] } } }

. "$base\Scripts\GUI-Helpers.ps1"
$script:DialogAnswer = $null
function Show-ExclPathDialog ([string]$Title, [string]$Initial = '') { $script:DialogAnswer }
function Show-ExclProcessDialog ([string]$Title, [string]$Initial = '') { $script:DialogAnswer }
function Show-SimpleTextDialog ([string]$Title, [string]$Prompt, [string]$Initial = '') { $script:DialogAnswer }
# a real message box would block the harness: record the warning instead of showing it
$script:Warned = $null
function Confirm-ExclValue ([string]$Category, [string]$Value) { $pr = Get-ExclValidation -Category $Category -Value $Value; if ($null -eq $pr) { return $true }; $script:Warned = $pr.Title; return $false }
. "$base\Scripts\GUI-Tab-Exclusions.ps1"

$Form.Show(); [System.Windows.Forms.Application]::DoEvents()
try
{
	# ---- construction ----
	Check 'five category buttons built from the table, in order' ((@($script:ExclUi.Keys).Count -eq 5) -and (($script:ExclTypes.Keys | ForEach-Object { $script:ExclUi[$_].Btn.Text }) -join ',') -eq 'ASR,Paths,Extensions,Processes,IPs')
	Check 'five list views, none visible before a category is chosen' (@($script:ExclUi.Values | Where-Object { $_.Lv.Visible }).Count -eq 0)
	Check 'each list view carries its category in Tag' ((($script:ExclUi.Keys | Where-Object { $script:ExclUi[$_].Lv.Tag -ne $_ }).Count) -eq 0)
	Check 'action bar hidden until first load' (-not $TsBtnExclAdd.Visible)

	# ---- choosing a category loads it through the server ----
	$script:Fake['Get-CDExclusionPath'] = @('C:\Apps\Tool[1]\tool.exe', 'C:\Other\thing.exe', '\\server\share\x')
	$script:ExclUi['Path'].Btn.PerformClick(); [System.Windows.Forms.Application]::DoEvents()
	Check 'Paths button sent Get-CDExclusionPath' ($script:Sent[0] -eq 'Get-CDExclusionPath') ($script:Sent -join ' | ')
	Check 'Paths list view shows 3 entries' ($script:ExclUi['Path'].Lv.Items.Count -eq 3) ([string]$script:ExclUi['Path'].Lv.Items.Count)
	Check 'only the Paths list view is visible, and its button is checked' ((@($script:ExclUi.Values | Where-Object { $_.Lv.Visible }).Count -eq 1) -and $script:ExclUi['Path'].Lv.Visible -and $script:ExclUi['Path'].Btn.Checked -and -not $script:ExclUi['ASR'].Btn.Checked)
	Check 'status says loaded (3 entries)' ($StatusLabel.Text -eq 'Exclusion Paths loaded (3 entries).') $StatusLabel.Text
	Check 'action bar now visible' ($TsBtnExclAdd.Visible -and $TsBtnExclRemove.Visible -and $TsBtnExclRefresh.Visible)

	# ---- literal filter ----
	$ExclFilterBox.Text = 'tool[1'
	Check 'filter "tool[1" (a [ in the box) leaves 1 entry and does not error' (($script:ExclUi['Path'].Lv.Items.Count -eq 1) -and ($StatusLabel.Text -eq 'Exclusion Paths: 1 of 3 shown.')) ($StatusLabel.Text + ' / ' + $script:ExclUi['Path'].Lv.Items.Count)
	$ExclFilterBox.Text = ''
	Check 'clearing the filter shows all 3 again' ($script:ExclUi['Path'].Lv.Items.Count -eq 3)

	# ---- every category loads its own getter and shows only its own list ----
	foreach ($Cat in 'ASR', 'Ext', 'Proc', 'IP')
	{
		$Get = $script:ExclTypes[$Cat].Get
		$script:Fake[$Get] = @("$Cat-one", "$Cat-two")
		$script:Sent.Clear()
		$script:ExclUi[$Cat].Btn.PerformClick(); [System.Windows.Forms.Application]::DoEvents()
		Check "$Cat : sent $Get, shows 2 entries, is the only visible list" (($script:Sent[0] -eq $Get) -and ($script:ExclUi[$Cat].Lv.Items.Count -eq 2) -and (@($script:ExclUi.Values | Where-Object { $_.Lv.Visible }).Count -eq 1) -and $script:ExclUi[$Cat].Lv.Visible) (($script:Sent -join '|') + ' items=' + $script:ExclUi[$Cat].Lv.Items.Count)
	}

	# ---- empty list ----
	$script:Fake['Get-CDExclusionExtension'] = $null
	$script:ExclUi['Ext'].Btn.PerformClick(); [System.Windows.Forms.Application]::DoEvents()
	Check 'empty extension list shows one placeholder row' (($script:ExclUi['Ext'].Lv.Items.Count -eq 1) -and ($script:ExclUi['Ext'].Lv.Items[0].Tag -eq '$placeholder'))
	Check 'empty list updates the status instead of leaving "Loading..."' ($StatusLabel.Text -ne 'Loading...') $StatusLabel.Text

	# ---- add ----
	$script:Fake['Get-CDExclusionPath'] = @('C:\a\one')
	$script:ExclUi['Path'].Btn.PerformClick(); [System.Windows.Forms.Application]::DoEvents()
	$script:Sent.Clear(); $script:DialogAnswer = '\\nas\backup\*'
	$TsBtnExclAdd.PerformClick(); [System.Windows.Forms.Application]::DoEvents()
	Check 'Add sent the add command for the typed UNC path, then reloaded' (($script:Sent[0] -eq "Set-CDExclusionPath -Path '\\nas\backup\*' -Add") -and ($script:Sent[1] -eq 'Get-CDExclusionPath')) ($script:Sent -join ' | ')
	$script:Sent.Clear(); $script:DialogAnswer = 'relative\bad'
	$TsBtnExclAdd.PerformClick(); [System.Windows.Forms.Application]::DoEvents()
	Check 'Add with an invalid path sent nothing and warned' (($script:Sent.Count -eq 0) -and ($script:Warned -eq 'Invalid Path')) (($script:Sent -join ' | ') + ' warned=' + $script:Warned)

	# ---- edit (double-click path) ----
	$Lv = $script:ExclUi['Path'].Lv
	$Lv.Items[0].Selected = $true; $Lv.Items[0].Focused = $true
	$script:Sent.Clear(); $script:DialogAnswer = 'C:\a\renamed'
	Edit-ExclEntry 'Path'; [System.Windows.Forms.Application]::DoEvents()
	Check 'Edit sent Add(new) THEN Remove(old) THEN reload' (($script:Sent[0] -eq "Set-CDExclusionPath -Path 'C:\a\renamed' -Add") -and ($script:Sent[1] -eq "Set-CDExclusionPath -Path 'C:\a\one' -Remove") -and ($script:Sent[2] -eq 'Get-CDExclusionPath')) ($script:Sent -join ' | ')
	$script:Sent.Clear(); $script:FakeError = 'server said no'
	$Lv.Items[0].Selected = $true; $Lv.Items[0].Focused = $true
	$script:DialogAnswer = 'C:\a\other'
	Edit-ExclEntry 'Path'; [System.Windows.Forms.Application]::DoEvents()
	Check 'Edit whose Add fails sends NO remove (old entry kept)' (($script:Sent.Count -eq 1) -and ($script:Sent[0] -like "*-Add")) ($script:Sent -join ' | ')
	Check 'status says the old entry was left as it was' ($StatusLabel.Text -like '*old entry left as it was*') $StatusLabel.Text
	$script:FakeError = $null

	# ---- remove ----
	$script:Fake['Get-CDExclusionPath'] = @('C:\r\one', 'C:\r\two', 'C:\r\three')
	$script:ExclUi['Path'].Btn.PerformClick(); [System.Windows.Forms.Application]::DoEvents()
	$Lv = $script:ExclUi['Path'].Lv
	$Lv.Items[0].Selected = $true; $Lv.Items[2].Selected = $true
	$script:Sent.Clear()
	$TsBtnExclRemove.PerformClick(); [System.Windows.Forms.Application]::DoEvents()
	Check 'Remove Selected sent a remove for each selected entry, then reloaded' (($script:Sent[0] -eq "Set-CDExclusionPath -Path 'C:\r\one' -Remove") -and ($script:Sent[1] -eq "Set-CDExclusionPath -Path 'C:\r\three' -Remove") -and ($script:Sent[2] -eq 'Get-CDExclusionPath')) ($script:Sent -join ' | ')

	# ---- placeholder is never edited or removed ----
	$script:Fake['Get-CDExclusionPath'] = $null
	$script:ExclUi['Path'].Btn.PerformClick(); [System.Windows.Forms.Application]::DoEvents()
	$Lv = $script:ExclUi['Path'].Lv
	$Lv.Items[0].Selected = $true; $Lv.Items[0].Focused = $true
	$script:Sent.Clear(); $script:DialogAnswer = 'C:\x\y'
	$TsBtnExclRemove.PerformClick(); Edit-ExclEntry 'Path'; [System.Windows.Forms.Application]::DoEvents()
	Check 'neither Remove nor Edit acts on the placeholder row' ($script:Sent.Count -eq 0) ($script:Sent -join ' | ')

	# ---- a server error on load ----
	$script:FakeError = 'access denied'; $script:Sent.Clear()
	$script:ExclUi['IP'].Btn.PerformClick(); [System.Windows.Forms.Application]::DoEvents()
	Check 'a load error is shown on the status bar' ($StatusLabel.Text -like 'Error: access denied*') $StatusLabel.Text
	$script:FakeError = $null
}
catch { Check 'the test ran to the end' $false $_.Exception.Message; throw }
finally { $Form.Close(); $Form.Dispose() }
'Host ' + $PSVersionTable.PSVersion
$script:Results
$fails = @($script:Results | Where-Object { $_ -like 'FAIL*' }).Count
'{0} checks, {1} failed' -f $script:Results.Count, $fails
if ($fails -gt 0) { exit 1 }
