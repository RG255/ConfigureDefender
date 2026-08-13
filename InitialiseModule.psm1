#!/usr/bin/env powershell
#requires -Version 5.0
#
<#
	.SYNOPSIS
	Initialises the ConfigureDefender PowerShell module.

	.DESCRIPTION
	Follows the same pattern as the NamedPipe module initialisation.
	Loads variable definition files then dot-sources all *.ps1 function files
	from the Functions\ and FunctionsWindows\ directories.
	Export is controlled by $script:FunctionExportTable defined in DefineVariables.ps1.

	ConfigureDefender is Windows-only.  The module will throw if loaded on a
	non-Windows platform.

	.EXAMPLE
	Remove-Module ConfigureDefender -Force -ErrorAction SilentlyContinue
	Import-Module ConfigureDefender -RequiredVersion 0.3
#>
try
{
	Function Publish-CustomXML
	{
		ForEach ($Item in ($MyCustomXML.GetEnumerator() | Sort-Object -Property key).Name)
		{
			$XMLItem = (Join-Path -Path $ModuleScriptRoot -ChildPath ('Functions{0}\{1}' -f $Option, $MyCustomXML[$Item].file))
			If (Test-Path -Path $XMLItem)
			{
				Switch ($MyCustomXML[$Item].Action)
				{
					'Update-FormatData'
					{
						Switch ($MyCustomXML[$Item].Option)
						{
							'Prependpath' { Update-FormatData -PrependPath $XMLItem -ErrorAction Stop }
							'Appendpath'  { Update-FormatData -AppendPath  $XMLItem -ErrorAction Stop }
						}
					}
					Default
					{ 'Unknown item in MyCustomXML: [{0}] Option: [{1}]' -f $Item, $MyCustomXML[$Item].Option | Write-Warning }
				}
			}
		}
	}

	Function Initialize-Folders
	{
		[CmdletBinding()]
		Param (
			[Parameter(Mandatory, HelpMessage = 'A list of folders to create')]
			[Array]$Folders
		)
		foreach ($Item in $Folders)
		{
			$Path = Join-Path -Path $ModuleScriptRoot -ChildPath $Item
			If (-not (Test-Path -Path $Path))
			{ New-Item -Path $Path -ItemType Directory | Out-Null }
		}
	}

	Function Publish-Variables
	{
		Param ([hashtable]$Variables)
		Try
		{
			ForEach ($VarSet in ($Variables.GetEnumerator() | Sort-Object -Property key).Name)
			{
				ForEach ($Item in ($Variables[$VarSet].GetEnumerator() | Sort-Object -Property key).Name)
				{
					$Params = @{ Name = $Null; Value = $Null; Option = $Null; Scope = $Null }
					If (Test-Path -Path ('Variable:{0}:{1}' -f $Variables[$VarSet][$Item].Scope, $Item))
					{
						$Params = @{ Name = $Item; Scope = $Variables[$VarSet][$Item].Scope }
						If ($Params.Scope -inotmatch $VOConstant)
						{ Remove-Variable @Params -Force }
					}
					$Params = @{
						Name   = $Item
						Value  = $Variables[$VarSet][$Item].Value
						Option = $Variables[$VarSet][$Item].Option
						Scope  = $Variables[$VarSet][$Item].Scope
					}
					New-Variable @Params -ErrorAction Stop
					Export-ModuleMember -Variable $Item -ErrorAction Stop
					If ($VInfoOn)
					{ Write-Information -MessageData ('Variable:[{0}] created' -f $Item) -InformationAction Continue }
				}
			}
		}
		Catch
		{
			Write-Information -MessageData ('Variable:[{0}] failed to create' -f $Item) -InformationAction Continue
		}
	}

	Function Get-Psd1Data
	{
		[CmdletBinding()]
		Param (
			[Parameter(Mandatory)]
			[Microsoft.PowerShell.DesiredStateConfiguration.ArgumentToConfigurationDataTransformation()]
			[HashTable]$PathToPsd1file
		)
		$PathToPsd1file
	}

	Function Publish-MyEnvironment
	{
		[CmdletBinding()]
		Param (
			[ValidateSet('Windows', 'Linux', 'MacOS')]
			[String]$Option = ''
		)
		foreach ($Item in ($PSD1Data.PrivateData.ModuleVars[$Option].keys | Sort-Object))
		{
			$FilePath = Join-Path -Path $ModuleScriptRoot -ChildPath ('Functions{0}\{1}' -f $Option, $PSD1Data.PrivateData.ModuleVars[$Option][$Item]) -ErrorAction Stop
			If (Test-Path -Path $FilePath)
			{ . $FilePath }
		}
	}

	$Global:Error.clear()
	$ModuleScriptRoot = $PSScriptRoot
	$ModuleName       = (Split-Path -Path (Split-Path -Path $ModuleScriptRoot -Parent) -Leaf)
	$PSD1Path         = (Join-Path -Path $ModuleScriptRoot -ChildPath ('{0}.{1}' -f $ModuleName, 'psd1'))
	$PSD1Data         = Get-Psd1Data -PathToPsd1file ('{0}' -f $PSD1Path)
}
catch
{
	$NumberOfErrors = [int]$Global:Error.count
	$ErrorNumber    = $NumberOfErrors - 1
	'{1}{1}An error occurred while processing: [{0}]{1}{1}Message      : [{2}]{1}Command Path : [{3}]{1}Line No.     : [{4}]{1}Failing Line : [{5}]{1}{1}' -f `
		(Join-Path -Path $ModuleScriptRoot -ChildPath $PSD1Data.RootModule), "`r`n",
		($Global:Error[$ErrorNumber].Exception.Message).Replace("`r`n", ''),
		$Global:Error[$ErrorNumber].InvocationInfo.PSCommandPath,
		$Global:Error[$ErrorNumber].InvocationInfo.ScriptLineNumber,
		($Global:Error[$ErrorNumber].InvocationInfo.Line).Trim() | Write-Warning
	throw 'Unable to retrieve required data from: [{0}]' -f $PSD1Path
}

try
{
	# Ensure required folders exist
	Initialize-Folders -Folders 'Functions', 'FunctionsWindows'

	# Load common variable definitions (DefineVariables.ps1)
	Publish-MyEnvironment

	# Exclude variable definition files and zip archives from function loading
	$VarDefFiles = @($PSD1Data.PrivateData.ModuleVars[''].Values)
	$Exclude     = [regex]'(?i)DefineVariables|Define-CustomXML|\.zip$'

	# Dot-source and export common (cross-platform) functions
	$CommonFunctions = Get-ChildItem -Path (Join-Path -Path $ModuleScriptRoot -ChildPath 'Functions\*.ps1') -ErrorAction Stop |
		Where-Object { $_.Name -inotmatch $Exclude -and $_.Name -notin $VarDefFiles }

	foreach ($Item in $CommonFunctions)
	{
		. $Item.FullName
		if (-not (Get-Command $Item.BaseName -CommandType Function, Filter -ErrorAction SilentlyContinue))
		{ Write-Host "Function [$($Item.BaseName)] was NOT created by [$($Item.Name)]" }
		else
		{
			$funcName     = $Item.BaseName
			$shouldExport = $true
			if ($script:FunctionExportTable -and $script:FunctionExportTable.ContainsKey($funcName))
			{ $shouldExport = $script:FunctionExportTable[$funcName] }
			if ($shouldExport)
			{ Export-ModuleMember -Function $funcName -ErrorAction Stop }
		}
	}

	# OS-specific loading - ConfigureDefender is Windows-only
	switch ([System.Environment]::OSVersion.Platform.value__)
	{
		2   # Windows
		{
			# Load Windows-specific variable definitions
			Publish-MyEnvironment -Option 'Windows'

			$VarDefFilesW = @($PSD1Data.PrivateData.ModuleVars['Windows'].Values)
			$ExcludeW     = [regex]'(?i)DefineVariables|Define-CustomXML|\.zip$'

			$WindowsFunctions = Get-ChildItem -Path (Join-Path -Path $ModuleScriptRoot -ChildPath 'FunctionsWindows\*.ps1') -ErrorAction Stop |
				Where-Object { $_.Name -inotmatch $ExcludeW -and $_.Name -notin $VarDefFilesW }

			foreach ($Item in $WindowsFunctions)
			{
				. $Item.FullName
				if (-not (Get-Command $Item.BaseName -CommandType Function, Filter -ErrorAction SilentlyContinue))
				{ Write-Host "Function [$($Item.BaseName)] was NOT created by [$($Item.Name)]" }
				else
				{
					$funcName     = $Item.BaseName
					$shouldExport = $true
					if ($script:FunctionExportTable -and $script:FunctionExportTable.ContainsKey($funcName))
					{ $shouldExport = $script:FunctionExportTable[$funcName] }
					if ($shouldExport)
					{ Export-ModuleMember -Function $funcName -ErrorAction Stop }
				}
			}
		}
		default
		{ throw 'ConfigureDefender requires Windows.' }
	}

	if (-not $global:CDModuleMessageShown)
	{
		Write-Host 'ConfigureDefender loaded. To use run: Start-ConfigureDefenderGUI'
		$global:CDModuleMessageShown = $true
	}
}
catch
{
	$NumberOfErrors = [int]$Global:Error.count
	$ErrorNumber    = $NumberOfErrors - 1
	'{1}{1}An error occurred while processing: [{0}]{1}{1}Message      : [{2}]{1}Command Path : [{3}]{1}Line No.     : [{4}]{1}Failing Line : [{5}]{1}{1}' -f `
		(Join-Path -Path $ModuleScriptRoot -ChildPath $PSD1Data.RootModule), "`r`n",
		($Global:Error[$ErrorNumber].Exception.Message).Replace("`r`n", ''),
		$Global:Error[$ErrorNumber].InvocationInfo.PSCommandPath,
		$Global:Error[$ErrorNumber].InvocationInfo.ScriptLineNumber,
		($Global:Error[$ErrorNumber].InvocationInfo.Line).Trim() | Write-Warning
	throw 'Unable to initialise module: {0}' -f $ModuleName
}
