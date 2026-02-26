<#
.SYNOPSIS
    Pester tests for Start-LitigationHold function
.DESCRIPTION
    Validates that Start-LitigationHold processes users correctly,
    handles errors gracefully, and produces expected outputs.
.NOTES
    Run with: Invoke-Pester -Path ./tests/Start-LitigationHold.Tests.ps1
#>

BeforeAll {
	# Load test configuration
    . $(Join-Path $PSScriptRoot 'configs\Load-TestConfig1.ps1')
	
	# Import the function
    $functionPath = Join-Path $RepoRoot 'src\Start-LitigationHold.psm1'
    Write-Host "Loading function from: $functionPath"
    
    if (-not (Test-Path $functionPath)) {
        Write-Error 'Function file not found at: $functionPath'
        throw 'Function file missing'
    }
    
    Import-Module $functionPath -Force
    
    # Use environment temp with fallback
    $tempDir = if ($env:TEMP) { $env:TEMP } else { $env:TMPDIR }
    if (-not $tempDir) { $tempDir = '/tmp' }
    
    # Set test paths
    $script:testMockPath = Join-Path $PSScriptRoot 'mocks\mock-data'
    $script:testLogPath = Join-Path $script:testMockPath 'logs'
    $script:testListFile = Join-Path $script:testMockPath 'LitigationHoldList.txt'
	$script:fallbackListFile = Join-Path $tempDir 'LitigationHoldList.txt'
	$script:fallbackLogFileDirectory = Join-Path $tempDir 'LitigationHoldLogs'
    
    # Ensure mock directories exist
    if (-not (Test-Path $script:testLogPath)) {
        New-Item -ItemType Directory -Path $script:testLogPath -Force | Out-Null
    }
    
    # Create clean log files
    $script:testLogFile = Join-Path $script:testLogPath 'LitigationHoldLog.txt'
    $script:testErrorFile = Join-Path $script:testLogPath 'LitigationHoldErrors.txt'
    
    $null | Out-File $script:testLogFile -Force
    $null | Out-File $script:testErrorFile -Force
    $null | Out-File $script:testListFile -Force
}

Describe 'Start-LitigationHold Parameter Validation' {
    It 'Should run without parameters in mock mode' {
        { Start-LitigationHold -UseMockData } | Should -Not -Throw
    }
    
    It 'Should accept custom SearchBase' {
        { Start-LitigationHold -SearchBase 'OU=Test,DC=local' -UseMockData } | Should -Not -Throw
    }
    
    It 'Should accept custom LogFilepath' {
        $testLog = Join-Path $tempDir 'pester-litigation-logs'
        { Start-LitigationHold -LogFileDirectory $testLog -UseMockData } | Should -Not -Throw
    }
    
    It 'Should accept custom LitigationHoldDuration' {
        { Start-LitigationHold -LitigationHoldDuration 365 -UseMockData } | Should -Not -Throw
    }
    
    It 'Should accept custom O365LicenseGroups' {
        { Start-LitigationHold -O365LicenseGroups @('Group1','Group2') -UseMockData } | Should -Not -Throw
    }
}

Describe 'Start-LitigationHold Mock Mode' {	
    It 'Should run without errors in mock mode' {
        { Start-LitigationHold -UseMockData } | Should -Not -Throw
    }
    
    It "Should create log directory if it doesn't exist" {
        $tempPath = Join-Path $tempDir 'pester-litigation-temp'
        if (Test-Path $tempPath) { Remove-Item $tempPath -Recurse -Force }
        
        { Start-LitigationHold -LogFileDirectory $tempPath -UseMockData } | Should -Not -Throw
        Test-Path $tempPath | Should -Be $true
    }
    
    It 'Should output result object' {
		$null | Out-File $script:fallbackListFile -Force
		
        $result = Start-LitigationHold -UseMockData
        $result | Should -Not -BeNullOrEmpty
        $result.UsersIdentified | Should -Be 2
        $result.Simulation | Should -Be $true
    }
}

Describe 'Start-LitigationHold User Processing' {
    BeforeEach {
        # Clear litigation hold list
        $null | Out-File $script:testListFile -Force
        $null | Out-File $script:testLogFile -Force
    }
    
    It 'Should process users in mock mode' {
        $result = Start-LitigationHold -LitigationHoldListFilepath $script:testListFile -LogFileDirectory $script:testLogPath -UseMockData
        $result.UsersIdentified | Should -Be 2
        $result.LitigationHoldApplied | Should -Be 2
    }
    
    It 'Should add users to litigation hold list after processing' {
        Start-LitigationHold -LitigationHoldListFilepath $script:testListFile -LogFileDirectory $script:testLogPath -UseMockData
        
        $list = Get-Content $script:testListFile | Where-Object { $_ -match '\S' }
        $list.Count | Should -Be 2
        $list[0] | Should -Match '@company.com'
    }
    
    It 'Should write to log file when processing users' {
		$null | Out-File $script:testListFile -Force
		$null | Out-File $script:testLogFile -Force
		
        Start-LitigationHold -LitigationHoldListFilepath $script:testListFile -LogFileDirectory $script:testLogPath -UseMockData
        
        $log = Get-Content $script:testLogFile
        $log.Count | Should -BeGreaterThan 0
        $log[0] | Should -Match 'added to litigation hold'
    }
    
    It 'Should not reprocess users already in litigation list' {
        # First run
        Start-LitigationHold -LitigationHoldListFilepath $script:testListFile -LogFileDirectory $script:testLogPath -UseMockData
        
        # Second run
        $result = Start-LitigationHold -LitigationHoldListFilepath $script:testListFile -LogFileDirectory $script:testLogPath -UseMockData
        
        # Should find 0 new users
        $result.UsersIdentified | Should -Be 0
        $result.LitigationHoldApplied | Should -Be 0
    }
}

Describe 'Start-LitigationHold Error Handling' {
    It 'Should handle missing SearchBase gracefully' {
        { Start-LitigationHold -SearchBase '' } | Should -Throw
    }
}

Describe 'Start-LitigationHold Performance' {
    It 'Should complete within reasonable time' {
        $elapsed = Measure-Command { Start-LitigationHold -UseMockData }
        $elapsed.TotalSeconds | Should -BeLessThan 10
    }
}

AfterAll {
    # Clean up test files
    $testFiles = @(
        (Join-Path $tempDir 'pester-litigation-logs'),
        (Join-Path $tempDir 'pester-litigation-temp'),
        (Join-Path $tempDir 'pester-new-logs')
    )
	
	
    # Add fallback files if they exist
    if ($script:fallbackListFile -and (Test-Path $script:fallbackListFile)) {
        $testFiles += $script:fallbackListFile
    }
    
    if ($script:fallbackLogFileDirectory -and (Test-Path $script:fallbackLogFileDirectory)) {
        $testFiles += $script:fallbackLogFileDirectory
    }
    
    foreach ($file in $testFiles) {
        if (Test-Path $file) {
            Remove-Item $file -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}