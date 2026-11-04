#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
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

	It 'Should be version 0.4' {
		(Get-Module -Name ConfigureDefender).Version.ToString() | Should -Be '0.4'
	}

	It 'Should have the correct GUID' {
		(Get-Module -Name ConfigureDefender).Guid.ToString() | Should -Be 'b4ddb8e6-c93f-4879-9209-31f600ad2a36'
	}

	It 'Should export exactly the expected public functions' {
		$Expected = @(
			'Get-CDASRRule', 'Get-CDEvent', 'Get-CDControlledFolder',
			'Get-CDNetworkProtection', 'Get-CDControlledFolderAccess',
			'Get-CDASRExclusion', 'Get-CDExclusionProcess',
			'Get-CDExclusionPath', 'Get-CDExclusionExtension',
			'Get-CDExclusionIpAddress', 'Get-CDAllowedApplication',
			'Get-CDSetting', 'Get-CDThreatAction', 'Get-CDThreatDetection', 'Get-CDSendRequestParam',
			'Set-CDASRRule', 'Set-CDASRExclusion', 'Set-CDExclusionProcess',
			'Set-CDExclusionPath', 'Set-CDExclusionExtension',
			'Set-CDExclusionIpAddress', 'Set-CDSetting', 'Set-CDThreatAction',
			'Set-CDControlledFolder', 'Set-CDAllowedApplication',
			'Set-CDControlledFolderAccess', 'Set-CDNetworkProtection', 'Set-CDCIVerbose',
			'Open-CDPipeSession', 'Close-CDPipeSession', 'Start-ConfigureDefenderGUI', 'Test-CDPipeSession',
			'Enable-MyCatchAudit', 'Disable-MyCatchAudit', 'Get-MyCatchAuditLog', 'Show-MyCatchAuditSummary',
			'Clear-MyCatchAuditLog', 'Invoke-MyCatchAuditTriage',
			'Clear-MyCatchAuditArchive', # 2026-09-16: archive-housekeeping addition (Invoke-FileManagement stays internal)
			'Enable-MyFunctionTrace', 'Disable-MyFunctionTrace', 'Clear-MyFunctionTraceLog', 'Clear-MyFunctionTraceArchive', # 2026-09-16: function-trace facility rollout
			'Protect-MyFunctionTraceFolder' # 2026-09-21: locks the trace folder ACL (or -Check); Enable-MyFunctionTrace warns when it is loose
		)
		$Exported = (Get-Module -Name ConfigureDefender).ExportedFunctions.Keys | Sort-Object
		Compare-Object -ReferenceObject ($Expected | Sort-Object) -DifferenceObject $Exported |
			Should -BeNullOrEmpty
	}
}

