#requires -Version 5.0
Function Get-CDControlledFolderAccess
{
	<#
		.SYNOPSIS
		Returns the current Controlled Folder Access state.

		.OUTPUTS
		PSCustomObject with properties:
		  Value   - Raw integer value (0=Disabled, 1=Enabled, 2=Audit, 3=BlockDiskModification, 4=AuditDiskModification)
		  Enabled - Boolean: true when Value is 1 or 3
	#>
	[CmdletBinding()]
	param()

	$Val = [int](Get-MpPreference).EnableControlledFolderAccess
	$Description = switch ($Val)
	{
		0 { 'Disabled' }
		1 { 'Enabled' }
		2 { 'Audit Mode' }
		3 { 'Block Disk Modification' }
		4 { 'Audit Disk Modification' }
		default { "Unknown ($Val)" }
	}
	[PSCustomObject][Ordered]@{
		Value       = $Val
		Enabled     = ($Val -eq 1 -or $Val -eq 3)
		Description = $Description
	}
}
