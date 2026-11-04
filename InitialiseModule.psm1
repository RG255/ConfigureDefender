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
	Import-Module ConfigureDefender -RequiredVersion 0.4
#>
try
{
	Function Initialize-Folder
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

	Function Publish-Variable
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
						{ Remove-Variable @Params -Force -WhatIf:$false }
					}
					$Params = @{
						Name   = $Item
						Value  = $Variables[$VarSet][$Item].Value
						Option = $Variables[$VarSet][$Item].Option
						Scope  = $Variables[$VarSet][$Item].Scope
					}
					# -WhatIf:$false on BOTH this and the Remove-Variable above (2026-09-27; same defect found
					# live in NamedPipe 0.15 and fixed across every live module the same day). New-Variable and
					# Remove-Variable honour ShouldProcess, so they inherit $WhatIfPreference - which is set for
					# the WHOLE SCOPE, including everything downstream, as soon as any caller runs a
					# SupportsShouldProcess script with -WhatIf. The module then IMPORTS BUT DOES NOT
					# INITIALISE: every variable skipped, Export-ModuleMember throwing on each missing one, and
					# the failure finally surfacing as a bogus "X is not recognized" - a half-loaded module
					# masquerading as a missing function.
					#
					# Creating a module's OWN internal variables at import time is not a user-visible state
					# change that -WhatIf should ever preview.
					New-Variable @Params -ErrorAction Stop -WhatIf:$false
					Export-ModuleMember -Variable $Item -ErrorAction Stop
					If ($VInfoOn)
					{ Write-Information -MessageData ('Variable:[{0}] created' -f $Item) -InformationAction Continue }
				}
			}
		}
		Catch
		{
			Write-Warning ('Variable:[{0}] failed to create: {1}' -f $Item, $_.Exception.Message)
			throw
		}
	}

	Function Get-Psd1Data
	{
		[CmdletBinding()]
		[OutputType([Hashtable])]
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
	$Err   = $_
	$Where = if ($PSD1Data -and $PSD1Data.RootModule) { Join-Path -Path $ModuleScriptRoot -ChildPath $PSD1Data.RootModule } else { $PSD1Path }
	'{1}{1}An error occurred while processing: [{0}]{1}{1}Message      : [{2}]{1}Command Path : [{3}]{1}Line No.     : [{4}]{1}Failing Line : [{5}]{1}{1}' -f `
		$Where, "`r`n",
		([string]$Err.Exception.Message).Replace("`r`n", ' '),
		$Err.InvocationInfo.PSCommandPath,
		$Err.InvocationInfo.ScriptLineNumber,
		([string]$Err.InvocationInfo.Line).Trim() | Write-Warning
	throw 'Unable to retrieve required data from: [{0}]' -f $PSD1Path
}

try
{
	# Ensure required folders exist
	Initialize-Folder -Folders 'Functions', 'FunctionsWindows'

	# Load common variable definitions (DefineVariables.ps1)
	Publish-MyEnvironment

	# Exclude variable definition files and zip archives from function loading
	$VarDefFiles = @($PSD1Data.PrivateData.ModuleVars[''].Values)
	$Exclude     = [regex]'(?i)DefineVariables|Define-CustomXML|\.zip$'

	# Dot-source and export common (cross-platform) functions. Vendored shared-utility copies
	# sit in their own 'vendored' subfolder (changed 2026-09-13) for filesystem
	# visibility - unioned in here so they still go through the same export-table logic below.
	$CommonFunctions = @(Get-ChildItem -Path (Join-Path -Path $ModuleScriptRoot -ChildPath 'Functions\*.ps1') -ErrorAction Stop) +
		@(Get-ChildItem -Path (Join-Path -Path $ModuleScriptRoot -ChildPath 'Functions\vendored\*.ps1') -ErrorAction SilentlyContinue) |
		Where-Object { $_.Name -inotmatch $Exclude -and $_.Name -notin $VarDefFiles }

	foreach ($Item in $CommonFunctions)
	{
		. $Item.FullName
		if (-not (Get-Command $Item.BaseName -CommandType Function, Filter -ErrorAction SilentlyContinue))
		{ Write-Warning "Function [$($Item.BaseName)] was NOT created by [$($Item.Name)]" }
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
				{ Write-Warning "Function [$($Item.BaseName)] was NOT created by [$($Item.Name)]" }
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
}
catch
{
	$Err   = $_
	$Where = if ($PSD1Data -and $PSD1Data.RootModule) { Join-Path -Path $ModuleScriptRoot -ChildPath $PSD1Data.RootModule } else { $PSD1Path }
	'{1}{1}An error occurred while processing: [{0}]{1}{1}Message      : [{2}]{1}Command Path : [{3}]{1}Line No.     : [{4}]{1}Failing Line : [{5}]{1}{1}' -f `
		$Where, "`r`n",
		([string]$Err.Exception.Message).Replace("`r`n", ' '),
		$Err.InvocationInfo.PSCommandPath,
		$Err.InvocationInfo.ScriptLineNumber,
		([string]$Err.InvocationInfo.Line).Trim() | Write-Warning
	throw 'Unable to initialise module: {0}' -f $ModuleName
}

# Catch-audit: surface any PERSISTED entries from a previous session/crash, once per process across
# every vendoring module (see Show-MyCatchAuditPendingNotice's own doc, 2026-09-10). Wrapped so a
# failure here can never turn into a module-import failure.
try { Show-MyCatchAuditPendingNotice } catch { Write-MyCatchAudit -Source 'InitialiseModule.psm1 (ConfigureDefender): module-init pending-catch-audit notice' -ErrorRecord $_ }
