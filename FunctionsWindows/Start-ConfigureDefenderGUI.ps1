function Start-ConfigureDefenderGUI
{
	<#
	.SYNOPSIS
	Launches the ConfigureDefender graphical interface.

	.DESCRIPTION
	Resolves the GUI entry point from the module's installed location and
	runs it, ensuring all dot-sourced tab files are loaded from the same
	deployed module directory rather than any development source tree.
	#>
	$ModuleBase = $MyInvocation.MyCommand.Module.ModuleBase
	& "$ModuleBase\Scripts\ConfigureDefenderGUI.ps1"
}