# ============================================================
Describe 'Data Structures' {
	It 'ASRRules should contain exactly 17 entries' {
		$Rules = (Get-Module ConfigureDefender).Invoke({ $script:ASRRules })
		$Rules.Count | Should -Be 17
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
Describe 'Get-CDThreatDetection' {
	# Regression (2026-09-21): [int]$ThreatID threw for any ID above [int]::MaxValue, and Defender's IDs do
	# exceed it (a real detection had ID 2147725502), so the whole detection list was lost to the catch audit.
	BeforeAll {
		$Script:BigId = [Int64]2147725502
		Mock -ModuleName ConfigureDefender Get-MpThreat {
			return [PSCustomObject]@{ ThreatID = 2147725502; ThreatName = 'Test:Big.ID'; SeverityID = 5; CategoryID = 8; IsActive = $false }
		}
		Mock -ModuleName ConfigureDefender Get-MpThreatDetection {
			return [PSCustomObject]@{
				ThreatID = 2147725502; ThreatStatusID = 4; CleaningActionID = 3; DetectionSourceTypeID = 1
				CurrentThreatExecutionStatusID = 0; InitialDetectionTime = (Get-Date); ActionSuccess = $true
				DomainUser = 'TEST\user'; ProcessName = 'test.exe'; Resources = @('file:_C:\x'); DetectionID = 'abc'
			}
		}
	}

	It 'returns a detection whose ThreatID is above the 32-bit integer range, instead of throwing' {
		$Result = @(Get-CDThreatDetection)
		$Result.Count | Should -Be 1
		$Result[0].ThreatID | Should -Be $Script:BigId
	}

	It 'still resolves the threat name for that large ID (lookup key and detection ID use the same type)' {
		(Get-CDThreatDetection)[0].ThreatName | Should -Be 'Test:Big.ID'
	}

	It 'writes nothing to the catch audit for a large ID' {
		Clear-MyCatchAuditLog -ErrorAction SilentlyContinue
		$null = Get-CDThreatDetection
		@(Get-MyCatchAuditLog | Where-Object { $_.Source -like '*Get-CDThreatDetection*' }).Count | Should -Be 0
	}
}

# ============================================================
Describe 'Get-CDASRRule' {
	BeforeAll {
		Mock -ModuleName ConfigureDefender Get-MpPreference { return $Script:MpPref }
	}

	It 'Should return exactly 17 objects' {
		@(Get-CDASRRule).Count | Should -Be 17
	}

	It 'Each object should have GUID, Action, Description properties' {
		Get-CDASRRule | ForEach-Object {
			$_.PSObject.Properties.Name | Should -Contain 'GUID'
			$_.PSObject.Properties.Name | Should -Contain 'Action'
			$_.PSObject.Properties.Name | Should -Contain 'Description'
		}
	}

	It 'Configured rule with action 1 should return Blocked' {
		$Rule = Get-CDASRRule | Where-Object { $_.GUID -eq 'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550' }
		$Rule.Action | Should -Be 'Blocked'
	}

	It 'Unconfigured rules should return Not Set' {
		$Unconfigured = Get-CDASRRule | Where-Object { $_.GUID -ne 'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550' }
		$Unconfigured | ForEach-Object { $_.Action | Should -Be 'Not Set' }
	}

	It 'Should return Not Set for all rules when Ids is null' {
		Mock -ModuleName ConfigureDefender Get-MpPreference {
			return [PSCustomObject]@{
				AttackSurfaceReductionRules_Ids     = $null
				AttackSurfaceReductionRules_Actions = $null
			}
		}
		Get-CDASRRule | ForEach-Object { $_.Action | Should -Be 'Not Set' }
	}

	It 'Should return Unknown for an unrecognised action value' {
		Mock -ModuleName ConfigureDefender Get-MpPreference {
			return [PSCustomObject]@{
				AttackSurfaceReductionRules_Ids     = @('be9ba2d9-53ea-4cdc-84e5-9b1eeee46550')
				AttackSurfaceReductionRules_Actions = @(99)
			}
		}
		$Rule = Get-CDASRRule | Where-Object { $_.GUID -eq 'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550' }
		$Rule.Action | Should -Be 'Unknown (99)'
	}

	It 'Description should match the known rule table entry' {
		$Rule = Get-CDASRRule | Where-Object { $_.GUID -eq 'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550' }
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
Describe 'Get-CDControlledFolder' {
	BeforeAll {
		Mock -ModuleName ConfigureDefender Get-MpPreference { return $Script:MpPref }
	}

	It 'Should return all protected folders' {
		@(Get-CDControlledFolder).Count | Should -Be 2
	}

	It 'Like filter should narrow results' {
		$Result = Get-CDControlledFolder -Like 'Documents'
		@($Result).Count | Should -Be 1
		$Result          | Should -Be 'C:\Users\Documents'
	}

	It 'Like filter with no match should return empty' {
		@(Get-CDControlledFolder -Like 'NoMatch').Count | Should -Be 0
	}

	It 'Should return empty when list is null' {
		Mock -ModuleName ConfigureDefender Get-MpPreference {
			return [PSCustomObject]@{ ControlledFolderAccessProtectedFolders = $null }
		}
		Get-CDControlledFolder | Should -BeNullOrEmpty
	}
}

# ============================================================
Describe 'Get-CDASRExclusion' {
	BeforeAll {
		Mock -ModuleName ConfigureDefender Get-MpPreference { return $Script:MpPref }
	}

	It 'Should return all exclusion paths' {
		@(Get-CDASRExclusion).Count | Should -Be 2
	}

	It 'Like filter should narrow results' {
		$Result = Get-CDASRExclusion -Like 'MyApp'
		@($Result).Count | Should -Be 1
		$Result          | Should -Be 'C:\MyApp\'
	}

	It 'Like filter with no match should return empty' {
		@(Get-CDASRExclusion -Like 'NoMatch').Count | Should -Be 0
	}
}

# ============================================================
Describe 'Get-CDAllowedApplication' {
	BeforeAll {
		Mock -ModuleName ConfigureDefender Get-MpPreference { return $Script:MpPref }
		# notepad.exe exists; missing.exe does not
		Mock -ModuleName ConfigureDefender Test-Path { $true } -ParameterFilter { $LiteralPath -eq 'C:\Windows\notepad.exe' }
		Mock -ModuleName ConfigureDefender Test-Path { $false } -ParameterFilter { $LiteralPath -ne 'C:\Windows\notepad.exe' }
	}

	It 'Should return all allowed apps with no filter' {
		@(Get-CDAllowedApplication).Count | Should -Be 2
	}

	It 'Like filter should narrow results' {
		$Result = Get-CDAllowedApplication -Like 'notepad'
		@($Result).Count | Should -Be 1
		$Result          | Should -Be 'C:\Windows\notepad.exe'
	}

	It 'CheckMissing should return only paths that do not exist on disk' {
		$Result = Get-CDAllowedApplication -CheckMissing
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

	It 'AddAll: should call Add-MpPreference ONCE, with all 17 rules (was one call per rule)' {
		Set-CDASRRule -AddAll -Action Disabled
		Should -Invoke Add-MpPreference -ModuleName ConfigureDefender -Times 1 -Exactly
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
		Mock -ModuleName ConfigureDefender Test-Path { $true } -ParameterFilter { $LiteralPath -eq 'C:\Windows\notepad.exe' }
		Mock -ModuleName ConfigureDefender Test-Path { $false } -ParameterFilter { $LiteralPath -ne 'C:\Windows\notepad.exe' }
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
	It 'Get-CDEvent -Filter only accepts All, ASR, CFA' {
		{ Get-CDEvent -Filter 'Invalid' } | Should -Throw
	}

	It 'Set-CDASRRule -Action only accepts Disabled, Audit, Blocked, Warn' {
		{ Set-CDASRRule -GUID 'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550' -Action 'NotValid' } |
			Should -Throw
	}

	It 'Get-CDAllowedApplication Like and CheckMissing are mutually exclusive parameter sets' {
		{ Get-CDAllowedApplication -Like 'foo' -CheckMissing } | Should -Throw
	}
}

# ============================================================
Describe 'Pipe session close / reuse use the inner PipeInfo' {
	# Regression (2026-10-12): $script:CDPipeInfo holds the whole ServerClientParams. Test-PipeSession and
	# Stop-PipeSession need its inner 'PipeInfo'. Passing the outer object made Test-PipeSession return $false
	# every time, so no ExitPipe was sent and the hidden elevated server was left running after the GUI closed.
	BeforeEach {
		InModuleScope ConfigureDefender {
			$script:CDPipeInfo          = [ordered]@{ PipeInfo = [PSCustomObject]@{ Marker = 'inner' }; Other = 1 }
			$script:CDSendRequestParams = [ordered]@{ NoExitOnError = $true }
		}
	}

	AfterEach {
		InModuleScope ConfigureDefender {
			$script:CDPipeInfo          = $null
			$script:CDSendRequestParams = $null
		}
	}

	It 'Close-CDPipeSession tests the inner PipeInfo and sends a normal exit when healthy' {
		Mock -ModuleName ConfigureDefender Test-PipeSession { $true }
		Mock -ModuleName ConfigureDefender Stop-PipeSession {}
		Close-CDPipeSession
		Should -Invoke -ModuleName ConfigureDefender Test-PipeSession -Times 1 -Exactly -ParameterFilter { $PipeInfo.Marker -eq 'inner' }
		Should -Invoke -ModuleName ConfigureDefender Stop-PipeSession -Times 1 -Exactly -ParameterFilter { $PipeInfo.Marker -eq 'inner' -and -not $Force }
	}

	It 'Close-CDPipeSession force-stops through the inner PipeInfo when the normal exit cannot be delivered' {
		Mock -ModuleName ConfigureDefender Test-PipeSession { $false }
		Mock -ModuleName ConfigureDefender Stop-PipeSession {}
		Close-CDPipeSession
		Should -Invoke -ModuleName ConfigureDefender Stop-PipeSession -Times 1 -Exactly -ParameterFilter { $PipeInfo.Marker -eq 'inner' -and $Force }
	}

	It 'Close-CDPipeSession does not throw when the force-stop itself fails' {
		Mock -ModuleName ConfigureDefender Test-PipeSession { $false }
		Mock -ModuleName ConfigureDefender Stop-PipeSession { throw 'server unreachable' }
		Mock -ModuleName ConfigureDefender Write-MyCatchAudit {}
		{ Close-CDPipeSession } | Should -Not -Throw
	}

	It 'Close-CDPipeSession clears the stored session state' {
		Mock -ModuleName ConfigureDefender Test-PipeSession { $true }
		Mock -ModuleName ConfigureDefender Stop-PipeSession {}
		Close-CDPipeSession
		InModuleScope ConfigureDefender {
			$script:CDPipeInfo          | Should -BeNullOrEmpty
			$script:CDSendRequestParams | Should -BeNullOrEmpty
		}
	}

	It 'Close-CDPipeSession with no session does nothing and does not throw' {
		InModuleScope ConfigureDefender { $script:CDPipeInfo = $null }
		Mock -ModuleName ConfigureDefender Test-PipeSession { $true }
		Mock -ModuleName ConfigureDefender Stop-PipeSession {}
		{ Close-CDPipeSession } | Should -Not -Throw
		Should -Invoke -ModuleName ConfigureDefender Stop-PipeSession -Times 0 -Exactly
	}

	It 'Open-CDPipeSession reuses a healthy session instead of starting another server' {
		Mock -ModuleName ConfigureDefender Test-PipeSession { $PipeInfo.Marker -eq 'inner' }
		Mock -ModuleName ConfigureDefender Start-PipeSession { throw 'must not start a second server' }
		{ Open-CDPipeSession } | Should -Not -Throw
		Should -Invoke -ModuleName ConfigureDefender Start-PipeSession -Times 0 -Exactly
	}
}

# ============================================================
Describe 'ConvertTo-CDEscapedArg (GUI quoting helper)' {
	BeforeAll {
		$Script:HelpersPath = Join-Path $Script:ModulePath 'Scripts\GUI-Helpers.ps1'
		$Tokens = $null; $Errors = $null
		$Ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:HelpersPath, [ref]$Tokens, [ref]$Errors)
		$Fn  = $Ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'ConvertTo-CDEscapedArg' }, $true)
		. ([scriptblock]::Create($Fn.Extent.Text))
		# the four curly single quotes PowerShell also treats as quotes
		$Script:Curly = [char]0x2018, [char]0x2019, [char]0x201A, [char]0x201B
	}

	It 'leaves an ordinary path unchanged' {
		ConvertTo-CDEscapedArg 'C:\Program Files\App\app.exe' | Should -BeExactly 'C:\Program Files\App\app.exe'
	}

	It 'accepts an empty string' {
		ConvertTo-CDEscapedArg '' | Should -BeExactly ''
	}

	It 'doubles the ASCII apostrophe' {
		ConvertTo-CDEscapedArg "C:\Bob's\a.exe" | Should -BeExactly "C:\Bob''s\a.exe"
	}

	It 'doubles each of the four curly single quotes' {
		foreach ($Q in $Script:Curly)
		{
			ConvertTo-CDEscapedArg ("C:\Bob{0}s\a.exe" -f $Q) | Should -BeExactly ("C:\Bob{0}{0}s\a.exe" -f $Q)
		}
	}

	It 'refuses control characters' {
		{ ConvertTo-CDEscapedArg "C:\a`nb" } | Should -Throw
		{ ConvertTo-CDEscapedArg "C:\a`0b" } | Should -Throw
	}

	It 'round-trips through the script block the server builds, including a curly-quote injection attempt' {
		$Evil = "C:\x{0}; Get-Process; {0}y" -f $Script:Curly[1]
		foreach ($Value in "C:\Bob's\a.exe", ("C:\Bob{0}s\a.exe" -f $Script:Curly[0]), $Evil)
		{
			$Cmd = "Write-Output -InputObject '{0}'" -f (ConvertTo-CDEscapedArg $Value)
			& ([scriptblock]::Create($Cmd)) | Should -BeExactly $Value
		}
	}
}

# ============================================================
Describe 'Set-CDSetting' {
	BeforeEach {
		Mock -ModuleName ConfigureDefender Write-CDAuditEvent {}
		Mock -ModuleName ConfigureDefender Write-MyCatchAudit {}
		# Default: Defender "accepts" every change, so Get-MpPreference reads back whatever Set-MpPreference was given.
		# Tests of a change that does NOT stick define their own Set-/Get-MpPreference mocks.
		$Script:Applied = @{}
		Mock -ModuleName ConfigureDefender Set-MpPreference { foreach ($k in $PSBoundParameters.Keys) { if ($k -ne 'ErrorAction') { $Script:Applied[$k] = $PSBoundParameters[$k] } } }
		Mock -ModuleName ConfigureDefender Get-MpPreference { [PSCustomObject]$Script:Applied }
	}

	It 'turns the request text $false into a real boolean False' {
		Mock -ModuleName ConfigureDefender Set-MpPreference {}
		Set-CDSetting -Name 'DisableRealtimeMonitoring' -Value '$false'
		Should -Invoke -ModuleName ConfigureDefender Set-MpPreference -Times 1 -Exactly -ParameterFilter { $DisableRealtimeMonitoring -is [bool] -and -not $DisableRealtimeMonitoring }
	}

	It 'turns the request text $true into a real boolean True' {
		Set-CDSetting -Name 'DisableRealtimeMonitoring' -Value '$true'
		Should -Invoke -ModuleName ConfigureDefender Set-MpPreference -Times 1 -Exactly -ParameterFilter { $DisableRealtimeMonitoring -is [bool] -and $DisableRealtimeMonitoring }
	}

	It 'passes a real boolean through unchanged' {
		Mock -ModuleName ConfigureDefender Set-MpPreference {}
		Set-CDSetting -Name 'DisableRealtimeMonitoring' -Value $false
		Should -Invoke -ModuleName ConfigureDefender Set-MpPreference -Times 1 -Exactly -ParameterFilter { $DisableRealtimeMonitoring -is [bool] -and -not $DisableRealtimeMonitoring }
	}

	It 'passes an integer through unchanged' {
		Set-CDSetting -Name 'CloudExtendedTimeout' -Value 20
		Should -Invoke -ModuleName ConfigureDefender Set-MpPreference -Times 1 -Exactly -ParameterFilter { $CloudExtendedTimeout -eq 20 }
	}

	It 'writes the audit event after a successful change' {
		Set-CDSetting -Name 'CloudExtendedTimeout' -Value 20
		Should -Invoke -ModuleName ConfigureDefender Write-CDAuditEvent -Times 1 -Exactly
	}

	It 'throws and writes no audit event when Set-MpPreference fails' {
		Mock -ModuleName ConfigureDefender Set-MpPreference { throw 'Defender refused the change' }
		{ Set-CDSetting -Name 'CloudExtendedTimeout' -Value 20 } | Should -Throw
		Should -Invoke -ModuleName ConfigureDefender Write-CDAuditEvent -Times 0 -Exactly
	}

	It 'fails loudly when Defender accepts a boolean change but the value does not change (Tamper Protection)' {
		Mock -ModuleName ConfigureDefender Set-MpPreference {}
		Mock -ModuleName ConfigureDefender Get-MpPreference { [PSCustomObject]@{ DisableArchiveScanning = $false } }
		{ Set-CDSetting -Name 'DisableArchiveScanning' -Value $true } | Should -Throw -ExpectedMessage '*still*Tamper Protection*'
		Should -Invoke -ModuleName ConfigureDefender Write-CDAuditEvent -Times 0 -Exactly
	}

	It 'fails loudly for the request text $true when the value does not change' {
		Mock -ModuleName ConfigureDefender Set-MpPreference {}
		Mock -ModuleName ConfigureDefender Get-MpPreference { [PSCustomObject]@{ DisableArchiveScanning = $false } }
		{ Set-CDSetting -Name 'DisableArchiveScanning' -Value '$true' } | Should -Throw -ExpectedMessage '*still*'
	}

	It 'succeeds and audits when the boolean change sticks' {
		Mock -ModuleName ConfigureDefender Set-MpPreference {}
		Mock -ModuleName ConfigureDefender Get-MpPreference { [PSCustomObject]@{ DisableArchiveScanning = $true } }
		{ Set-CDSetting -Name 'DisableArchiveScanning' -Value $true } | Should -Not -Throw
		Should -Invoke -ModuleName ConfigureDefender Write-CDAuditEvent -Times 1 -Exactly
	}

	It 'fails loudly when an integer setting does not change' {
		Mock -ModuleName ConfigureDefender Set-MpPreference {}
		Mock -ModuleName ConfigureDefender Get-MpPreference { [PSCustomObject]@{ CloudExtendedTimeout = 10 } }
		{ Set-CDSetting -Name 'CloudExtendedTimeout' -Value 20 } | Should -Throw -ExpectedMessage '*still*'
	}

	It 'accepts an integer that matches an enum value read back' {
		Mock -ModuleName ConfigureDefender Set-MpPreference {}
		Mock -ModuleName ConfigureDefender Get-MpPreference { [PSCustomObject]@{ PUAProtection = [System.DayOfWeek]::Tuesday } }
		{ Set-CDSetting -Name 'PUAProtection' -Value 2 } | Should -Not -Throw
	}

	It 'stays quiet when the setting cannot be read back (property absent)' {
		Mock -ModuleName ConfigureDefender Set-MpPreference {}
		Mock -ModuleName ConfigureDefender Get-MpPreference { [PSCustomObject]@{ SomethingElse = 1 } }
		{ Set-CDSetting -Name 'DisableArchiveScanning' -Value $true } | Should -Not -Throw
	}

	It 'asks Set-MpPreference to stop on error so a non-terminating failure is not reported as success' {
		# A NON-terminating error from Set-MpPreference must become terminating, otherwise the catch never runs
		# and the audit entry reports a change that did not happen. Pester mocks do not carry -ErrorAction into
		# the mock body, so this checks the call itself rather than its behaviour.
		$Path = Join-Path $Script:ModulePath 'FunctionsWindows\Set-CDSetting.ps1'
		$Ast  = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
		$Call = $Ast.Find({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Set-MpPreference' }, $true)
		$Call | Should -Not -BeNullOrEmpty
		$Els = @($Call.CommandElements)
		$Idx = -1
		for ($i = 0; $i -lt $Els.Count; $i++)
		{ if ($Els[$i] -is [System.Management.Automation.Language.CommandParameterAst] -and $Els[$i].ParameterName -eq 'ErrorAction') { $Idx = $i } }
		$Idx | Should -BeGreaterThan -1
		# the value is either attached (-ErrorAction:Stop) or the next element (-ErrorAction Stop)
		$ValueAst = if ($Els[$Idx].Argument) { $Els[$Idx].Argument } else { $Els[$Idx + 1] }
		$ValueAst.Extent.Text | Should -BeExactly 'Stop'
	}
}

# ============================================================
Describe 'Open-CDPipeSession replaces a stale session cleanly' {
	BeforeEach {
		InModuleScope ConfigureDefender {
			$script:CDPipeInfo          = [ordered]@{ PipeInfo = [PSCustomObject]@{ Marker = 'stale' } }
			$script:CDSendRequestParams = [ordered]@{ NoExitOnError = $true }
		}
	}

	AfterEach {
		InModuleScope ConfigureDefender {
			$script:CDPipeInfo          = $null
			$script:CDSendRequestParams = $null
		}
	}

	It 'closes the stale session before it starts a replacement' {
		$Script:CallOrder = [System.Collections.Generic.List[string]]::new()
		Mock -ModuleName ConfigureDefender Test-PipeSession { $false }
		Mock -ModuleName ConfigureDefender Close-CDPipeSession { $Script:CallOrder.Add('close') }
		Mock -ModuleName ConfigureDefender Start-PipeSession {
			$Script:CallOrder.Add('start')
			[PSCustomObject]@{
				ServerClientParams = [ordered]@{ PipeInfo = [PSCustomObject]@{ Marker = 'new' } }
				SendRequestParams  = [ordered]@{}
			}
		}
		Open-CDPipeSession
		($Script:CallOrder -join ',') | Should -BeExactly 'close,start'
		InModuleScope ConfigureDefender { $script:CDPipeInfo.PipeInfo.Marker } | Should -BeExactly 'new'
	}

	It 'leaves a healthy session alone' {
		Mock -ModuleName ConfigureDefender Test-PipeSession { $true }
		Mock -ModuleName ConfigureDefender Close-CDPipeSession {}
		Mock -ModuleName ConfigureDefender Start-PipeSession { throw 'must not start a second server' }
		{ Open-CDPipeSession } | Should -Not -Throw
		Should -Invoke -ModuleName ConfigureDefender Close-CDPipeSession -Times 0 -Exactly
		Should -Invoke -ModuleName ConfigureDefender Start-PipeSession -Times 0 -Exactly
	}
}

# ============================================================
Describe 'GUI scripts - regression guards' {
	BeforeAll {
		$Script:GuiDir = Join-Path $Script:ModulePath 'Scripts'
	}

	It 'closes the pipe in FormClosed, not FormClosing, so the later "SAC logging off" handler still has a session' {
		$Path = Join-Path $Script:GuiDir 'ConfigureDefenderGUI.ps1'
		$Ast  = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
		$Calls = $Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Member.Value -like 'Add_Form*' }, $true)
		$Closer = @($Calls | Where-Object { $_.Extent.Text -match 'Close-CDPipeSession' })
		$Closer.Count | Should -Be 1
		$Closer[0].Member.Value | Should -BeExactly 'Add_FormClosed'
	}

	It 'sends Boolean settings as $true / $false, not the backtick-escaped text' {
		$Text = Get-Content -LiteralPath (Join-Path $Script:GuiDir 'GUI-Tab-Settings.ps1') -Raw
		$Text | Should -Not -Match '`\$(true|false)'
	}

	It 'builds no command string from a value escaped with the ASCII-only -replace' {
		foreach ($File in Get-ChildItem -LiteralPath $Script:GuiDir -Filter 'GUI-Tab-*.ps1')
		{
			$Text = Get-Content -LiteralPath $File.FullName -Raw
			($File.Name + ': ' + ($Text -match '-replace\s+"''"\s*,\s*"''''"')) | Should -BeExactly ($File.Name + ': False')
		}
	}

	It 'adds the new entry before removing the old one when editing an exclusion or allowed application' {
		foreach ($Name in 'GUI-Tab-CFA.ps1')
		{
			$Text  = Get-Content -LiteralPath (Join-Path $Script:GuiDir $Name) -Raw
			$Pairs = [regex]::Matches($Text, '\$Esc(Old|New)\x27 -(Add|Remove)')
			$Pairs.Count | Should -BeGreaterThan 0
			# every edit handler must read "add NEW, then remove OLD", repeated once per handler
			$Seq = ($Pairs | ForEach-Object { $_.Groups[1].Value + $_.Groups[2].Value }) -join ' '
			$Seq | Should -Match '^NewAdd OldRemove( NewAdd OldRemove)*$'
		}
	}
}

# ============================================================
Describe 'Vendored dependencies are all present' {
	It 'has Write-MyLog, which the vendored Invoke-FileManagement calls' {
		Test-Path -LiteralPath (Join-Path $Script:ModulePath 'Functions\vendored\Write-MyLog.ps1') | Should -BeTrue
		Test-Path -LiteralPath (Join-Path $Script:ModulePath 'Functions\vendored\Invoke-FileManagement.ps1') | Should -BeTrue
	}

	It 'loads Write-MyLog inside the module without exporting it' {
		(Get-Module ConfigureDefender).ExportedFunctions.ContainsKey('Write-MyLog') | Should -BeFalse
		& (Get-Module ConfigureDefender) { [bool](Get-Command Write-MyLog -ErrorAction SilentlyContinue) } | Should -BeTrue
	}
}

# ============================================================
Describe 'Get-CDStatusSummary (keeps the GUI status bar to one line)' {
	BeforeAll {
		$Tokens = $null; $Errors = $null
		$Ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Script:ModulePath 'Scripts\GUI-Helpers.ps1'), [ref]$Tokens, [ref]$Errors)
		$Fn  = $Ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-CDStatusSummary' }, $true)
		. ([scriptblock]::Create($Fn.Extent.Text))

		# Shape of the error text a failed server request returns (several errors, wrapped messages, long stack traces)
		$Script:Dump = @"
Error No1
     Line No.          : 44
     Line              : [void][Convert]::FromBase64String(`$Value)
     Message           : Exception calling "FromBase64String" with "1" argument(s): "The input is not a valid Base-64
                         string as it contains a non-base 64 character."
     Command Path      : C:\Modules\NamedPipe\0.16\Functions\Test-Base64String.ps1
     Exception Type    : System.Management.Automation.MethodInvocationException
     Stack Trace       : at Test-Base64String, C:\Modules\NamedPipe\0.16\Functions\Test-Base64String.ps1: line 44

_______________________

Error No2
     Line No.          : 29
     Message           : UNC paths not allowed for exclusions
     Command Path      : C:\Modules\ConfigureDefender\0.4\FunctionsWindows\Set-CDExclusionPath.ps1
     Exception Type    : System.Management.Automation.RuntimeException

_______________________

Error No3
     Line No.          : 1
     Message           : Cannot validate argument on parameter 'Path'. UNC paths not allowed for exclusions
     Exception Type    : System.Management.Automation.ParameterBindingValidationException

_______________________

Error No4

_______________________

Error No5
     Line No.          : 338
     Message           : Exception calling "Invoke" with "0" argument(s): "Cannot validate argument on parameter
                         'Path'. UNC paths not allowed for exclusions"
     Exception Type    : System.Management.Automation.MethodInvocationException
"@
		# make it long the way the real one is
		$Script:BigDump = "Error adding new path (old entry left as it was): `r`n" + $Script:Dump + ("`r`n" + ("     Stack Trace       : at Something, C:\Modules\X\Y.ps1: line 1`r`n" * 100))
	}

	It 'returns short single-line text unchanged' {
		Get-CDStatusSummary 'Loading...' | Should -BeExactly 'Loading...'
		Get-CDStatusSummary 'Exclusion Paths loaded (3 entries).' | Should -BeExactly 'Exclusion Paths loaded (3 entries).'
	}

	It 'returns an empty string for empty or null input' {
		Get-CDStatusSummary '' | Should -BeExactly ''
		Get-CDStatusSummary $null | Should -BeExactly ''
	}

	It 'cuts a long multi-line error dump to one short line' {
		$Summary = Get-CDStatusSummary $Script:BigDump
		$Script:BigDump.Length | Should -BeGreaterThan 3000
		$Summary | Should -Not -Match "[\r\n]"
		$Summary.Length | Should -BeLessOrEqual 220
	}

	It 'keeps the caller''s own prefix and the real cause, not the wrapper messages' {
		$Summary = Get-CDStatusSummary $Script:BigDump
		$Summary | Should -Match '^Error adding new path \(old entry left as it was\):'
		$Summary | Should -Match "UNC paths not allowed"
		$Summary | Should -Not -Match 'Exception calling'
	}

	It 'handles multi-line text that has no Message lines' {
		$Summary = Get-CDStatusSummary "Error: something failed`r`nsecond line of detail`r`nthird line"
		$Summary | Should -Not -Match "[\r\n]"
		$Summary | Should -Match '^Error: something failed'
	}

	It 'truncates a very long single line' {
		$Summary = Get-CDStatusSummary ('x' * 1000)
		$Summary.Length | Should -Be 220
		$Summary | Should -Match '\.\.\.$'
	}
}

# ============================================================
Describe 'GUI status bar is wired to the summariser' {
	It 'hooks StatusLabel.TextChanged and calls Get-CDStatusSummary' {
		$Path = Join-Path $Script:ModulePath 'Scripts\ConfigureDefenderGUI.ps1'
		$Ast  = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
		$Hook = @($Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Member.Value -eq 'Add_TextChanged' -and $n.Expression.Extent.Text -eq '$StatusLabel' }, $true))
		$Hook.Count | Should -Be 1
		$Hook[0].Extent.Text | Should -Match 'Get-CDStatusSummary'
	}
}

# ============================================================
Describe 'Settings tab never trusts the value it typed' {
	BeforeAll {
		$Tokens = $null; $Errors = $null
		$Script:SetPath = Join-Path $Script:ModulePath 'Scripts\GUI-Tab-Settings.ps1'
		$HAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Script:ModulePath 'Scripts\GUI-Helpers.ps1'), [ref]$Tokens, [ref]$Errors)
		$Fn   = $HAst.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Test-CDSettingMatch' }, $true)
		. ([scriptblock]::Create($Fn.Extent.Text))
	}

	It 'Test-CDSettingMatch compares booleans as booleans' {
		Test-CDSettingMatch $true  $true  | Should -BeTrue
		Test-CDSettingMatch $false $true  | Should -BeFalse
		Test-CDSettingMatch $false $false | Should -BeTrue
		Test-CDSettingMatch 1      $true  | Should -BeTrue
	}

	It 'Test-CDSettingMatch compares integers and enums as integers' {
		Test-CDSettingMatch 20 20 | Should -BeTrue
		Test-CDSettingMatch 10 20 | Should -BeFalse
		Test-CDSettingMatch ([System.DayOfWeek]::Tuesday) 2 | Should -BeTrue
		Test-CDSettingMatch ([System.DayOfWeek]::Monday)  2 | Should -BeFalse
	}

	It 'Test-CDSettingMatch counts an uncomparable value as a match (no false alarm)' {
		Test-CDSettingMatch 'not a number' 5 | Should -BeTrue
	}

	It 'the edit handler re-reads Defender after the request and no longer writes the typed value into the cache' {
		$Ast = [System.Management.Automation.Language.Parser]::ParseFile($Script:SetPath, [ref]$null, [ref]$null)
		$Hdl = @($Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Member.Value -eq 'Add_DoubleClick' }, $true))
		$Hdl.Count | Should -Be 1
		$Hdl[0].Extent.Text | Should -Match 'Get-CDSetting'
		$Hdl[0].Extent.Text | Should -Match 'Test-CDSettingMatch'
		$Hdl[0].Extent.Text | Should -Not -Match '\$Setting\.Value\s*=\s*\$NewVal'
	}
}

# ============================================================
Describe 'Status bar hover detail' {
	BeforeAll {
		$Tokens = $null; $Errors = $null
		$Ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Script:ModulePath 'Scripts\GUI-Helpers.ps1'), [ref]$Tokens, [ref]$Errors)
		foreach ($Name in 'Get-CDStatusSummary', 'Get-CDStatusDetail')
		{
			$Fn = $Ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name }, $true)
			. ([scriptblock]::Create($Fn.Extent.Text))
		}
		$Script:Dump2 = @"
Error adding new path (old entry left as it was):
Error No1
     Line No.          : 62
     Message           : Defender accepted the command but DisableArchiveScanning is still 'False' (wanted 'True'). Tamper
                         Protection or a policy is probably blocking the change.
     Command Path      : C:\Modules\ConfigureDefender\0.4\FunctionsWindows\Set-CDSetting.ps1
     Stack Trace       : at Set-CDSetting, C:\Modules\ConfigureDefender\0.4\FunctionsWindows\Set-CDSetting.ps1: line 62
_______________________
Error No2
     Line No.          : 338
     Message           : Exception calling "Invoke" with "0" argument(s): "Defender accepted the command but
                         DisableArchiveScanning is still 'False' (wanted 'True')."
     Stack Trace       : at Get-SBResult, C:\Modules\NamedPipe\0.16\Functions\Get-SBResult.ps1: line 338
"@
	}

	It 'ShortenTo makes the summary shorter while a single line up to MaxLength is still left alone' {
		$Short = Get-CDStatusSummary $Script:Dump2 -MaxLength 220 -ShortenTo 90
		$Short.Length | Should -BeLessOrEqual 90
		$Short | Should -Not -Match "[\r\n]"
		$Line = 'x' * 200
		Get-CDStatusSummary $Line -MaxLength 220 -ShortenTo 90 | Should -BeExactly $Line
	}

	It 'the detail lists every error message, numbered, without the stack traces' {
		$Detail = Get-CDStatusDetail $Script:Dump2
		$Detail | Should -Match '1\. Defender accepted the command'
		$Detail | Should -Match '2\. Exception calling "Invoke"'
		$Detail | Should -Not -Match 'Stack Trace'
		$Detail | Should -Not -Match 'Get-SBResult'
		$Detail | Should -Match '^Error adding new path'
	}

	It 'the detail is capped at 3000 characters' {
		$Many = 'Error adding new path: ' + "`r`n" + ((1..400 | ForEach-Object { "Error No$_`r`n     Message           : message number $_ " + ('y' * 60) + "`r`n     Command Path      : C:\x" }) -join "`r`n")
		(Get-CDStatusDetail $Many).Length | Should -BeLessOrEqual 3000
	}

	It 'the detail of text without Message lines is the text itself, cut to 3000 characters' {
		Get-CDStatusDetail 'plain text' | Should -BeExactly 'plain text'
		(Get-CDStatusDetail ('z' * 5000)).Length | Should -Be 3000
		Get-CDStatusDetail '' | Should -BeExactly ''
	}

	It 'the GUI hook uses the detail as the tooltip and adds the hover hint to the shortened text' {
		$Path = Join-Path $Script:ModulePath 'Scripts\ConfigureDefenderGUI.ps1'
		$Text = Get-Content -LiteralPath $Path -Raw
		$Text | Should -Match 'ToolTipText\s*=\s*Get-CDStatusDetail'
		$Text | Should -Match 'hover here for the full error list'
	}
}

# ============================================================
Describe 'Set-CDExclusionPath validates on Add only and allows UNC paths' {
	BeforeEach {
		Mock -ModuleName ConfigureDefender Add-MpPreference {}
		Mock -ModuleName ConfigureDefender Remove-MpPreference {}
		Mock -ModuleName ConfigureDefender Write-MyCatchAudit {}
	}

	It 'adds a UNC path' {
		Set-CDExclusionPath -Path '\\server\share\tools\*' -Add
		Should -Invoke -ModuleName ConfigureDefender Add-MpPreference -Times 1 -Exactly -ParameterFilter { $ExclusionPath -eq '\\server\share\tools\*' }
	}

	It 'adds a drive path and a wildcard path with ?' {
		Set-CDExclusionPath -Path 'C:\Temp\file?.tmp' -Add
		Should -Invoke -ModuleName ConfigureDefender Add-MpPreference -Times 1 -Exactly
	}

	It 'rejects invalid characters on Add - also when the path contains a wildcard (the old rule let < through then)' {
		{ Set-CDExclusionPath -Path 'C:\a|b' -Add } | Should -Throw -ExpectedMessage '*Invalid characters*'
		{ Set-CDExclusionPath -Path 'C:\a<b\*' -Add } | Should -Throw -ExpectedMessage '*Invalid characters*'
		Should -Invoke -ModuleName ConfigureDefender Add-MpPreference -Times 0 -Exactly
	}

	It 'rejects a path over 260 characters on Add' {
		{ Set-CDExclusionPath -Path ('C:\' + ('a' * 300)) -Add } | Should -Throw -ExpectedMessage '*260*'
	}

	It 'removes a UNC entry' {
		Set-CDExclusionPath -Path '\\server\share\x' -Remove
		Should -Invoke -ModuleName ConfigureDefender Remove-MpPreference -Times 1 -Exactly -ParameterFilter { $ExclusionPath -eq '\\server\share\x' }
	}

	It 'removes an entry that Add would refuse (so a bad entry can never be stuck in the list)' {
		Set-CDExclusionPath -Path 'C:\odd<name\*' -Remove
		Should -Invoke -ModuleName ConfigureDefender Remove-MpPreference -Times 1 -Exactly
	}
}

# ============================================================
Describe 'Test-CDEntryMissing (the one rule behind Missing / -RemoveMissing)' {
	BeforeAll {
		$Script:Mod = Get-Module ConfigureDefender
		$Script:Real = Join-Path $TestDrive 'real.exe'
		Set-Content -LiteralPath $Script:Real -Value 'x'
		$Bracket = Join-Path $TestDrive 'Tool[1]'
		New-Item -ItemType Directory -Path $Bracket | Out-Null
		$Script:BracketFile = Join-Path $Bracket 'tool.exe'
		Set-Content -LiteralPath $Script:BracketFile -Value 'x'
		$env:CD_TEST_DIR = $TestDrive
	}
	AfterAll { Remove-Item Env:\CD_TEST_DIR -ErrorAction SilentlyContinue }

	It 'is false for a file that exists' {
		& $Script:Mod { param($p) Test-CDEntryMissing $p } $Script:Real | Should -BeFalse
	}

	It 'is true for a file that does not exist' {
		& $Script:Mod { param($p) Test-CDEntryMissing $p } (Join-Path $TestDrive 'gone.exe') | Should -BeTrue
	}

	It 'is false for an existing file in a folder whose name has [ ] (-Path read it as a wildcard set)' {
		& $Script:Mod { param($p) Test-CDEntryMissing $p } $Script:BracketFile | Should -BeFalse
	}

	It 'is true for a missing file in a [ ] folder' {
		& $Script:Mod { param($p) Test-CDEntryMissing $p } (Join-Path (Join-Path $TestDrive 'Tool[1]') 'nope.exe') | Should -BeTrue
	}

	It 'is false for wildcard entries (they cannot be tested, so they are never removed)' {
		& $Script:Mod { param($p) Test-CDEntryMissing $p } 'C:\NoSuchFolder\*' | Should -BeFalse
		& $Script:Mod { param($p) Test-CDEntryMissing $p } 'C:\NoSuchFolder\app?.exe' | Should -BeFalse
	}

	It 'expands environment variables: an existing target is not missing, a missing one is' {
		& $Script:Mod { Test-CDEntryMissing '%CD_TEST_DIR%\real.exe' } | Should -BeFalse
		& $Script:Mod { Test-CDEntryMissing '%CD_TEST_DIR%\gone.exe' } | Should -BeTrue
	}

	It 'is false when a variable cannot be expanded (doubt never deletes)' {
		& $Script:Mod { Test-CDEntryMissing '%CD_NO_SUCH_VARIABLE_XYZ%\app.exe' } | Should -BeFalse
	}

	It 'is false for empty or null input' {
		& $Script:Mod { Test-CDEntryMissing '' } | Should -BeFalse
		& $Script:Mod { Test-CDEntryMissing $null } | Should -BeFalse
	}
}

# ============================================================
Describe 'Allowed applications: -RemoveMissing and -CheckMissing use the cautious rule' {
	BeforeAll {
		$Script:Dir = Join-Path $TestDrive 'apps'
		New-Item -ItemType Directory -Path (Join-Path $Script:Dir 'Tool[1]') -Force | Out-Null
		$Script:Present  = Join-Path $Script:Dir 'present.exe'
		$Script:Brackets = Join-Path (Join-Path $Script:Dir 'Tool[1]') 'tool.exe'
		Set-Content -LiteralPath $Script:Present -Value 'x'
		Set-Content -LiteralPath $Script:Brackets -Value 'x'
		$Script:Gone = Join-Path $Script:Dir 'gone.exe'
		$Script:List = @($Script:Present, $Script:Brackets, $Script:Gone, 'C:\NoSuchFolder\*')
	}
	BeforeEach {
		Mock -ModuleName ConfigureDefender Get-MpPreference { [PSCustomObject]@{ ControlledFolderAccessAllowedApplications = $Script:List } }
		Mock -ModuleName ConfigureDefender Remove-MpPreference {}
		Mock -ModuleName ConfigureDefender Write-MyCatchAudit {}
	}

	It '-RemoveMissing removes only the entry that is really gone' {
		Set-CDAllowedApplication -RemoveMissing
		Should -Invoke -ModuleName ConfigureDefender Remove-MpPreference -Times 1 -Exactly
		Should -Invoke -ModuleName ConfigureDefender Remove-MpPreference -Times 1 -Exactly -ParameterFilter { $ControlledFolderAccessAllowedApplications -eq $Script:Gone }
	}

	It '-CheckMissing lists only the entry that is really gone' {
		$Missing = @(Get-CDAllowedApplication -CheckMissing)
		$Missing.Count | Should -Be 1
		$Missing[0] | Should -BeExactly $Script:Gone
	}
}

# ============================================================
Describe 'Invoke-SacLoggingOff reports whether the disable really worked' {
	BeforeAll {
		$Tokens = $null; $Errors = $null
		$Ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Script:ModulePath 'Scripts\GUI-Tab-ThreatEvents.ps1'), [ref]$Tokens, [ref]$Errors)
		$Fn  = $Ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-SacLoggingOff' }, $true)
		. ([scriptblock]::Create($Fn.Extent.Text))
		function Get-CDSRP { @{ DataObject = $null } }
		# the module's catch-audit function lives in the module; the extracted function needs a stand-in here
		function Write-MyCatchAudit { param($Source, $ErrorRecord) $Script:Audited = $Source }
		function Send-Request { param([Parameter(ValueFromPipeline)]$In, $DataObject) process { if ($Script:FakeThrow) { throw $Script:FakeThrow }; [PSCustomObject]@{ Error = $Script:FakeError; Result = $null } } }
	}
	BeforeEach { $Script:FakeError = ''; $Script:FakeThrow = $null; $Script:Audited = $null }

	It 'is Ok when the server returns no error' {
		$R = Invoke-SacLoggingOff
		$R.Ok | Should -BeTrue
		$R.Why | Should -BeExactly ''
	}

	It 'is NOT Ok when the server returns an error (it does not throw)' {
		$Script:FakeError = 'channel is locked by another process'
		$R = Invoke-SacLoggingOff
		$R.Ok | Should -BeFalse
		$R.Why | Should -Match 'locked'
	}

	It 'is NOT Ok when the request itself throws' {
		$Script:FakeThrow = 'pipe is gone'
		$R = Invoke-SacLoggingOff
		$R.Ok | Should -BeFalse
		$R.Why | Should -Match 'pipe is gone'
		$Script:Audited | Should -Match 'Invoke-SacLoggingOff'   # the failure is recorded, not just returned
	}

	It 'is used by the manual-off and startup paths as well as the definition' {
		$Text = Get-Content -LiteralPath (Join-Path $Script:ModulePath 'Scripts\GUI-Tab-ThreatEvents.ps1') -Raw
		([regex]::Matches($Text, 'Invoke-SacLoggingOff')).Count | Should -BeGreaterOrEqual 3
	}
}

# ============================================================
Describe 'One exclusion-path rule for typed and Browse input' {
	BeforeAll {
		$Tokens = $null; $Errors = $null
		$Ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Script:ModulePath 'Scripts\GUI-Helpers.ps1'), [ref]$Tokens, [ref]$Errors)
		$Fn  = $Ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Test-CDExclusionPath' }, $true)
		. ([scriptblock]::Create($Fn.Extent.Text))
	}

	It 'the GUI rule accepts drive, UNC and environment-variable paths and rejects relative and bad ones' {
		Test-CDExclusionPath 'C:\Apps\x.exe'       | Should -BeTrue
		Test-CDExclusionPath '\\server\share\x'    | Should -BeTrue
		Test-CDExclusionPath '%APPDATA%\x'         | Should -BeTrue
		Test-CDExclusionPath 'relative\x'          | Should -BeFalse
		Test-CDExclusionPath 'C:\a|b'              | Should -BeFalse
	}

	It 'the Browse-button check defers to that rule and no longer carries its own UNC ban' {
		$Text = Get-Content -LiteralPath (Join-Path $Script:ModulePath 'Scripts\GUI-Helpers.ps1') -Raw
		$Text | Should -Not -Match 'UNC paths not allowed'
		$Text | Should -Match 'if \(-not \(Test-CDExclusionPath \$Path\)\)'
	}
}

# ============================================================
Describe 'Enum edit dialog does not preselect the first option for an unlisted live value' {
	It 'selects nothing when the live value is not a choice, and treats OK with no choice as no change' {
		$Text = Get-Content -LiteralPath (Join-Path $Script:ModulePath 'Scripts\GUI-Tab-Settings.ps1') -Raw
		$Text | Should -Match '\$CurrentIdx\s*=\s*-1'
		$Text | Should -Match 'if \(\$SelIdx -ge 0\)'
		$Text | Should -Match 'not one of these choices'
		$Text | Should -Not -Match '\$CurrentIdx\s*=\s*0;'
	}
}

# ============================================================
Describe 'GUI event handlers cannot throw into WinForms, and the auto-off timer does not outlive its window' {
	BeforeAll {
		$Script:GuiAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Script:ModulePath 'Scripts\ConfigureDefenderGUI.ps1'), [ref]$null, [ref]$null)
		$Script:TabAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Script:ModulePath 'Scripts\GUI-Tab-ThreatEvents.ps1'), [ref]$null, [ref]$null)
		function Get-HandlerBodyStatement ($Ast, [string]$Member, [string]$Target)
		{
			$Call = $Ast.Find({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Member.Value -eq $Member -and $n.Expression.Extent.Text -eq $Target }, $true)
			if (-not $Call) { return $null }
			@($Call.Arguments[0].ScriptBlock.EndBlock.Statements)
		}
	}

	It 'the SAC auto-off Tick handler body is a single try/catch, so nothing can escape it' {
		$S = Get-HandlerBodyStatement $Script:TabAst 'Add_Tick' '$script:LogAllowsTimer'
		$S | Should -Not -BeNullOrEmpty
		$S.Count | Should -Be 1
		$S[0] | Should -BeOfType ([System.Management.Automation.Language.TryStatementAst])
		$S[0].CatchClauses.Count | Should -BeGreaterThan 0
	}

	It 'the Tick handler turns logging off through Invoke-SacLoggingOff (so it checks the result)' {
		$Call = $Script:TabAst.Find({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Member.Value -eq 'Add_Tick' }, $true)
		$Call.Extent.Text | Should -Match 'Invoke-SacLoggingOff'
	}

	It 'the status-bar TextChanged hook body is a single try/catch' {
		$S = Get-HandlerBodyStatement $Script:GuiAst 'Add_TextChanged' '$StatusLabel'
		$S | Should -Not -BeNullOrEmpty
		$S.Count | Should -Be 1
		$S[0] | Should -BeOfType ([System.Management.Automation.Language.TryStatementAst])
	}

	It 'closing the window stops and disposes the auto-off timer' {
		$Call = $Script:GuiAst.Find({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Member.Value -eq 'Add_FormClosed' -and $n.Expression.Extent.Text -eq '$Form' }, $true)
		$Call | Should -Not -BeNullOrEmpty
		$Call.Extent.Text | Should -Match 'LogAllowsTimer\.Stop\(\)'
		$Call.Extent.Text | Should -Match 'LogAllowsTimer\.Dispose\(\)'
	}
}

# ============================================================
Describe 'Set-CDCIVerbose records only unexpected LogMode failures' {
	BeforeEach {
		$Script:SaveMsg = 'The parameter is incorrect.'
		Mock -ModuleName ConfigureDefender Write-MyCatchAudit {}
		Mock -ModuleName ConfigureDefender Unregister-ScheduledTask {}
		Mock -ModuleName ConfigureDefender Register-ScheduledTask { [PSCustomObject]@{} }
	}

	It 'enable: the channel refusing Circular (always, on this build) is NOT recorded' {
		# a fresh channel object per call; only a SaveChanges made while LogMode is Circular fails
		Mock -ModuleName ConfigureDefender Get-WinEvent {
			$o = [PSCustomObject]@{ IsEnabled = $false; MaximumSizeInBytes = 1052672; LogMode = [System.Diagnostics.Eventing.Reader.EventLogMode]::Retain }
			$o | Add-Member -MemberType ScriptMethod -Name SaveChanges -Value { if ($this.LogMode -eq [System.Diagnostics.Eventing.Reader.EventLogMode]::Circular) { throw $Script:SaveMsg } }
			$o
		}
		$R = Set-CDCIVerbose -WatchdogMinutes 0
		$R.Enabled | Should -BeFalse   # the mock never really enables anything; what matters is that it did not throw
		Should -Invoke -ModuleName ConfigureDefender Write-MyCatchAudit -Times 0 -Exactly -ParameterFilter { $Source -like '*LogMode*' }
	}

	It 'enable: a DIFFERENT failure setting the mode is still recorded' {
		$Script:SaveMsg = 'Access is denied.'
		Mock -ModuleName ConfigureDefender Get-WinEvent {
			$o = [PSCustomObject]@{ IsEnabled = $false; MaximumSizeInBytes = 1052672; LogMode = [System.Diagnostics.Eventing.Reader.EventLogMode]::Retain }
			$o | Add-Member -MemberType ScriptMethod -Name SaveChanges -Value { if ($this.LogMode -eq [System.Diagnostics.Eventing.Reader.EventLogMode]::Circular) { throw $Script:SaveMsg } }
			$o
		}
		$null = Set-CDCIVerbose -WatchdogMinutes 0
		Should -Invoke -ModuleName ConfigureDefender Write-MyCatchAudit -Times 1 -Exactly -ParameterFilter { $Source -like '*set LogMode Circular*' }
	}

	It 'disable: the known refusal restoring the default mode is NOT recorded' {
		Mock -ModuleName ConfigureDefender Get-WinEvent {
			$o = [PSCustomObject]@{ IsEnabled = $true; MaximumSizeInBytes = 134217728; LogMode = [System.Diagnostics.Eventing.Reader.EventLogMode]::Circular }
			$o | Add-Member -MemberType ScriptMethod -Name SaveChanges -Value { if ($this.LogMode -eq [System.Diagnostics.Eventing.Reader.EventLogMode]::Retain) { throw $Script:SaveMsg } }
			$o
		}
		$null = Set-CDCIVerbose -Disable
		Should -Invoke -ModuleName ConfigureDefender Write-MyCatchAudit -Times 0 -Exactly -ParameterFilter { $Source -like '*restore default LogMode*' }
	}

	It 'disable: a DIFFERENT failure restoring the default mode is still recorded' {
		$Script:SaveMsg = 'The log file is in use.'
		Mock -ModuleName ConfigureDefender Get-WinEvent {
			$o = [PSCustomObject]@{ IsEnabled = $true; MaximumSizeInBytes = 134217728; LogMode = [System.Diagnostics.Eventing.Reader.EventLogMode]::Circular }
			$o | Add-Member -MemberType ScriptMethod -Name SaveChanges -Value { if ($this.LogMode -eq [System.Diagnostics.Eventing.Reader.EventLogMode]::Retain) { throw $Script:SaveMsg } }
			$o
		}
		$null = Set-CDCIVerbose -Disable
		Should -Invoke -ModuleName ConfigureDefender Write-MyCatchAudit -Times 1 -Exactly -ParameterFilter { $Source -like '*restore default LogMode*' }
	}
}

# ============================================================
Describe 'GUI scripts only call functions the GUI can actually see' {
	# ConfigureDefenderGUI.ps1 re-imports the module first, so the GUI scope sees only EXPORTED functions. A call to an internal one
	# fails at run time with "The term ... is not recognized" - which is how Test-CDEntryMissing broke the Allowed Applications list.
	BeforeAll {
		$Parse = { param($p) [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$null) }
		$FuncDefs = { param($ast) $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) }
		$ModFiles = Get-ChildItem (Join-Path $Script:ModulePath 'Functions'), (Join-Path $Script:ModulePath 'FunctionsWindows') -Recurse -Filter *.ps1
		$Script:ModDefined = @($ModFiles | ForEach-Object { & $FuncDefs (& $Parse $_.FullName) } | ForEach-Object { $_.Name } | Sort-Object -Unique)
		$Script:Exported   = @((Import-PowerShellDataFile (Join-Path $Script:ModulePath 'ConfigureDefender.psd1')).FunctionsToExport)
		$Script:GuiFiles   = @(Get-ChildItem (Join-Path $Script:ModulePath 'Scripts') -Filter *.ps1)
		$Script:HelpersAst = & $Parse (Join-Path $Script:ModulePath 'Scripts\GUI-Helpers.ps1')
		$Script:Forwarders = @(& $FuncDefs $Script:HelpersAst | ForEach-Object { $_.Name })
		$Script:InternalCalls = @(& { foreach ($F in $Script:GuiFiles)
				{
					(& $Parse $F.FullName).FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object {
						$Name = $_.GetCommandName()
						if ($Name -and $Name -in $Script:ModDefined -and $Name -notin $Script:Exported) { $Name }
					}
				} } | Sort-Object -Unique)
	}

	It 'every module-internal function a GUI script calls has a forwarder defined in GUI-Helpers.ps1' {
		$Missing = @($Script:InternalCalls | Where-Object { $_ -notin $Script:Forwarders })
		($Missing -join ', ') | Should -BeExactly ''
	}

	It 'the GUI really does call internal functions that way (so the check above is not vacuous)' {
		$Script:InternalCalls | Should -Contain 'Write-MyCatchAudit'
		$Script:InternalCalls | Should -Contain 'Test-CDEntryMissing'
	}

	It 'each forwarder reaches the module through Get-Module ConfigureDefender' {
		foreach ($Name in $Script:InternalCalls)
		{
			$Def = $Script:HelpersAst.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name }, $true)
			$Def.Extent.Text | Should -Match 'Get-Module ConfigureDefender'
		}
	}

	Context 'the forwarders work against the real module' {
		BeforeAll {
			foreach ($Name in 'Write-MyCatchAudit', 'Test-CDEntryMissing')
			{
				$Def = $Script:HelpersAst.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name }, $true)
				. ([scriptblock]::Create($Def.Extent.Text))
			}
			$Script:Present = Join-Path $TestDrive 'present.exe'
			Set-Content -LiteralPath $Script:Present -Value 'x'
		}

		It 'Test-CDEntryMissing forwards: an existing file is not missing, a missing one is' {
			Test-CDEntryMissing $Script:Present | Should -BeFalse
			Test-CDEntryMissing (Join-Path $TestDrive 'gone.exe') | Should -BeTrue
		}

		It 'Test-CDEntryMissing forwards: a wildcard entry is never missing' {
			Test-CDEntryMissing 'C:\NoSuchFolder\*' | Should -BeFalse
		}

		It 'Write-MyCatchAudit forwards into the module with the same source and error' {
			Mock -ModuleName ConfigureDefender Write-MyCatchAudit {}
			try { throw 'boom for the forwarder test' } catch { Write-MyCatchAudit -Source 'forwarder test' -ErrorRecord $_ }
			Should -Invoke -ModuleName ConfigureDefender Write-MyCatchAudit -Times 1 -Exactly -ParameterFilter { $Source -eq 'forwarder test' -and $ErrorRecord.Exception.Message -eq 'boom for the forwarder test' }
		}

		It 'Write-MyCatchAudit forwards -Teardown too' {
			Mock -ModuleName ConfigureDefender Write-MyCatchAudit {}
			try { throw 'x' } catch { Write-MyCatchAudit -Source 'teardown test' -ErrorRecord $_ -Teardown }
			Should -Invoke -ModuleName ConfigureDefender Write-MyCatchAudit -Times 1 -Exactly -ParameterFilter { $Source -eq 'teardown test' -and $Teardown }
		}
	}
}

# ============================================================
Describe 'Read-CDEventLog: no match is empty, a real failure is an error' {
	BeforeAll { $Script:Mod = Get-Module ConfigureDefender }

	It 'returns nothing, without error, when no event matches (real log, real Get-WinEvent)' {
		$R = @(& $Script:Mod { Read-CDEventLog -FilterHashtable @{ LogName = 'Application'; Id = 65500; StartTime = (Get-Date) } })
		$R.Count | Should -Be 0
	}

	It 'returns nothing, without error, when the log does not exist (real Get-WinEvent)' {
		$R = @(& $Script:Mod { Read-CDEventLog -FilterHashtable @{ LogName = 'No-Such-Log-For-Test-XYZ'; StartTime = (Get-Date) } })
		$R.Count | Should -Be 0
	}

	It 'throws, and records it, when the failure is anything else (access denied)' {
		Mock -ModuleName ConfigureDefender Write-MyCatchAudit {}
		Mock -ModuleName ConfigureDefender Get-WinEvent {
			throw ([System.Management.Automation.ErrorRecord]::new([System.UnauthorizedAccessException]::new('Attempted to perform an unauthorized operation.'), 'System.UnauthorizedAccessException,Microsoft.PowerShell.Commands.GetWinEventCommand', 'PermissionDenied', $null))
		}
		{ & $Script:Mod { Read-CDEventLog -FilterHashtable @{ LogName = 'Application' } } } | Should -Throw
		Should -Invoke -ModuleName ConfigureDefender Write-MyCatchAudit -Times 1 -Exactly -ParameterFilter { $Source -like 'Read-CDEventLog*' }
	}

	It 'passes -Oldest through and always passes the filter to the log service (never reads the whole log)' {
		Mock -ModuleName ConfigureDefender Get-WinEvent {}
		$null = & $Script:Mod { Read-CDEventLog -FilterHashtable @{ LogName = 'Application'; Id = 1 } -Oldest }
		Should -Invoke -ModuleName ConfigureDefender Get-WinEvent -Times 1 -Exactly -ParameterFilter { $Oldest -and $FilterHashtable.Id -eq 1 }
	}
}

# ============================================================
Describe 'Get-CDEvent: message decoding and server-side filtering' {
	BeforeAll {
		$Script:Since = (Get-Date).AddDays(-1)
		$Script:Accent = [string][char]0xE9
		$Script:Curly  = [string][char]0x2019
		$Script:Dir    = 'C:\Users\Jos' + $Script:Accent + '\Bob' + $Script:Curly + 's'
		$Script:Msg = "Microsoft Defender Exploit Guard has blocked an operation that is not allowed by your IT administrator.`r`n" +
		"For more information please contact your IT administrator.`r`n" +
		" ID: be9ba2d9-53ea-4cdc-84e5-9b1eeee46550`r`n" +
		" Detection time: 2026-10-18T10:00:00.000Z`r`n" +
		" User: HOST\someone`r`n" +
		" Path: $($Script:Dir)\a.exe`r`n" +
		" Process Name: $($Script:Dir)\p.exe`r`n"
		$Script:Event = [PSCustomObject]@{ Id = 1121; TimeCreated = (Get-Date).AddHours(-1); Message = $Script:Msg }
	}

	It 'keeps a non-ASCII path exactly as logged (the old byte round-trip turned e-acute into two wrong characters)' {
		Mock -ModuleName ConfigureDefender Get-WinEvent { $Script:Event }
		$R = @(Get-CDEvent -Filter ASR -Since $Script:Since)
		$R.Count | Should -Be 1
		$R[0].Path | Should -BeExactly ($Script:Dir + '\a.exe')
		$R[0].ProcessName | Should -BeExactly ($Script:Dir + '\p.exe')
		$R[0].ID | Should -BeExactly 'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550'
	}

	It 'does not throw for an event whose message is missing' {
		Mock -ModuleName ConfigureDefender Get-WinEvent { [PSCustomObject]@{ Id = 1121; TimeCreated = (Get-Date); Message = $null } }
		{ Get-CDEvent -Filter ASR -Since $Script:Since } | Should -Not -Throw
	}

	It 'asks the log service for just the wanted event IDs since the start time (no read-everything-then-filter)' {
		Mock -ModuleName ConfigureDefender Get-WinEvent {}
		$null = Get-CDEvent -Filter CFA -Since $Script:Since
		Should -Invoke -ModuleName ConfigureDefender Get-WinEvent -Times 1 -Exactly -ParameterFilter { $FilterHashtable.StartTime -eq $Script:Since -and ($FilterHashtable.Id -contains 1123) -and ($FilterHashtable.Id -contains 1128) -and -not ($FilterHashtable.Id -contains 1121) }
		Should -Invoke -ModuleName ConfigureDefender Get-WinEvent -Times 0 -Exactly -ParameterFilter { -not $FilterHashtable }
	}

	It 'lets a real read failure through instead of reporting an empty list' {
		Mock -ModuleName ConfigureDefender Write-MyCatchAudit {}
		Mock -ModuleName ConfigureDefender Get-WinEvent {
			throw ([System.Management.Automation.ErrorRecord]::new([System.UnauthorizedAccessException]::new('Attempted to perform an unauthorized operation.'), 'System.UnauthorizedAccessException,Microsoft.PowerShell.Commands.GetWinEventCommand', 'PermissionDenied', $null))
		}
		{ Get-CDEvent -Filter ASR -Since $Script:Since } | Should -Throw
	}

	It 'still returns an empty list when nothing matched' {
		Mock -ModuleName ConfigureDefender Get-WinEvent {
			throw ([System.Management.Automation.ErrorRecord]::new([System.Exception]::new('No events were found that match the specified selection criteria.'), 'NoMatchingEventsFound,Microsoft.PowerShell.Commands.GetWinEventCommand', 'ObjectNotFound', $null))
		}
		@(Get-CDEvent -Filter ASR -Since $Script:Since).Count | Should -Be 0
	}
}

# ============================================================
Describe 'Get-CDASRRule lists configured rules this module does not know' {
	It 'matches a configured id regardless of case' {
		Mock -ModuleName ConfigureDefender Get-MpPreference { [PSCustomObject]@{ AttackSurfaceReductionRules_Ids = @('BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550'); AttackSurfaceReductionRules_Actions = @(1) } }
		$R = @(Get-CDASRRule)
		$R.Count | Should -Be 17
		($R | Where-Object GUID -eq 'be9ba2d9-53ea-4cdc-84e5-9b1eeee46550').Action | Should -BeExactly 'Blocked'
	}

	It 'adds an extra row for a configured rule that is not in the table' {
		Mock -ModuleName ConfigureDefender Get-MpPreference { [PSCustomObject]@{ AttackSurfaceReductionRules_Ids = @('be9ba2d9-53ea-4cdc-84e5-9b1eeee46550', '11111111-2222-3333-4444-555555555555'); AttackSurfaceReductionRules_Actions = @(1, 2) } }
		$R = @(Get-CDASRRule)
		$R.Count | Should -Be 18
		$Extra = $R | Where-Object GUID -eq '11111111-2222-3333-4444-555555555555'
		$Extra | Should -Not -BeNullOrEmpty
		$Extra.Action | Should -BeExactly 'Audit'
		$Extra.Description | Should -Match '^Unknown rule'
		$R[-1].GUID | Should -BeExactly '11111111-2222-3333-4444-555555555555'   # the unknown ones come after the known ones
	}

	It 'still returns exactly the 17 known rules, all Not Set, when nothing is configured' {
		Mock -ModuleName ConfigureDefender Get-MpPreference { [PSCustomObject]@{ AttackSurfaceReductionRules_Ids = $null; AttackSurfaceReductionRules_Actions = $null } }
		$R = @(Get-CDASRRule)
		$R.Count | Should -Be 17
		@($R | Where-Object Action -ne 'Not Set').Count | Should -Be 0
	}
}

# ============================================================
Describe 'Set-CDASRRule: GUID validation and one-call add / remove' {
	BeforeEach {
		Mock -ModuleName ConfigureDefender Add-MpPreference {}
		Mock -ModuleName ConfigureDefender Remove-MpPreference {}
		Mock -ModuleName ConfigureDefender Write-MyCatchAudit {}
	}

	It 'refuses a GUID that is not a GUID (including an injection attempt)' {
		{ Set-CDASRRule -GUID 'not-a-guid' -Action Blocked } | Should -Throw
		{ Set-CDASRRule -GUID "x'; Get-Process; '" -Action Blocked } | Should -Throw
		{ Set-CDASRRule -RemoveGUID 'also not a guid' } | Should -Throw
		Should -Invoke -ModuleName ConfigureDefender Add-MpPreference -Times 0 -Exactly
		Should -Invoke -ModuleName ConfigureDefender Remove-MpPreference -Times 0 -Exactly
	}

	It 'accepts a real GUID in either case' {
		Set-CDASRRule -GUID 'BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550' -Action Blocked
		Should -Invoke -ModuleName ConfigureDefender Add-MpPreference -Times 1 -Exactly
	}

	It 'AddAll makes ONE call with all 17 ids and a matching action for each' {
		Set-CDASRRule -AddAll -Action Audit
		Should -Invoke -ModuleName ConfigureDefender Add-MpPreference -Times 1 -Exactly -ParameterFilter { @($AttackSurfaceReductionRules_Ids).Count -eq 17 -and @($AttackSurfaceReductionRules_Actions).Count -eq 17 -and (@($AttackSurfaceReductionRules_Actions | Where-Object { [int]$_ -eq 2 }).Count -eq 17) }
	}

	It 'RemoveAll makes ONE call with every configured id' {
		Mock -ModuleName ConfigureDefender Get-MpPreference { [PSCustomObject]@{ AttackSurfaceReductionRules_Ids = @('be9ba2d9-53ea-4cdc-84e5-9b1eeee46550', '3b576869-a4ec-4529-8536-b80a7769e899') } }
		Set-CDASRRule -RemoveAll
		Should -Invoke -ModuleName ConfigureDefender Remove-MpPreference -Times 1 -Exactly -ParameterFilter { @($AttackSurfaceReductionRules_Ids).Count -eq 2 }
	}

	It 'RemoveAll with nothing configured makes no call' {
		Mock -ModuleName ConfigureDefender Get-MpPreference { [PSCustomObject]@{ AttackSurfaceReductionRules_Ids = $null } }
		Set-CDASRRule -RemoveAll
		Should -Invoke -ModuleName ConfigureDefender Remove-MpPreference -Times 0 -Exactly
	}
}

# ============================================================
Describe 'GUI: ASR tab, Allowed Applications list and filters' {
	BeforeAll {
		$Script:GuiDir = Join-Path $Script:ModulePath 'Scripts'
		$Script:AsrText = Get-Content -LiteralPath (Join-Path $Script:GuiDir 'GUI-Tab-ASR.ps1') -Raw
		$Script:CfaText = Get-Content -LiteralPath (Join-Path $Script:GuiDir 'GUI-Tab-CFA.ps1') -Raw
	}

	It 'the ASR action handler skips the placeholder row and quotes the GUID through the shared helper' {
		$Script:AsrText | Should -Match "Where-Object \{ \`$_\.Tag -ne '\`$placeholder' \}"
		$Script:AsrText | Should -Match 'ConvertTo-CDEscapedArg \(\[string\]\$GUID\)'
	}

	It 'the Allowed Applications view reads a cached existence map instead of testing paths on every filter keystroke' {
		$Ast  = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Script:GuiDir 'GUI-Tab-CFA.ps1'), [ref]$null, [ref]$null)
		$View = $Ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Update-AllowedAppsView' }, $true)
		$View.Extent.Text | Should -Not -Match 'Test-CDEntryMissing'
		$View.Extent.Text | Should -Match 'AllowedAppsMissing'
		$Script:CfaText | Should -Match 'AllowedAppsMissing\[\[string\]\$AppPath\] = \[bool\]\(Test-CDEntryMissing \$AppPath\)'
	}

	It 'typed filters match literally, so a [ in the box no longer raises a wildcard error' {
		foreach ($Name in 'GUI-Tab-CFA.ps1', 'GUI-Tab-ThreatEvents.ps1', 'GUI-Tab-Exclusions.ps1', 'GUI-Helpers.ps1')
		{
			$Text = Get-Content -LiteralPath (Join-Path $Script:GuiDir $Name) -Raw
			($Name + ': ' + ($Text -match '-ilike\s+"\*\$')) | Should -BeExactly ($Name + ': False')
		}
		# and the literal form really does cope with the characters that broke the wildcard form
		[bool]('C:\Apps\Tool[1]\tool.exe'.IndexOf('Tool[1', [StringComparison]::OrdinalIgnoreCase) -ge 0) | Should -BeTrue
		{ 'C:\Apps\Tool[1]\tool.exe' -ilike '*[*' } | Should -Throw
	}
}

# ============================================================
Describe 'GUI script does not hardcode a module version' {
	BeforeAll { $Script:GuiText = Get-Content -LiteralPath (Join-Path $Script:ModulePath 'Scripts\ConfigureDefenderGUI.ps1') -Raw }

	It 'imports the module that sits next to it, not a named version' {
		$Script:GuiText | Should -Not -Match 'Import-Module ConfigureDefender -RequiredVersion'
		$Script:GuiText | Should -Match "Import-Module \(Join-Path \(Split-Path -Parent \`$PSScriptRoot\) 'ConfigureDefender\.psd1'\)"
		Test-Path -LiteralPath (Join-Path (Split-Path -Parent (Join-Path $Script:ModulePath 'Scripts')) 'ConfigureDefender.psd1') | Should -BeTrue
	}

	It 'takes the window title from the loaded module' {
		$Script:GuiText | Should -Match "Form\.Text\s+=\s+'Configure Defender  v\{0\}' -f \(Get-Module ConfigureDefender\)\.Version"
		$Script:GuiText | Should -Not -Match "Configure Defender  v\d"
	}
}

# ============================================================
Describe 'Get-CDSetting and Get-CDThreatAction (table-driven)' {
	It 'returns the 24 settings, once each, in the original order' {
		Mock -ModuleName ConfigureDefender Get-MpPreference { [PSCustomObject]@{ DisableRealtimeMonitoring = $false; PUAProtection = 1; CloudExtendedTimeout = 10 } }
		$S = @(Get-CDSetting)
		$S.Count | Should -Be 24
		@($S.Name | Select-Object -Unique).Count | Should -Be 24
		$S[0].Name | Should -BeExactly 'DisableRealtimeMonitoring'
		$S[-1].Name | Should -BeExactly 'UILockdown'
	}

	It 'gives every setting a name, label, type and description, and the fields its type needs' {
		Mock -ModuleName ConfigureDefender Get-MpPreference { [PSCustomObject]@{ Dummy = 1 } }
		foreach ($S in @(Get-CDSetting))
		{
			$S.Name | Should -Not -BeNullOrEmpty
			$S.FriendlyName | Should -Not -BeNullOrEmpty
			$S.Description | Should -Not -BeNullOrEmpty
			$S.Type | Should -BeIn 'Bool', 'Enum', 'Int'
			if ($S.Type -eq 'Enum') { $S.Options.Count | Should -BeGreaterThan 1 } else { $S.Options | Should -BeNullOrEmpty }
			if ($S.Type -eq 'Int') { $S.Max | Should -BeGreaterThan $S.Min } else { $S.Min | Should -BeNullOrEmpty; $S.Max | Should -BeNullOrEmpty }
		}
	}

	It 'reads each value from the property of the same name' {
		Mock -ModuleName ConfigureDefender Get-MpPreference { [PSCustomObject]@{ DisableArchiveScanning = $true; CloudExtendedTimeout = 37; EnableControlledFolderAccess = 2 } }
		$S = @(Get-CDSetting)
		($S | Where-Object Name -eq 'DisableArchiveScanning').Value | Should -BeTrue
		($S | Where-Object Name -eq 'CloudExtendedTimeout').Value | Should -Be 37
		($S | Where-Object Name -eq 'EnableControlledFolderAccess').Options[2] | Should -BeExactly 'Audit Mode'
	}

	It 'Get-CDThreatAction returns the five levels in order and maps the action labels' {
		Mock -ModuleName ConfigureDefender Get-MpPreference { [PSCustomObject]@{ SevereThreatDefaultAction = 2; HighThreatDefaultAction = 1; ModerateThreatDefaultAction = 0; LowThreatDefaultAction = 99; UnknownThreatDefaultAction = 10 } }
		$A = @(Get-CDThreatAction)
		($A.Level -join ',') | Should -BeExactly 'Severe,High,Moderate,Low,Unknown'
		($A | Where-Object Level -eq 'Severe').Action | Should -BeExactly 'Remove'
		($A | Where-Object Level -eq 'High').Action | Should -BeExactly 'Quarantine'
		($A | Where-Object Level -eq 'Moderate').Action | Should -BeExactly 'Clean'
		($A | Where-Object Level -eq 'Low').Action | Should -BeExactly 'Unknown (99)'
		($A | Where-Object Level -eq 'Unknown').Action | Should -BeExactly 'Block'
		($A | Where-Object Level -eq 'Severe').Property | Should -BeExactly 'SevereThreatDefaultAction'
	}
}

# ============================================================
Describe 'InitialiseModule.psm1 reports the real failure' {
	BeforeAll { $Script:InitPath = Join-Path $Script:ModulePath 'InitialiseModule.psm1' }

	It 'no longer reads the oldest error in the session, writes to the host, or carries the dead Publish-CustomXML' {
		$Text = Get-Content -LiteralPath $Script:InitPath -Raw
		$Text | Should -Not -Match '\$Global:Error\[\$ErrorNumber\]'
		$Text | Should -Not -Match 'Write-Host'
		$Text | Should -Not -Match 'Publish-CustomXML'
	}

	It 'a module with a broken function file fails to import and the report names that file and statement, not an unrelated earlier error' {
		$Dest = Join-Path $TestDrive 'ConfigureDefender\0.4'
		New-Item -ItemType Directory -Path $Dest -Force | Out-Null
		Copy-Item (Join-Path $Script:ModulePath '*') $Dest -Recurse -Exclude 'Tests'
		Add-Content -LiteralPath (Join-Path $Dest 'FunctionsWindows\Get-CDNetworkProtection.ps1') -Value "`r`nFunction Broken-Thing { if ( }"
		$Psd1 = Join-Path $Dest 'ConfigureDefender.psd1'
		$Exe  = (Get-Process -Id $PID).Path
		# a different, unrelated error is raised first in the child process
		$Cmd  = "`$null = Get-Item 'C:\this\path\does\not\exist' -ErrorAction SilentlyContinue; try { Import-Module '$Psd1' -Force -ErrorAction Stop; 'IMPORTED' } catch { 'THROWN: ' + `$_.Exception.Message }"
		$Out  = (& $Exe -NoProfile -Command $Cmd 2>&1 | Out-String)
		$Out | Should -Match 'THROWN: Unable to initialise module: ConfigureDefender'
		$Out | Should -Not -Match 'IMPORTED'
		# Windows PowerShell wraps long warning lines at the console width, which can split a file name; join the lines first
		$Flat = $Out -replace '\r?\n', ''
		$Flat | Should -Match 'Get-CDNetworkProtection\.ps1'
		$Out | Should -Match 'Failing Line : \[Function Broken-Thing \{ if \( \}\]'
		$Flat | Should -Not -Match 'this\\path\\does\\not\\exist'
	}
}

# ============================================================
Describe 'Exclusions tab: one table, one set of functions' {
	BeforeAll {
		$Script:HelpersPath = Join-Path $Script:ModulePath 'Scripts\GUI-Helpers.ps1'
		$Script:HAst = [System.Management.Automation.Language.Parser]::ParseFile($Script:HelpersPath, [ref]$null, [ref]$null)
		# the table, plus the functions that work on it and the validators / quoting helper they call
		$Assign = $Script:HAst.Find({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$script:ExclTypes' }, $true)
		. ([scriptblock]::Create($Assign.Extent.Text))
		foreach ($Name in 'ConvertTo-CDEscapedArg', 'Test-CDExclusionPath', 'Test-CDExclusionProcess', 'Test-CDExclusionExtension', 'Test-CDIPAddress',
			'Get-ExclCommand', 'Get-ExclFiltered', 'Get-ExclValidation', 'Show-ExclDialog')
		{
			$Fn = $Script:HAst.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name }, $true)
			. ([scriptblock]::Create($Fn.Extent.Text))
		}
		$Script:TabText = Get-Content -LiteralPath (Join-Path $Script:ModulePath 'Scripts\GUI-Tab-Exclusions.ps1') -Raw
		$Script:TabAst  = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Script:ModulePath 'Scripts\GUI-Tab-Exclusions.ps1'), [ref]$null, [ref]$null)
	}

	Context 'the category table' {
		It 'lists the five categories in the order the buttons appear' {
			($script:ExclTypes.Keys -join ',') | Should -BeExactly 'ASR,Path,Ext,Proc,IP'
		}

		It 'gives every category everything the tab needs' {
			foreach ($Cat in $script:ExclTypes.Keys)
			{
				$Type = $script:ExclTypes[$Cat]
				foreach ($Key in 'Button', 'Tip', 'Label', 'Column', 'Get', 'Set', 'Param', 'Kind', 'AddTitle', 'EditTitle') { ($Cat + '.' + $Key + ' = ' + [bool]$Type[$Key]) | Should -BeExactly ($Cat + '.' + $Key + ' = True') }
				$Type.Kind | Should -BeIn 'Path', 'Process', 'Extension', 'IP'
				if ($Type.Kind -in 'Extension', 'IP') { $Type.Prompt | Should -Not -BeNullOrEmpty }
			}
		}

		It 'points at real module functions: the getter exists and the setter takes that parameter with -Add and -Remove' {
			$Exp = (Get-Module ConfigureDefender).ExportedFunctions
			foreach ($Cat in $script:ExclTypes.Keys)
			{
				$Type = $script:ExclTypes[$Cat]
				$Exp.ContainsKey($Type.Get) | Should -BeTrue
				$Exp.ContainsKey($Type.Set) | Should -BeTrue
				$P = $Exp[$Type.Set].Parameters
				$P.ContainsKey($Type.Param) | Should -BeTrue
				$P.ContainsKey('Add') | Should -BeTrue
				$P.ContainsKey('Remove') | Should -BeTrue
			}
		}
	}

	Context 'Get-ExclCommand' {
		It 'builds the command for each category and verb' {
			Get-ExclCommand -Category Path -Value 'C:\a\b' -Verb Add        | Should -BeExactly "Set-CDExclusionPath -Path 'C:\a\b' -Add"
			Get-ExclCommand -Category ASR  -Value 'C:\a\b' -Verb Remove     | Should -BeExactly "Set-CDASRExclusion -Path 'C:\a\b' -Remove"
			Get-ExclCommand -Category Ext  -Value '.tmp'   -Verb Add        | Should -BeExactly "Set-CDExclusionExtension -Extension '.tmp' -Add"
			Get-ExclCommand -Category Proc -Value 'app.exe' -Verb Remove    | Should -BeExactly "Set-CDExclusionProcess -Process 'app.exe' -Remove"
			Get-ExclCommand -Category IP   -Value '10.0.0.0/8' -Verb Add    | Should -BeExactly "Set-CDExclusionIpAddress -IpAddress '10.0.0.0/8' -Add"
		}

		It 'refuses an unknown category and an unknown verb' {
			{ Get-ExclCommand -Category Nope -Value 'x' -Verb Add } | Should -Throw
			{ Get-ExclCommand -Category Path -Value 'x' -Verb Delete } | Should -Throw
		}

		It 'refuses a value with a control character' {
			{ Get-ExclCommand -Category Path -Value "C:\a`nb" -Verb Add } | Should -Throw
		}

		It 'survives the parse the server does, for apostrophes, curly quotes and an injection attempt' {
			# a stand-in for the Set-CD* functions that hands back the value it was given
			function Show-Parsed { param($Path, $Process, $Extension, $IpAddress, [switch]$Add, [switch]$Remove) @($Path, $Process, $Extension, $IpAddress | Where-Object { $null -ne $_ })[0] }
			$Curly = [string][char]0x2019
			foreach ($Cat in 'Path', 'ASR', 'Proc', 'Ext', 'IP')
			{
				foreach ($Value in "C:\Bob's\a.exe", "C:\Bob${Curly}s\a.exe", "x${Curly}; Get-Process; ${Curly}y")
				{
					$Cmd = (Get-ExclCommand -Category $Cat -Value $Value -Verb Add) -replace '^Set-CD\w+', 'Show-Parsed'
					& ([scriptblock]::Create($Cmd)) | Should -BeExactly $Value
				}
			}
		}
	}

	Context 'Get-ExclFiltered' {
		It 'matches literally and ignores case' {
			$Items = 'C:\Apps\Tool[1]\tool.exe', 'C:\Other\thing.exe', 'D:\Data\x.tmp'
			@(Get-ExclFiltered $Items 'tool[1]').Count | Should -Be 1
			@(Get-ExclFiltered $Items 'OTHER').Count   | Should -Be 1
			@(Get-ExclFiltered $Items '*').Count       | Should -Be 0     # a literal *, not a wildcard
			@(Get-ExclFiltered $Items '[').Count       | Should -Be 1     # a literal [, no wildcard error
		}

		It 'returns everything for an empty filter and nothing for no match' {
			$Items = 'a', 'b', 'c'
			@(Get-ExclFiltered $Items '').Count | Should -Be 3
			@(Get-ExclFiltered $Items 'zzz').Count | Should -Be 0
		}
	}

	Context 'Get-ExclValidation' {
		It 'accepts good values, including a UNC path' {
			Get-ExclValidation -Category Path -Value '\\server\share\x' | Should -BeNullOrEmpty
			Get-ExclValidation -Category ASR  -Value 'C:\Apps\x.exe'    | Should -BeNullOrEmpty
			Get-ExclValidation -Category Proc -Value 'app.exe'          | Should -BeNullOrEmpty
			Get-ExclValidation -Category Ext  -Value '.tmp'             | Should -BeNullOrEmpty
			Get-ExclValidation -Category IP   -Value '192.168.1.1'      | Should -BeNullOrEmpty
		}

		It 'rejects bad values with a title and a message that names the value' {
			$P = Get-ExclValidation -Category Path -Value 'relative\x'
			$P.Title | Should -BeExactly 'Invalid Path'
			$P.Message | Should -Match 'relative\\x'
			(Get-ExclValidation -Category Proc -Value 'a|b').Title | Should -BeExactly 'Invalid Process'
			(Get-ExclValidation -Category Ext  -Value 'a b').Title | Should -BeExactly 'Invalid Extension'
			(Get-ExclValidation -Category IP   -Value 'nope').Title | Should -BeExactly 'Invalid IP Address'
		}
	}

	Context 'Show-ExclDialog' {
		BeforeAll {
			function Show-ExclPathDialog ([string]$Title, [string]$Initial = '') { "PATH|$Title|$Initial" }
			function Show-ExclProcessDialog ([string]$Title, [string]$Initial = '') { "PROC|$Title|$Initial" }
			function Show-SimpleTextDialog ([string]$Title, [string]$Prompt, [string]$Initial = '') { "TEXT|$Title|$Prompt|$Initial" }
		}

		It 'picks the dialog and title for the category and mode' {
			Show-ExclDialog -Category ASR  -Mode Add                      | Should -BeExactly 'PATH|Add ASR Exclusion|'
			Show-ExclDialog -Category Path -Mode Edit -Initial 'C:\old'   | Should -BeExactly 'PATH|Edit Exclusion Path|C:\old'
			Show-ExclDialog -Category Proc -Mode Add                      | Should -BeExactly 'PROC|Add Exclusion Process|'
			Show-ExclDialog -Category Ext  -Mode Edit -Initial '.tmp'     | Should -BeExactly 'TEXT|Edit Exclusion Extension|File extension to exclude (e.g. .tmp or tmp):|.tmp'
			Show-ExclDialog -Category IP   -Mode Add                      | Should -BeExactly 'TEXT|Add Exclusion IP Address|IP address to exclude (IPv4 or IPv6):|'
		}
	}

	Context 'the tab script' {
		It 'no longer carries five copies of anything: the per-category functions are gone and the single ones exist' {
			foreach ($Old in 'Update-ExclASRView', 'Update-ExclProcView', 'Update-ExclPathView', 'Update-ExclExtView', 'Update-ExclIPView') { $Script:TabText | Should -Not -Match $Old }
			foreach ($New in 'Update-ExclView', 'Invoke-ExclRefresh', 'Edit-ExclEntry', 'Switch-ExclCategory') { $Script:TabText | Should -Match ('function ' + $New) }
			$Script:TabText | Should -Not -Match '-ilike'
			$Script:TabText | Should -Not -Match '-replace "''"'
		}

		It 'the main script switches the Exclusions view through the single function' {
			$Main = Get-Content -LiteralPath (Join-Path $Script:ModulePath 'Scripts\ConfigureDefenderGUI.ps1') -Raw
			$Main | Should -Match 'Update-ExclView \$script:ExclCategory'
			$Main | Should -Not -Match 'Update-Excl(ASR|Proc|Path|Ext|IP)View'
		}

		It 'editing adds the new entry before it removes the old one' {
			$Fn = $Script:TabAst.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Edit-ExclEntry' }, $true)
			$Text = $Fn.Extent.Text
			$Add = $Text.IndexOf("'Add'"); $Remove = $Text.IndexOf("'Remove'")
			$Add | Should -BeGreaterThan -1
			$Remove | Should -BeGreaterThan $Add
		}

		It 'wires the edit handler and the size handler once, in the loop that builds the list views' {
			([regex]::Matches($Script:TabText, 'Add_DoubleClick')).Count | Should -Be 1
			([regex]::Matches($Script:TabText, 'Edit-ExclEntry \$this\.Tag')).Count | Should -Be 1
		}

		It 'skips the placeholder row when editing and when removing' {
			([regex]::Matches($Script:TabText, "\`$placeholder")).Count | Should -BeGreaterOrEqual 2
		}
	}
}

# ============================================================
Describe 'GUI small fixes: History custom date, error status text, cursor reset' {
	BeforeAll {
		$Script:GuiDir = Join-Path $Script:ModulePath 'Scripts'
		$HistAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Script:GuiDir 'GUI-Tab-History.ps1'), [ref]$null, [ref]$null)
		$Fn = $HistAst.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-HistSinceDate' }, $true)
		. ([scriptblock]::Create($Fn.Extent.Text))
		$HelpAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Script:GuiDir 'GUI-Helpers.ps1'), [ref]$null, [ref]$null)
		$Fn2 = $HelpAst.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Write-OperationError' }, $true)
		. ([scriptblock]::Create($Fn2.Extent.Text))
	}

	It 'History: "Custom Date..." reuses the date already picked instead of asking on every refresh' {
		$TsCbHistSince = [PSCustomObject]@{ SelectedItem = 'Custom Date...' }
		$script:HistAskDate    = $false
		$script:HistCustomDate = [datetime]'2026-01-02'
		Get-HistSinceDate | Should -Be ([datetime]'2026-01-02')
	}

	It 'History: the other choices are unchanged' {
		$TsCbHistSince = [PSCustomObject]@{ SelectedItem = 'All Time' }
		Get-HistSinceDate | Should -BeNullOrEmpty
		$TsCbHistSince = [PSCustomObject]@{ SelectedItem = 'Last 7 Days' }
		((Get-Date) - (Get-HistSinceDate)).TotalDays | Should -BeGreaterThan 6.9
	}

	It 'History: picking a different "since" choice makes it ask again' {
		$Text = Get-Content -LiteralPath (Join-Path $Script:GuiDir 'GUI-Tab-History.ps1') -Raw
		$Text | Should -Match 'Add_SelectedIndexChanged\(\{ \$script:HistAskDate = \$true;'
	}

	It 'Write-OperationError tells the user WHERE the details are, and writes them there' {
		$OldTemp = $env:TEMP
		try
		{
			$env:TEMP = $TestDrive
			$StatusLabel = [PSCustomObject]@{ Text = '' }
			try { throw 'something went wrong for the test' } catch { Write-OperationError -Operation 'Unit test' -ErrorInfo $_ }
			$Log = Get-ChildItem -LiteralPath $TestDrive -Filter 'ConfigureDefender-*.log' | Select-Object -First 1
			$Log | Should -Not -BeNullOrEmpty
			$StatusLabel.Text | Should -Match ([regex]::Escape($Log.FullName))
			(Get-Content -LiteralPath $Log.FullName -Raw) | Should -Match 'something went wrong for the test'
		}
		finally { $env:TEMP = $OldTemp }
	}

	It 'every place that clears the wait cursor property also resets the real cursor' {
		foreach ($File in Get-ChildItem -LiteralPath $Script:GuiDir -Filter *.ps1)
		{
			$Text  = Get-Content -LiteralPath $File.FullName -Raw
			$Prop  = ([regex]::Matches($Text, 'UseWaitCursor = \$false')).Count
			$Reset = ([regex]::Matches($Text, '\[System\.Windows\.Forms\.Cursor\]::Current = \[System\.Windows\.Forms\.Cursors\]::Default')).Count
			($File.Name + ': ' + $Prop + ' vs ' + $Reset) | Should -BeExactly ($File.Name + ': ' + $Prop + ' vs ' + $Prop)
		}
	}

	It 'the tab region labels run 1 to 7 in the order the tabs appear' {
		$Expected = [ordered]@{ 'GUI-Tab-Settings.ps1' = 'Tab 1'; 'GUI-Tab-ASR.ps1' = 'Tab 2'; 'GUI-Tab-Exclusions.ps1' = 'Tab 3'; 'GUI-Tab-CFA.ps1' = 'Tab 4' }
		foreach ($Name in $Expected.Keys)
		{
			(Get-Content -LiteralPath (Join-Path $Script:GuiDir $Name) -TotalCount 1) | Should -Match ('^#region ' + $Expected[$Name] + ' - ')
		}
	}
}

# ============================================================
Describe 'Busy cursor helpers' {
	BeforeAll {
		Add-Type -AssemblyName System.Windows.Forms
		$Script:GuiDir = Join-Path $Script:ModulePath 'Scripts'
		$Ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Script:GuiDir 'GUI-Helpers.ps1'), [ref]$null, [ref]$null)
		foreach ($Name in 'Enter-GuiBusy', 'Exit-GuiBusy')
		{
			$Fn = $Ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name }, $true)
			. ([scriptblock]::Create($Fn.Extent.Text))
		}
	}

	It 'Enter-GuiBusy sets the status text (default "Loading...") and the busy flag' {
		$StatusLabel = [PSCustomObject]@{ Text = '' }
		$Form        = [PSCustomObject]@{ UseWaitCursor = $false }
		Enter-GuiBusy
		$StatusLabel.Text | Should -BeExactly 'Loading...'
		$Form.UseWaitCursor | Should -BeTrue
		Enter-GuiBusy 'Reading the event log...'
		$StatusLabel.Text | Should -BeExactly 'Reading the event log...'
	}

	It 'Exit-GuiBusy clears the busy flag and resets the real cursor' {
		$Form = [PSCustomObject]@{ UseWaitCursor = $true }
		Add-Type -AssemblyName System.Windows.Forms
		[System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::WaitCursor
		Exit-GuiBusy
		$Form.UseWaitCursor | Should -BeFalse
		[System.Windows.Forms.Cursor]::Current | Should -Be ([System.Windows.Forms.Cursors]::Default)
	}

	It 'no GUI script repeats the pattern any more: the busy flag is touched only inside the two helpers' {
		foreach ($File in Get-ChildItem -LiteralPath $Script:GuiDir -Filter *.ps1)
		{
			$Text = Get-Content -LiteralPath $File.FullName -Raw
			$Raw  = ([regex]::Matches($Text, 'UseWaitCursor = \$(true|false)')).Count
			$Expected = if ($File.Name -eq 'GUI-Helpers.ps1') { 2 } else { 0 }
			($File.Name + ': ' + $Raw) | Should -BeExactly ($File.Name + ': ' + $Expected)
		}
	}

	It 'every handler that enters the busy state also leaves it' {
		foreach ($File in Get-ChildItem -LiteralPath $Script:GuiDir -Filter *.ps1)
		{
			$FileAst = [System.Management.Automation.Language.Parser]::ParseFile($File.FullName, [ref]$null, [ref]$null)
			$Enter = @($FileAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Enter-GuiBusy' }, $true)).Count   # real calls only: not comments, not the definition
			$Exit  = @($FileAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Exit-GuiBusy' }, $true)).Count
			($File.Name + ': enter ' + $Enter + ' / exit ' + $Exit) | Should -BeExactly ($File.Name + ': enter ' + $Enter + ' / exit ' + $Enter)
		}
	}

	It 'the busy state is left in a finally block, so an error or a return cannot leave the cursor spinning' {
		foreach ($Name in 'GUI-Tab-ASR.ps1', 'GUI-Tab-Settings.ps1', 'GUI-Tab-History.ps1', 'GUI-Tab-CFA.ps1', 'GUI-Tab-ThreatEvents.ps1', 'GUI-Tab-Exclusions.ps1', 'ConfigureDefenderGUI.ps1')
		{
			$Ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Script:GuiDir $Name), [ref]$null, [ref]$null)
			$Calls = $Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Exit-GuiBusy' }, $true)
			foreach ($C in $Calls)
			{
				$P = $C.Parent; $InFinally = $false
				while ($P) { if ($P -is [System.Management.Automation.Language.TryStatementAst]) { if ($P.Finally -and $P.Finally.Extent.StartOffset -le $C.Extent.StartOffset -and $P.Finally.Extent.EndOffset -ge $C.Extent.EndOffset) { $InFinally = $true }; break }; $P = $P.Parent }
				($Name + ' line ' + $C.Extent.StartLineNumber + ': ' + $InFinally) | Should -BeExactly ($Name + ' line ' + $C.Extent.StartLineNumber + ': True')
			}
		}
	}
}