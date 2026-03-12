#requires -Version 5.0
<#
    .SYNOPSIS
    Functional integration tests for the ConfigureDefender module.

    .DESCRIPTION
    Runs ConfigureDefender operations against the live Defender service.
    Read operations run directly (non-elevated). Write operations are dispatched
    via an elevated NamedPipe server opened on first use and closed in the
    finally block - matching the GUI's own lifetime pattern.

    Safe write tests perform round-trips: read the current setting, apply the
    same value, then verify no net change was made.

    .PARAMETER Test
    One or more test names to run. Defaults to all tests.
    Valid values: ASRRules, ASRExclusions, AllowedApps, NetworkProtection,
                  ControlledFolders, CFAState, Events, SetNP, SetCFA, SetASRRule

    .PARAMETER SkipWriteTests
    Skip all tests that open a pipe session and send write commands.
    Useful when running without an available UAC prompt.

    .NOTES
    Must be run from PowerShell 5.1 (Windows PowerShell) - the same host that
    loads the ConfigureDefender module. Run as a standard user; write tests
    will trigger a UAC elevation prompt to start the pipe server.

    Do NOT use em-dashes in this file. Use a regular hyphen (-) only.
#>
[CmdletBinding()]
param (
    [ValidateSet('ASRRules', 'ASRExclusions', 'AllowedApps', 'NetworkProtection',
        'ControlledFolders', 'CFAState', 'Events', 'SetNP', 'SetCFA', 'SetASRRule')]
    [String[]]$Test = @('ASRRules', 'ASRExclusions', 'AllowedApps', 'NetworkProtection',
        'ControlledFolders', 'CFAState', 'Events', 'SetNP', 'SetCFA', 'SetASRRule'),
    [Switch]$SkipWriteTests
)

#region Module load
$ModulePath = Split-Path -Parent $PSScriptRoot
Remove-Module -Name ConfigureDefender -Force -ErrorAction SilentlyContinue
Import-Module "$ModulePath\ConfigureDefender.psd1" -Force -ErrorAction Stop
Write-Host 'ConfigureDefender module loaded.' -ForegroundColor Green
#endregion

#region Helpers
function Write-TestHeader
{
    param([string]$Name)
    Write-Host ("`n[Test] {0}" -f $Name) -ForegroundColor Cyan
}

function Get-SRP
{
    # Retrieve the module-scope SendRequestParams from inside the module
    (Get-Module ConfigureDefender).Invoke({ $script:CDSendRequestParams })
}

function Invoke-PipeCommand
{
    <#
        .SYNOPSIS
        Send a command string to the elevated pipe server and return the result object.
        Sets $script:LastPipeError to the error string (empty string if none).
    #>
    param(
        [string]$Command,
        [hashtable]$SRP
    )
    $SRP.'DataObject' = $Command | Send-Request @SRP -NoExitOnError
    $script:LastPipeError = $SRP.'DataObject'.Error
    $SRP.'DataObject'.Result
}

$script:LastPipeError = ''
#endregion

$Results       = [ordered]@{}
$WriteTests    = @('SetNP', 'SetCFA', 'SetASRRule')
$PipeOpened    = $false

