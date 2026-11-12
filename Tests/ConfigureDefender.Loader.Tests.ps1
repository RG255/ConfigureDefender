#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }
<#
	.SYNOPSIS
	Pester tests for the module loader (InitialiseModule.psm1): a variable that cannot be created at import stops the import.

	.DESCRIPTION
	Child processes import a temp copy of the module; nothing is elevated, Defender settings are never read or written,
	and the real module folder is never modified. The loader has Windows-only function loading, so there are no
	Linux/macOS loops to check.
#>

Describe 'ConfigureDefender loader - variable creation failure' {

	BeforeAll {
		$script:ModuleRoot = Split-Path -Path $PSScriptRoot -Parent
		$script:Exe        = (Get-Process -Id $PID).Path
		$script:LoaderPath = Join-Path -Path $script:ModuleRoot -ChildPath 'InitialiseModule.psm1'

		function script:New-Fixture {
			param([string]$Name, [switch]$BreakVariable)
			$dest = Join-Path -Path $TestDrive -ChildPath ('{0}\ConfigureDefender\0.6' -f $Name)
			$null = New-Item -Path $dest -ItemType Directory -Force
			Get-ChildItem -LiteralPath $script:ModuleRoot -Force | Where-Object { $_.Name -notin 'Tests', '.git', '.claude' } |
				Copy-Item -Destination $dest -Recurse -Force
			if ($BreakVariable)
			{
				# An unknown variable Option makes New-Variable throw.
				$def = Join-Path -Path $dest -ChildPath 'Functions\DefineVariables.ps1'
				Add-Content -LiteralPath $def -Value "`r`nPublish-Variable -Variables ([Ordered]@{ N99Probe = @{ S14ProbeVar = @{ Value = 1; Scope = 'Script'; Option = 'NoSuchOption' } } })`r`n"
			}
			Join-Path -Path $dest -ChildPath 'ConfigureDefender.psd1'
		}

		function script:Invoke-ChildImport {
			param([string]$Psd1)
			$cmd = "`$ErrorActionPreference='Stop'; try { `$m = Import-Module -Name '$Psd1' -Force -PassThru -WarningAction SilentlyContinue; 'RESULT cmds={0} vars={1}' -f `$m.ExportedCommands.Count, `$m.ExportedVariables.Count } catch { 'IMPORTFAILED ' + `$_.Exception.Message }"
			$out = & $script:Exe -NoProfile -NonInteractive -Command $cmd 2>&1 | Out-String
			[pscustomobject]@{ Output = $out }
		}
	}

	It 'a normal import succeeds and exports the full command and variable sets' {
		$r = Invoke-ChildImport -Psd1 (New-Fixture -Name 'ok')
		$r.Output | Should -Match 'RESULT cmds=44 vars=7'
	}

	It 'a variable that cannot be created fails the import with a message naming the module and the variable' {
		$r = Invoke-ChildImport -Psd1 (New-Fixture -Name 'bad' -BreakVariable)
		$r.Output | Should -Not -Match 'RESULT cmds='
		$r.Output | Should -Match 'IMPORTFAILED'
		$r.Output | Should -Match 'ConfigureDefender'
		$r.Output | Should -Match 'S14ProbeVar'
	}

	It 'Publish-Variable catch rethrows with context and does not only warn or write information' {
		$errs = $null
		$ast = [System.Management.Automation.Language.Parser]::ParseFile($script:LoaderPath, [ref]$null, [ref]$errs)
		$fn = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Publish-Variable' }, $true)
		$catch = $fn.FindAll({ param($n) $n -is [System.Management.Automation.Language.CatchClauseAst] }, $true) | Select-Object -Last 1
		$catch.Body.Extent.Text | Should -Match '\bthrow\b'
		$catch.Body.Extent.Text | Should -Match '\$ModuleName'
		$catch.Body.Extent.Text | Should -Match '\$Item'
		$catch.Body.Extent.Text | Should -Not -Match 'Write-Information'
	}
}
