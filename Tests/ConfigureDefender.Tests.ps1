#Requires -Modules Pester
<#
	.SYNOPSIS
	Pester tests for the ConfigureDefender module v0.1

	.DESCRIPTION
	Unit test suite for ConfigureDefender module v0.1 including:
	- Module import and manifest verification
	- Data structure verification (ASR rule table, bidirectional option lookups)
	- Get-CD* function behaviour with mocked Get-MpPreference
	- Set-CD* function behaviour with mocked Set/Add/Remove-MpPreference
	- Parameter validation

	Tests do NOT require Defender to be running and do NOT modify system configuration.
	All Defender cmdlets are mocked.

	.NOTES
	Version: 1.0 2026-03-11
	Run with: Invoke-Pester -Path .\ConfigureDefender.Tests.ps1 -Output Detailed
#>

BeforeAll {
	$Script:ModulePath = Split-Path -Parent $PSScriptRoot
	Remove-Module -Name ConfigureDefender -Force -ErrorAction SilentlyContinue
	Import-Module "$Script:ModulePath\ConfigureDefender.psd1" -Force

	# Shared mock MpPreference used across multiple test blocks
	$Script:MpPref = [PSCustomObject]@{
		AttackSurfaceReductionRules_Ids               = @('be9ba2d9-53ea-4cdc-84e5-9b1eeee46550')
		AttackSurfaceReductionRules_Actions           = @(1)  # Blocked
		EnableNetworkProtection                       = 2     # Audit
		EnableControlledFolderAccess                  = 1     # Enabled
		ControlledFolderAccessProtectedFolders        = @('C:\Users\Documents', 'C:\Users\Pictures')
		AttackSurfaceReductionOnlyExclusions          = @('C:\MyApp\', 'C:\Tools\helper.exe')
		ControlledFolderAccessAllowedApplications     = @('C:\Windows\notepad.exe', 'C:\fake\missing.exe')
	}
}

AfterAll {
	Remove-Module -Name ConfigureDefender -Force -ErrorAction SilentlyContinue
}

# ============================================================
Describe 'Module Import' {
	It 'Should import without errors' {
		Get-Module -Name ConfigureDefender | Should -Not -BeNullOrEmpty
	}

	It 'Should be version 0.1' {
		(Get-Module -Name ConfigureDefender).Version.ToString() | Should -Be '0.1'
	}

	It 'Should have the correct GUID' {
		(Get-Module -Name ConfigureDefender).Guid.ToString() | Should -Be 'b4ddb8e6-c93f-4879-9209-31f600ad2a36'
	}

	It 'Should export exactly the expected public functions' {
		$Expected = @(
			'Get-CDASRRules', 'Get-CDEvents', 'Get-CDControlledFolders',
			'Get-CDNetworkProtection', 'Get-CDControlledFolderAccess',
			'Get-CDASRExclusions', 'Get-CDExclusionProcesses',
			'Get-CDExclusionPaths', 'Get-CDExclusionExtensions',
			'Get-CDExclusionIpAddresses', 'Get-CDAllowedApplications',
			'Get-CDSettings', 'Get-CDThreatActions', 'Get-CDSendRequestParams',
			'Set-CDASRRule', 'Set-CDASRExclusion', 'Set-CDExclusionProcess',
			'Set-CDExclusionPath', 'Set-CDExclusionExtension',
			'Set-CDExclusionIpAddress', 'Set-CDSetting', 'Set-CDThreatAction',
			'Set-CDControlledFolder', 'Set-CDAllowedApplication',
			'Set-CDControlledFolderAccess', 'Set-CDNetworkProtection',
			'Open-CDPipeSession', 'Close-CDPipeSession', 'Start-ConfigureDefenderGUI'
		)
		$Exported = (Get-Module -Name ConfigureDefender).ExportedFunctions.Keys | Sort-Object
		Compare-Object -ReferenceObject ($Expected | Sort-Object) -DifferenceObject $Exported |
			Should -BeNullOrEmpty
	}
}

# ============================================================
Describe 'Data Structures' {
	It 'ASRRules should contain exactly 16 entries' {
		$Rules = (Get-Module ConfigureDefender).Invoke({ $script:ASRRules })
		$Rules.Count | Should -Be 16
	}

	It 'ASRRules keys should all be lowercase GUIDs' {
		$Rules = (Get-Module ConfigureDefender).Invoke({ $script:ASRRules })
		foreach ($Key in $Rules.Keys)
		{
			$Key | Should -Match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
		}
	}

	It 'ASRRules values should be non-empty strings' {
		$Rules = (Get-Module ConfigureDefender).Invoke({ $script:ASRRules })
		foreach ($Val in $Rules.Values)
		{
			$Val | Should -Not -BeNullOrEmpty
		}
	}

	It 'ASROptions: integer to string lookup' {
		$Opts = (Get-Module ConfigureDefender).Invoke({ $script:ASROptions })
		$Opts[0] | Should -Be 'Disabled'
		$Opts[1] | Should -Be 'Blocked'
		$Opts[2] | Should -Be 'Audit'
		$Opts[6] | Should -Be 'Warn'
	}

	It 'ASROptions: string to integer lookup (bidirectional)' {
		$Opts = (Get-Module ConfigureDefender).Invoke({ $script:ASROptions })
		$Opts['Disabled'] | Should -Be 0
		$Opts['Blocked']  | Should -Be 1
		$Opts['Audit']    | Should -Be 2
		$Opts['Warn']     | Should -Be 6
	}

	It 'NPOptions: integer to string lookup' {
		$Opts = (Get-Module ConfigureDefender).Invoke({ $script:NPOptions })
		$Opts[0] | Should -Be 'Disabled'
		$Opts[1] | Should -Be 'Enabled'
		$Opts[2] | Should -Be 'Audit'
	}

	It 'NPOptions: string to integer lookup (bidirectional)' {
		$Opts = (Get-Module ConfigureDefender).Invoke({ $script:NPOptions })
		$Opts['Disabled'] | Should -Be 0
		$Opts['Enabled']  | Should -Be 1
		$Opts['Audit']    | Should -Be 2
	}

	It 'ASREventID should be 1121' {
		(Get-Module ConfigureDefender).Invoke({ $script:ASREventID }) | Should -Be '1121'
	}

	It 'CFEventID should be 1123' {
		(Get-Module ConfigureDefender).Invoke({ $script:CFEventID }) | Should -Be '1123'
	}
}

# ============================================================
Describe 'Get-CDASRRules' {
	BeforeAll {
		Mock -ModuleName ConfigureDefender Get-MpPreference { return $Script:MpPref }
	}

	It 'Should return exactly 16 objects' {
		@(Get-CDASRRules).Count | Should -Be 16
	}

	It 'Each object should have GUID, Action, Description properties' {
		Get-CDASRRules | ForEach-Object {
			$_.PSObject.Properties.Name | Should -Contain 'GUID'
			$_.PSObject.Properties.Name | Should -Contain 'Action'
			$_.PSObject.Properties.Name | Should -Contain 'Description'
		}
	}

	It 'Configured rule with action 1 should return Blocked' {
		$Rule = Get-CDASRRules | Where-Object { $_.GUID -eq 'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550' }
		$Rule.Action | Should -Be 'Blocked'
	}

	It 'Unconfigured rules should return Not Set' {
		$Unconfigured = Get-CDASRRules | Where-Object { $_.GUID -ne 'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550' }
		$Unconfigured | ForEach-Object { $_.Action | Should -Be 'Not Set' }
	}

	It 'Should return Not Set for all rules when Ids is null' {
		Mock -ModuleName ConfigureDefender Get-MpPreference {
			return [PSCustomObject]@{
				AttackSurfaceReductionRules_Ids     = $null
				AttackSurfaceReductionRules_Actions = $null
			}
		}
		Get-CDASRRules | ForEach-Object { $_.Action | Should -Be 'Not Set' }
	}

	It 'Should return Unknown for an unrecognised action value' {
		Mock -ModuleName ConfigureDefender Get-MpPreference {
			return [PSCustomObject]@{
				AttackSurfaceReductionRules_Ids     = @('be9ba2d9-53ea-4cdc-84e5-9b1eeee46550')
				AttackSurfaceReductionRules_Actions = @(99)
			}
		}
		$Rule = Get-CDASRRules | Where-Object { $_.GUID -eq 'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550' }
		$Rule.Action | Should -Be 'Unknown (99)'
	}

	It 'Description should match the known rule table entry' {
		$Rule = Get-CDASRRules | Where-Object { $_.GUID -eq 'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550' }
		$Rule.Description | Should -Be 'Block executable content from email client and webmail'
	}
}

# ============================================================
Describe 'Get-CDNetworkProtection' {
	It 'Should return Value and Description properties' {
		Mock -ModuleName ConfigureDefender Get-MpPreference { return [PSCustomObject]@{ EnableNetworkProtection = 0 } }
		$Result = Get-CDNetworkProtection
		$Result.PSObject.Properties.Name | Should -Contain 'Value'
		$Result.PSObject.Properties.Name | Should -Contain 'Description'
	}

	It 'Value 0 -> Disabled' {
		Mock -ModuleName ConfigureDefender Get-MpPreference { return [PSCustomObject]@{ EnableNetworkProtection = 0 } }
		$Result = Get-CDNetworkProtection
		$Result.Value       | Should -Be 0
		$Result.Description | Should -Be 'Disabled'
	}

	It 'Value 1 -> Enabled' {
		Mock -ModuleName ConfigureDefender Get-MpPreference { return [PSCustomObject]@{ EnableNetworkProtection = 1 } }
		$Result = Get-CDNetworkProtection
		$Result.Value       | Should -Be 1
		$Result.Description | Should -Be 'Enabled'
	}

	It 'Value 2 -> Audit' {
		Mock -ModuleName ConfigureDefender Get-MpPreference { return [PSCustomObject]@{ EnableNetworkProtection = 2 } }
		$Result = Get-CDNetworkProtection
		$Result.Value       | Should -Be 2
		$Result.Description | Should -Be 'Audit'
	}

	It 'Unknown value -> Unknown description' {
		Mock -ModuleName ConfigureDefender Get-MpPreference { return [PSCustomObject]@{ EnableNetworkProtection = 7 } }
		(Get-CDNetworkProtection).Description | Should -Be 'Unknown (7)'
	}
}

# ============================================================
Describe 'Get-CDControlledFolderAccess' {
	It 'Should return Value, Enabled, and Description properties' {
		Mock -ModuleName ConfigureDefender Get-MpPreference { return [PSCustomObject]@{ EnableControlledFolderAccess = 0 } }
		$Result = Get-CDControlledFolderAccess
		$Result.PSObject.Properties.Name | Should -Contain 'Value'
		$Result.PSObject.Properties.Name | Should -Contain 'Enabled'
		$Result.PSObject.Properties.Name | Should -Contain 'Description'
	}

	It 'Value 0 -> Disabled, Enabled=$false' {
		Mock -ModuleName ConfigureDefender Get-MpPreference { return [PSCustomObject]@{ EnableControlledFolderAccess = 0 } }
		$Result = Get-CDControlledFolderAccess
		$Result.Value       | Should -Be 0
		$Result.Enabled     | Should -BeFalse
		$Result.Description | Should -Be 'Disabled'
	}

	It 'Value 1 -> Enabled, Enabled=$true' {
		Mock -ModuleName ConfigureDefender Get-MpPreference { return [PSCustomObject]@{ EnableControlledFolderAccess = 1 } }
		$Result = Get-CDControlledFolderAccess
		$Result.Value       | Should -Be 1
		$Result.Enabled     | Should -BeTrue
		$Result.Description | Should -Be 'Enabled'
	}

	It 'Value 2 -> Audit Mode, Enabled=$false' {
		Mock -ModuleName ConfigureDefender Get-MpPreference { return [PSCustomObject]@{ EnableControlledFolderAccess = 2 } }
		$Result = Get-CDControlledFolderAccess
		$Result.Value       | Should -Be 2
		$Result.Enabled     | Should -BeFalse
		$Result.Description | Should -Be 'Audit Mode'
	}

	It 'Value 3 -> Block Disk Modification, Enabled=$true' {
		Mock -ModuleName ConfigureDefender Get-MpPreference { return [PSCustomObject]@{ EnableControlledFolderAccess = 3 } }
		$Result = Get-CDControlledFolderAccess
		$Result.Value       | Should -Be 3
		$Result.Enabled     | Should -BeTrue
		$Result.Description | Should -Be 'Block Disk Modification'
	}

	It 'Value 4 -> Audit Disk Modification, Enabled=$false' {
		Mock -ModuleName ConfigureDefender Get-MpPreference { return [PSCustomObject]@{ EnableControlledFolderAccess = 4 } }
		$Result = Get-CDControlledFolderAccess
		$Result.Value       | Should -Be 4
		$Result.Enabled     | Should -BeFalse
		$Result.Description | Should -Be 'Audit Disk Modification'
	}
}

# ============================================================
Describe 'Get-CDControlledFolders' {
	BeforeAll {
		Mock -ModuleName ConfigureDefender Get-MpPreference { return $Script:MpPref }
	}

	It 'Should return all protected folders' {
		@(Get-CDControlledFolders).Count | Should -Be 2
	}

	It 'Like filter should narrow results' {
		$Result = Get-CDControlledFolders -Like 'Documents'
		@($Result).Count | Should -Be 1
		$Result          | Should -Be 'C:\Users\Documents'
	}

	It 'Like filter with no match should return empty' {
		@(Get-CDControlledFolders -Like 'NoMatch').Count | Should -Be 0
	}

	It 'Should return empty when list is null' {
		Mock -ModuleName ConfigureDefender Get-MpPreference {
			return [PSCustomObject]@{ ControlledFolderAccessProtectedFolders = $null }
		}
		Get-CDControlledFolders | Should -BeNullOrEmpty
	}
}

# ============================================================
Describe 'Get-CDASRExclusions' {
	BeforeAll {
		Mock -ModuleName ConfigureDefender Get-MpPreference { return $Script:MpPref }
	}

	It 'Should return all exclusion paths' {
		@(Get-CDASRExclusions).Count | Should -Be 2
	}

	It 'Like filter should narrow results' {
		$Result = Get-CDASRExclusions -Like 'MyApp'
		@($Result).Count | Should -Be 1
		$Result          | Should -Be 'C:\MyApp\'
	}

	It 'Like filter with no match should return empty' {
		@(Get-CDASRExclusions -Like 'NoMatch').Count | Should -Be 0
	}
}

# ============================================================
Describe 'Get-CDAllowedApplications' {
	BeforeAll {
		Mock -ModuleName ConfigureDefender Get-MpPreference { return $Script:MpPref }
		# notepad.exe exists; missing.exe does not
		Mock -ModuleName ConfigureDefender Test-Path {
			param([string]$Path)
			$Path -eq 'C:\Windows\notepad.exe'
		}
	}

	It 'Should return all allowed apps with no filter' {
		@(Get-CDAllowedApplications).Count | Should -Be 2
	}

	It 'Like filter should narrow results' {
		$Result = Get-CDAllowedApplications -Like 'notepad'
		@($Result).Count | Should -Be 1
		$Result          | Should -Be 'C:\Windows\notepad.exe'
	}

	It 'CheckMissing should return only paths that do not exist on disk' {
		$Result = Get-CDAllowedApplications -CheckMissing
		@($Result).Count | Should -Be 1
		$Result          | Should -Be 'C:\fake\missing.exe'
	}
}

# ============================================================
Describe 'Set-CDASRRule' {
	BeforeAll {
		Mock -ModuleName ConfigureDefender Add-MpPreference {}
		Mock -ModuleName ConfigureDefender Remove-MpPreference {}
		Mock -ModuleName ConfigureDefender Get-MpPreference {
			return [PSCustomObject]@{
				AttackSurfaceReductionRules_Ids     = @('be9ba2d9-53ea-4cdc-84e5-9b1eeee46550')
				AttackSurfaceReductionRules_Actions = @(1)
			}
		}
	}

	It 'Change: should call Add-MpPreference with correct GUID and numeric action' {
		Set-CDASRRule -GUID 'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550' -Action Blocked
		Should -Invoke Add-MpPreference -ModuleName ConfigureDefender -Times 1 -ParameterFilter {
			$AttackSurfaceReductionRules_Ids -eq 'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550' -and
			$AttackSurfaceReductionRules_Actions -eq 1
		}
	}

	It 'Add: should call Add-MpPreference' {
		Set-CDASRRule -GUID 'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550' -Action Audit -Add
		Should -Invoke Add-MpPreference -ModuleName ConfigureDefender -Times 1
	}

	It 'AddAll: should call Add-MpPreference once per rule (16 times)' {
		Set-CDASRRule -AddAll -Action Disabled
		Should -Invoke Add-MpPreference -ModuleName ConfigureDefender -Times 16
	}

	It 'Remove: should call Remove-MpPreference with the given GUID' {
		Set-CDASRRule -RemoveGUID 'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550'
		Should -Invoke Remove-MpPreference -ModuleName ConfigureDefender -Times 1 -ParameterFilter {
			$AttackSurfaceReductionRules_Ids -eq 'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550'
		}
	}

	It 'RemoveAll: should call Remove-MpPreference for each configured rule' {
		Set-CDASRRule -RemoveAll
		Should -Invoke Remove-MpPreference -ModuleName ConfigureDefender -Times 1
	}

	It 'Should reject an invalid Action value' {
		{ Set-CDASRRule -GUID 'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550' -Action 'Invalid' } |
			Should -Throw
	}
}

# ============================================================
Describe 'Set-CDControlledFolderAccess' {
	BeforeAll {
		Mock -ModuleName ConfigureDefender Set-MpPreference {}
	}

	It 'Enable should call Set-MpPreference with value 1' {
		Set-CDControlledFolderAccess -Enable
		Should -Invoke Set-MpPreference -ModuleName ConfigureDefender -Times 1 -ParameterFilter {
			$EnableControlledFolderAccess -eq 1
		}
	}

	It 'Audit should call Set-MpPreference with value 2' {
		Set-CDControlledFolderAccess -Audit
		Should -Invoke Set-MpPreference -ModuleName ConfigureDefender -Times 1 -ParameterFilter {
			$EnableControlledFolderAccess -eq 2
		}
	}

	It 'Disable should call Set-MpPreference with value 0' {
		Set-CDControlledFolderAccess -Disable
		Should -Invoke Set-MpPreference -ModuleName ConfigureDefender -Times 1 -ParameterFilter {
			$EnableControlledFolderAccess -eq 0
		}
	}
}

# ============================================================
Describe 'Set-CDNetworkProtection' {
	BeforeAll {
		Mock -ModuleName ConfigureDefender Set-MpPreference {}
	}

	It 'Enable should call Set-MpPreference with value 1' {
		Set-CDNetworkProtection -Enable
		Should -Invoke Set-MpPreference -ModuleName ConfigureDefender -Times 1 -ParameterFilter {
			$EnableNetworkProtection -eq 1
		}
	}

	It 'Audit should call Set-MpPreference with value 2' {
		Set-CDNetworkProtection -Audit
		Should -Invoke Set-MpPreference -ModuleName ConfigureDefender -Times 1 -ParameterFilter {
			$EnableNetworkProtection -eq 2
		}
	}

	It 'Disable should call Set-MpPreference with value 0' {
		Set-CDNetworkProtection -Disable
		Should -Invoke Set-MpPreference -ModuleName ConfigureDefender -Times 1 -ParameterFilter {
			$EnableNetworkProtection -eq 0
		}
	}
}

# ============================================================
Describe 'Set-CDASRExclusion' {
	BeforeAll {
		Mock -ModuleName ConfigureDefender Add-MpPreference {}
		Mock -ModuleName ConfigureDefender Remove-MpPreference {}
	}

	It 'Add should call Add-MpPreference with the path' {
		Set-CDASRExclusion -Path 'C:\MyApp\'
		Should -Invoke Add-MpPreference -ModuleName ConfigureDefender -Times 1 -ParameterFilter {
			$AttackSurfaceReductionOnlyExclusions -eq 'C:\MyApp\'
		}
	}

	It 'Remove should call Remove-MpPreference with the path' {
		Set-CDASRExclusion -Path 'C:\MyApp\' -Remove
		Should -Invoke Remove-MpPreference -ModuleName ConfigureDefender -Times 1 -ParameterFilter {
			$AttackSurfaceReductionOnlyExclusions -eq 'C:\MyApp\'
		}
	}
}

# ============================================================
Describe 'Set-CDControlledFolder' {
	BeforeAll {
		Mock -ModuleName ConfigureDefender Add-MpPreference {}
		Mock -ModuleName ConfigureDefender Remove-MpPreference {}
	}

	It 'Add should call Add-MpPreference with the folder' {
		Set-CDControlledFolder -Folder 'C:\MyData'
		Should -Invoke Add-MpPreference -ModuleName ConfigureDefender -Times 1 -ParameterFilter {
			$ControlledFolderAccessProtectedFolders -eq 'C:\MyData'
		}
	}

	It 'Remove should call Remove-MpPreference with the folder' {
		Set-CDControlledFolder -Folder 'C:\MyData' -Remove
		Should -Invoke Remove-MpPreference -ModuleName ConfigureDefender -Times 1 -ParameterFilter {
			$ControlledFolderAccessProtectedFolders -eq 'C:\MyData'
		}
	}
}

# ============================================================
Describe 'Set-CDAllowedApplication' {
	BeforeAll {
		Mock -ModuleName ConfigureDefender Add-MpPreference {}
		Mock -ModuleName ConfigureDefender Remove-MpPreference {}
		Mock -ModuleName ConfigureDefender Get-MpPreference {
			return [PSCustomObject]@{
				ControlledFolderAccessAllowedApplications = @('C:\Windows\notepad.exe', 'C:\fake\gone.exe')
			}
		}
		Mock -ModuleName ConfigureDefender Test-Path {
			param([string]$Path)
			$Path -eq 'C:\Windows\notepad.exe'
		}
	}

	It 'Add should call Add-MpPreference with the path' {
		Set-CDAllowedApplication -Path 'C:\MyApp\app.exe'
		Should -Invoke Add-MpPreference -ModuleName ConfigureDefender -Times 1 -ParameterFilter {
			$ControlledFolderAccessAllowedApplications -eq 'C:\MyApp\app.exe'
		}
	}

	It 'Remove should call Remove-MpPreference with the path' {
		Set-CDAllowedApplication -Path 'C:\MyApp\app.exe' -Remove
		Should -Invoke Remove-MpPreference -ModuleName ConfigureDefender -Times 1 -ParameterFilter {
			$ControlledFolderAccessAllowedApplications -eq 'C:\MyApp\app.exe'
		}
	}

	It 'RemoveMissing should call Remove-MpPreference only for paths that do not exist' {
		Set-CDAllowedApplication -RemoveMissing
		Should -Invoke Remove-MpPreference -ModuleName ConfigureDefender -Times 1 -ParameterFilter {
			$ControlledFolderAccessAllowedApplications -eq 'C:\fake\gone.exe'
		}
	}
}

# ============================================================
Describe 'Parameter Validation' {
	It 'Get-CDEvents -Filter only accepts All, ASR, CFA' {
		{ Get-CDEvents -Filter 'Invalid' } | Should -Throw
	}

	It 'Set-CDASRRule -Action only accepts Disabled, Audit, Blocked, Warn' {
		{ Set-CDASRRule -GUID 'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550' -Action 'NotValid' } |
			Should -Throw
	}

	It 'Get-CDAllowedApplications Like and CheckMissing are mutually exclusive parameter sets' {
		{ Get-CDAllowedApplications -Like 'foo' -CheckMissing } | Should -Throw
	}
}
