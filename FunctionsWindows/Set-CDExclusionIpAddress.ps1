#requires -Version 5.0
Function Set-CDExclusionIpAddress
{
	<#
		.SYNOPSIS
		Adds or removes an IP address exclusion from Defender scanning.

		.DESCRIPTION
		Requires elevation - intended to run in the elevated NamedPipe server process.
		Each successful change is recorded in the Application event log (source ConfigureDefender, event 4002 (IP-address exclusion added or removed)) with the names or paths involved, never a secret.
		Supports IPv4 and IPv6 addresses.

		.PARAMETER IpAddress
		The IP address to add or remove.

		.PARAMETER Add
		Add the IP address to the exclusion list.

		.PARAMETER Remove
		Remove the IP address from the exclusion list.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
		Justification = 'Set-CDExclusionIpAddress writes an IP-address exclusion - state change is the explicit purpose of this function.')]
	[CmdletBinding(DefaultParameterSetName = 'Add')]
	param
	(
		[Parameter(Mandatory)]
		[string]$IpAddress,

		[Parameter(ParameterSetName = 'Add')]
		[switch]$Add,

		[Parameter(ParameterSetName = 'Remove')]
		[switch]$Remove
	)

	If (1 -band ($env:MyFunctionTraceEnabled -as [Int])) { Write-MyFunctionTrace }

	$Verb = 'added'
	try
	{
		switch ($PSCmdlet.ParameterSetName)
		{
			'Add'    { Add-MpPreference    -ExclusionIpAddress $IpAddress }
			'Remove' { $Verb = 'removed'; Remove-MpPreference -ExclusionIpAddress $IpAddress }
		}
	}
	catch
	{
		Write-MyCatchAudit -Source 'Set-CDExclusionIpAddress: writing IP-address exclusion' -ErrorRecord $_
		throw
	}

	Write-CDAuditEvent -EventId 4002 -Message ("Defender IP-address exclusion {0}: {1}" -f $Verb, $IpAddress)
}
