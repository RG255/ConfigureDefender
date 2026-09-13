function Start-ConfigureDefenderGUI
{
	<#
	.SYNOPSIS
	Launches the ConfigureDefender graphical interface.

	.DESCRIPTION
	Resolves the GUI entry point from the module's installed location and
	runs it, ensuring all dot-sourced tab files are loaded from the same
	deployed module directory rather than any development source tree.

	.PARAMETER EnableCatchAudit
	2026-08-20, user-requested: shorthand for calling Enable-MyCatchAudit first, so a single command
	launches the GUI with catch auditing already on for this process - see Write-MyCatchAudit /
	Enable-MyCatchAudit for what that means. Only covers catches that fire in THIS (GUI) process; the
	elevated NamedPipe server Set-CDSetting/Set-CDCIVerbose run in is a SEPARATE process that inherits
	the setting when it spawns (on first admin operation from the GUI), but has no visible console of
	its own to show the resulting Write-Warning output.

	Auto-disables when the GUI window closes, so the switch does not leak into the rest of the console
	session it was launched from - the GUI's own FormClosing handler checks whether THIS call is what
	turned it on (not a separate manual Enable-MyCatchAudit made before launching) and only disables in
	that case, so a deliberately-started longer diagnostic session spanning multiple GUI launches is
	left alone.

	.EXAMPLE
	Start-ConfigureDefenderGUI -EnableCatchAudit
	Launches the GUI with catch auditing on; auto-disables again when the GUI window is closed.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
		Justification = 'Launching the GUI window is the explicit purpose of this function - there is no state to confirm before doing the one thing it does.')]
	[CmdletBinding()]
	Param ([Switch]$EnableCatchAudit)

	If ($EnableCatchAudit)
	{
		$null = Enable-MyCatchAudit
		$env:CDCatchAuditAutoDisable = '1'
	}

	$ModuleBase = $MyInvocation.MyCommand.Module.ModuleBase
	& "$ModuleBase\Scripts\ConfigureDefenderGUI.ps1"
}
