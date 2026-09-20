#requires -Version 5.0
Function Set-CDExclusionIpAddress
{
	<#
		.SYNOPSIS
		Adds or removes an IP address exclusion from Defender scanning.

		.DESCRIPTION
		Requires elevation - intended to run in the elevated NamedPipe server process.
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

	try
	{
		switch ($PSCmdlet.ParameterSetName)
		{
			'Add'    { Add-MpPreference    -ExclusionIpAddress $IpAddress }
			'Remove' { Remove-MpPreference -ExclusionIpAddress $IpAddress }
		}
	}
	catch
	{
		Write-MyCatchAudit -Source 'Set-CDExclusionIpAddress: writing IP-address exclusion' -ErrorRecord $_
		throw
	}
}
