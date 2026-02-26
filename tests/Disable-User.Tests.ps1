<#
.SYNOPSIS
    Pester tests for Disable-User function
.DESCRIPTION
    Validates that Disable-User handles parameters correctly, runs in demo mode,
    and produces expected outputs without errors.
.NOTES
    Run with: Invoke-Pester -Path ./tests/Disable-User.Tests.ps1
#>

BeforeAll {
	# Load test configuration
    . $(Join-Path $PSScriptRoot 'configs\Load-TestConfig1.ps1')
	
	# Import the function
    $functionPath = Join-Path $RepoRoot 'src\Disable-User.psm1'
    Write-Host "Loading function from: $functionPath"
    
    if (-not (Test-Path $functionPath)) {
        Write-Error "Function file not found at: $functionPath"
        throw 'Function file missing'
    }
    
    Import-Module $functionPath -Force
    
    # Use environment temp with fallback
    $tempDir = if ($env:TEMP) { $env:TEMP } else { $env:TMPDIR }
    if (-not $tempDir) { $tempDir = '/tmp' }
    
    # Set test paths
    $script:testMockPath = Join-Path $PSScriptRoot 'mocks\mock-data'
    $script:testBackupFile = Join-Path $script:testMockPath 'disabled-users-backup.json'
    $script:testCalendarFile = Join-Path $script:testMockPath 'calendar-permissions.json'
	$script:fallbackBackupFile = Join-Path $tempDir 'BackupJsonFile.json'
	$script:fallbackPermissionsFile = Join-Path $tempDir 'CalendarPermissionsFile.json'
    
    # Ensure mock directory exists
    if (-not (Test-Path $script:testMockPath)) {
        New-Item -ItemType Directory -Path $script:testMockPath -Force | Out-Null
    }
    
    # Create clean test files
    $null | Out-File $script:testBackupFile -Force
}

Describe 'Disable-User Parameter Validation' {
    It 'Should accept pipeline input' {
        { 'test.user' | Disable-User -BackupJsonFilepath $script:testBackupFile -CalendarPermissionsFilepath $script:testCalendarFile } | Should -Not -Throw
    }
    
    It 'Should accept multiple pipeline inputs' {
		$null | Out-File $script:testBackupFile -Force

        $users = @('user1', 'user2', 'user3')
        $results = $users | Disable-User -BackupJsonFilepath $script:testBackupFile -CalendarPermissionsFilepath $script:testCalendarFile
        $results.Count | Should -Be 3
    }
    
    It 'Should handle empty username gracefully' {
        { Disable-User -Username '' } | Should -Throw
    }
    
    It 'Should accept all switches' {
        { Disable-User -Username 'test.user' -KeepMailGroups -KeepCalendarPermissions } | Should -Not -Throw
    }
}

Describe 'Disable-User Demo Mode' {
    BeforeEach {
        # Reset backup file before each test
        $null | Out-File $script:testBackupFile -Force
        $null | Out-File $script:fallbackBackupFile -Force
    }

     It 'Should run without errors in demo mode with defaults' {
        # This test relies on the function's built-in fallbacks
        { Disable-User -Username 'jsmith' } | Should -Not -Throw
    }

    It 'Should output result objects' {
        $result = Disable-User -Username 'jsmith'
        $result | Should -Not -BeNullOrEmpty
    }

    It "Should create mock data directory if it doesn't exist" {
        $tempPath = Join-Path $tempDir 'pester-test-mock'
        if (Test-Path $tempPath) { Remove-Item $tempPath -Recurse -Force }
        
        { Disable-User -Username 'jsmith' -BackupJsonFilepath (Join-Path $tempPath 'test.json') } | Should -Not -Throw
    }
}

Describe 'Disable-User Backup Functionality' {
    BeforeEach {
        # Create clean test file
        $null | Out-File $script:testBackupFile -Force
    }

    It "Should create backup file if it doesn't exist" {
        $testFile = Join-Path $tempDir 'pester-test-backup.json'
        if (Test-Path $testFile) { Remove-Item $testFile -Force }

        Disable-User -Username 'jsmith' -BackupJsonFilepath $testFile

        Test-Path $testFile | Should -Be $true
        $content = Get-Content $testFile | ConvertFrom-Json
        $content | Should -Not -BeNullOrEmpty
    }

    It 'Should append to existing backup file' {
        # First disable
        Disable-User -Username 'user1' -BackupJsonFilepath $script:testBackupFile

        # Second disable
        Disable-User -Username 'user2' -BackupJsonFilepath $script:testBackupFile

        $content = Get-Content $script:testBackupFile | ConvertFrom-Json
        $content.Count | Should -Be 2
        $content[0].User | Should -Be 'user1'
        $content[1].User | Should -Be 'user2'
    }

    It 'Should handle duplicate usernames in backup' {
        # First disable
        Disable-User -Username 'jsmith' -BackupJsonFilepath $script:testBackupFile

        # Get the content and verify it exists
        [Array]$content = Get-Content $script:testBackupFile | ConvertFrom-Json
        $content.Count | Should -Be 1

        # Store the disabled date for later comparison
        $originalDate = $content[0]._DisabledDate

        # Disable same user again (should rename old entry)
        Disable-User -Username 'jsmith' -BackupJsonFilepath $script:testBackupFile

        $content = Get-Content $script:testBackupFile | ConvertFrom-Json
        $content.Count | Should -Be 2

        # First entry should have modified name with date
        $content[0].User | Should -Match 'jsmith_'

        # Second entry should be the new one
        $content[1].User | Should -Be 'jsmith'
    }
}

Describe 'Disable-User Calendar Permissions' {
    It 'Should handle missing calendar permissions file gracefully' {
        $missingFile = Join-Path $tempDir 'missing.json'
        if (Test-Path $missingFile) { Remove-Item $missingFile -Force }

        { Disable-User -Username 'jsmith' -CalendarPermissionsFilepath $missingFile } | Should -Not -Throw
    }

    It 'Should process calendar permissions when file exists' {
        # Create test calendar permissions file
        $testCalendarFile = Join-Path $tempDir 'pester-calendar.json'
        $testData = @(
            [PSCustomObject]@{
                Calendar = 'confroom@test.com'
                Permissions = @(
                    @{ User = 'John Smith'; AccessRights = 'Editor' }
                )
            }
        )
        $testData | ConvertTo-Json -Depth 3 | Set-Content $testCalendarFile

        { Disable-User -Username 'jsmith' -CalendarPermissionsFilepath $testCalendarFile } | Should -Not -Throw
    }
}

Describe 'Disable-User Verbose Output' {
    It 'Should output verbose messages when requested' {
        $output = Disable-User -Username 'jsmith' -Verbose 4>&1
        $output[0] | Should -Match 'Starting Disable-User'
    }
}

Describe 'Disable-User Edge Cases' {
    It 'Should handle username with spaces' {
        { Disable-User -Username 'john smith' } | Should -Not -Throw
    }

    It 'Should handle username with dots' {
        { Disable-User -Username 'john.smith' } | Should -Not -Throw
    }

    It 'Should handle very long username' {
        $longName = 'a' * 100
        { Disable-User -Username $longName } | Should -Not -Throw
    }
}

AfterAll {
    # Clean up test files
    $testFiles = @(
        (Join-Path $tempDir 'pester-test-backup.json'),
        (Join-Path $tempDir 'pester-calendar.json'),
        (Join-Path $tempDir 'pester-test-mock')
    )

    foreach ($file in $testFiles) {
        if (Test-Path $file) {
            Remove-Item $file -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}