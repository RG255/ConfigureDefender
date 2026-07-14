#requires -Version 5.0
Function Set-CDSetting
{
	<#
		.SYNOPSIS
		Sets a single Defender preference setting by name.

		.DESCRIPTION
		Requires elevation - intended to run in the elevated NamedPipe server process.
		Uses Set-MpPreference with a dynamic parameter name so all settings can be
		changed via a single function.

		.PARAMETER Name
		The MpPreference property name (e.g. 'DisableRealtimeMonitoring').

		.PARAMETER Value
		The value to set. Pass $true/$false for Bool settings, an integer for Enum
		or Int settings.
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[string]$Name,

		[Parameter(Mandatory)]
		$Value
	)

	$Params = @{ $Name = $Value }
	Set-MpPreference @Params

	try
	{
		Write-EventLog -LogName Application -Source ConfigureDefender `
			-EventId 4001 -EntryType Information `
			-Message "Defender setting updated: $Name = $Value" -ErrorAction SilentlyContinue
	}
	catch
	{
	}
}