try
{
    # ----------------------------------------------------------------
    # Read tests - no elevation required
    # ----------------------------------------------------------------

    if ($Test -contains 'ASRRules')
    {
        Write-TestHeader 'ASRRules - Get-CDASRRules'
        try
        {
            $Rules = Get-CDASRRules
            if ($null -eq $Rules)
            { throw 'Get-CDASRRules returned null' }
            $Count = @($Rules).Count
            Write-Host ("  Rules returned: {0}" -f $Count) -ForegroundColor Gray
            foreach ($Rule in $Rules)
            {
                Write-Host ("  {0,-10} {1}  {2}" -f $Rule.Action, $Rule.GUID, $Rule.Description) -ForegroundColor Gray
            }
            $Results['ASRRules'] = 'PASS'
        }
        catch
        {
            $Results['ASRRules'] = "FAIL: $_"
            Write-Host ("  [FAIL] $_") -ForegroundColor Red
        }
    }

    if ($Test -contains 'ASRExclusions')
    {
        Write-TestHeader 'ASRExclusions - Get-CDASRExclusions'
        try
        {
            $Excl = Get-CDASRExclusions
            $Count = if ($null -eq $Excl) { 0 } else { @($Excl).Count }
            Write-Host ("  Exclusions: {0}" -f $Count) -ForegroundColor Gray
            foreach ($E in $Excl) { Write-Host ("    {0}" -f $E) -ForegroundColor Gray }
            $Results['ASRExclusions'] = 'PASS'
        }
        catch
        {
            $Results['ASRExclusions'] = "FAIL: $_"
            Write-Host ("  [FAIL] $_") -ForegroundColor Red
        }
    }

    if ($Test -contains 'AllowedApps')
    {
        Write-TestHeader 'AllowedApps - Get-CDAllowedApplications'
        try
        {
            $Apps = Get-CDAllowedApplications
            $Count = if ($null -eq $Apps) { 0 } else { @($Apps).Count }
            Write-Host ("  Allowed applications: {0}" -f $Count) -ForegroundColor Gray
            foreach ($A in $Apps) { Write-Host ("    {0}" -f $A) -ForegroundColor Gray }
            $Results['AllowedApps'] = 'PASS'
        }
        catch
        {
            $Results['AllowedApps'] = "FAIL: $_"
            Write-Host ("  [FAIL] $_") -ForegroundColor Red
        }
    }

    if ($Test -contains 'NetworkProtection')
    {
        Write-TestHeader 'NetworkProtection - Get-CDNetworkProtection'
        try
        {
            $NP = Get-CDNetworkProtection
            if ($null -eq $NP)
            { throw 'Get-CDNetworkProtection returned null' }
            Write-Host ("  Network Protection state: {0}" -f $NP) -ForegroundColor Gray
            $Results['NetworkProtection'] = 'PASS'
        }
        catch
        {
            $Results['NetworkProtection'] = "FAIL: $_"
            Write-Host ("  [FAIL] $_") -ForegroundColor Red
        }
    }

    if ($Test -contains 'ControlledFolders')
    {
        Write-TestHeader 'ControlledFolders - Get-CDControlledFolders'
        try
        {
            $Folders = Get-CDControlledFolders
            $Count = if ($null -eq $Folders) { 0 } else { @($Folders).Count }
            Write-Host ("  Protected folders: {0}" -f $Count) -ForegroundColor Gray
            foreach ($F in $Folders) { Write-Host ("    {0}" -f $F) -ForegroundColor Gray }
            $Results['ControlledFolders'] = 'PASS'
        }
        catch
        {
            $Results['ControlledFolders'] = "FAIL: $_"
            Write-Host ("  [FAIL] $_") -ForegroundColor Red
        }
    }

    if ($Test -contains 'CFAState')
    {
        Write-TestHeader 'CFAState - Get-CDControlledFolderAccess'
        try
        {
            $CFA = Get-CDControlledFolderAccess
            if ($null -eq $CFA)
            { throw 'Get-CDControlledFolderAccess returned null' }
            Write-Host ("  CFA state: {0}" -f $CFA) -ForegroundColor Gray
            $Results['CFAState'] = 'PASS'
        }
        catch
        {
            $Results['CFAState'] = "FAIL: $_"
            Write-Host ("  [FAIL] $_") -ForegroundColor Red
        }
    }

    if ($Test -contains 'Events')
    {
        Write-TestHeader 'Events - Get-CDEvents'
        try
        {
            $Events = Get-CDEvents
            $Count = if ($null -eq $Events) { 0 } else { @($Events).Count }
            Write-Host ("  Events returned: {0}" -f $Count) -ForegroundColor Gray
            $Results['Events'] = 'PASS'
        }
        catch
        {
            $Results['Events'] = "FAIL: $_"
            Write-Host ("  [FAIL] $_") -ForegroundColor Red
        }
    }

    # ----------------------------------------------------------------
    # Write tests - require elevated pipe session
    # ----------------------------------------------------------------

    $WriteTestsRequested = ($Test | Where-Object { $WriteTests -contains $_ }).Count -gt 0

    if ($WriteTestsRequested -and -not $SkipWriteTests)
    {
        Write-Host "`nOpening elevated pipe session for write tests..." -ForegroundColor Yellow
        Open-CDPipeSession
        $PipeOpened = $true
        Write-Host 'Pipe session opened.' -ForegroundColor Green

        $SRP = Get-SRP
        if ($null -eq $SRP)
        { throw 'CDSendRequestParams is null after Open-CDPipeSession' }

        # SetNP - read current state, set same state (round-trip, no net change)
        if ($Test -contains 'SetNP')
        {
            Write-TestHeader 'SetNP - Set-CDNetworkProtection round-trip'
            try
            {
                $CurrentNP = Get-CDNetworkProtection
                Write-Host ("  Current NP state: {0}" -f $CurrentNP) -ForegroundColor Gray

                $SetCmd = switch ($CurrentNP)
                {
                    'Enabled'  { 'Set-CDNetworkProtection -Enable' }
                    'Audit'    { 'Set-CDNetworkProtection -Audit' }
                    'Disabled' { 'Set-CDNetworkProtection -Disable' }
                    default    { throw "Unknown NP state: $CurrentNP" }
                }
                Write-Host ("  Sending: {0}" -f $SetCmd) -ForegroundColor Gray
                $Res = Invoke-PipeCommand -Command $SetCmd -SRP $SRP
                if ($script:LastPipeError)
                { throw "Pipe error: $($script:LastPipeError)" }

                $AfterNP = Get-CDNetworkProtection
                if ($AfterNP -ne $CurrentNP)
                { throw "State changed: expected '$CurrentNP', got '$AfterNP'" }
                Write-Host ("  NP state after set: {0} (unchanged - correct)" -f $AfterNP) -ForegroundColor Gray
                $Results['SetNP'] = 'PASS'
            }
            catch
            {
                $Results['SetNP'] = "FAIL: $_"
                Write-Host ("  [FAIL] $_") -ForegroundColor Red
            }
        }

        # SetCFA - read current state, set same state (round-trip, no net change)
        if ($Test -contains 'SetCFA')
        {
            Write-TestHeader 'SetCFA - Set-CDControlledFolderAccess round-trip'
            try
            {
                $CurrentCFA = Get-CDControlledFolderAccess
                Write-Host ("  Current CFA state: {0}" -f $CurrentCFA) -ForegroundColor Gray

                $SetCmd = switch ($CurrentCFA)
                {
                    'Enabled'  { 'Set-CDControlledFolderAccess -Enable' }
                    'Audit'    { 'Set-CDControlledFolderAccess -Audit' }
                    'Disabled' { 'Set-CDControlledFolderAccess -Disable' }
                    default    { throw "Unknown CFA state: $CurrentCFA" }
                }
                Write-Host ("  Sending: {0}" -f $SetCmd) -ForegroundColor Gray
                $Res = Invoke-PipeCommand -Command $SetCmd -SRP $SRP
                if ($script:LastPipeError)
                { throw "Pipe error: $($script:LastPipeError)" }

                $AfterCFA = Get-CDControlledFolderAccess
                if ($AfterCFA -ne $CurrentCFA)
                { throw "State changed: expected '$CurrentCFA', got '$AfterCFA'" }
                Write-Host ("  CFA state after set: {0} (unchanged - correct)" -f $AfterCFA) -ForegroundColor Gray
                $Results['SetCFA'] = 'PASS'
            }
            catch
            {
                $Results['SetCFA'] = "FAIL: $_"
                Write-Host ("  [FAIL] $_") -ForegroundColor Red
            }
        }

        # SetASRRule - pick first configured rule, set to same action (round-trip)
        if ($Test -contains 'SetASRRule')
        {
            Write-TestHeader 'SetASRRule - Set-CDASRRule round-trip'
            try
            {
                $Rules = Get-CDASRRules | Where-Object { $_.Action -ne 'Not Set' }
                if (-not $Rules)
                { throw 'No configured ASR rules found to test round-trip against' }

                $Rule = @($Rules)[0]
                Write-Host ("  Using rule: {0} ({1})" -f $Rule.GUID, $Rule.Action) -ForegroundColor Gray

                $SetCmd = 'Set-CDASRRule -GUID "{0}" -Action {1}' -f $Rule.GUID, $Rule.Action
                Write-Host ("  Sending: {0}" -f $SetCmd) -ForegroundColor Gray
                $Res = Invoke-PipeCommand -Command $SetCmd -SRP $SRP
                if ($script:LastPipeError)
                { throw "Pipe error: $($script:LastPipeError)" }

                $AfterRules = Get-CDASRRules | Where-Object { $_.GUID -eq $Rule.GUID }
                $AfterAction = @($AfterRules)[0].Action
                if ($AfterAction -ne $Rule.Action)
                { throw "Action changed: expected '$($Rule.Action)', got '$AfterAction'" }
                Write-Host ("  Rule action after set: {0} (unchanged - correct)" -f $AfterAction) -ForegroundColor Gray
                $Results['SetASRRule'] = 'PASS'
            }
            catch
            {
                $Results['SetASRRule'] = "FAIL: $_"
                Write-Host ("  [FAIL] $_") -ForegroundColor Red
            }
        }
    }
    elseif ($WriteTestsRequested -and $SkipWriteTests)
    {
        foreach ($T in ($Test | Where-Object { $WriteTests -contains $_ }))
        {
            $Results[$T] = 'SKIPPED'
            Write-Host ("  [{0}] Skipped (SkipWriteTests)" -f $T) -ForegroundColor Yellow
        }
    }
}
finally
{
    if ($PipeOpened)
    {
        Close-CDPipeSession
        Write-Host 'Pipe session closed.' -ForegroundColor Green
    }
}

# Results summary
$PassCount    = ($Results.Values | Where-Object { $_ -eq 'PASS' }).Count
$SkipCount    = ($Results.Values | Where-Object { $_ -eq 'SKIPPED' }).Count
$TotalRun     = $Results.Count - $SkipCount

Write-Host ("`n===== ConfigureDefender Integration Test Results =====") -ForegroundColor Cyan
foreach ($Name in $Results.Keys)
{
    $Val   = $Results[$Name]
    $Color = switch ($Val)
    {
        'PASS'    { 'Green' }
        'SKIPPED' { 'Yellow' }
        default   { 'Red' }
    }
    Write-Host ('  {0,-20} : {1}' -f $Name, $Val) -ForegroundColor $Color
}
$AllPassed  = $PassCount -eq $TotalRun
$TotalColor = if ($AllPassed) { 'Green' } else { 'Red' }
Write-Host ("`nTotal: {0}/{1} passed{2}" -f $PassCount, $TotalRun,
    $(if ($SkipCount -gt 0) { ", $SkipCount skipped" } else { '' })) -ForegroundColor $TotalColor
