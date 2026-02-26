# Test configuration defaults for Pester tests

$script:TestRoot = if ($PSScriptRoot) {
    Split-Path -Parent $PSScriptRoot
} else {
	( get-item $MyInvocation.MyCommand.Path ).Parent.Parent.FullName
}

$script:RepoRoot = Split-Path -Parent $script:TestRoot

# Set test defaults
$script:YourDomain = 'company.com'
$script:YourADDC = 'DC=company,DC=com'
$script:TestSearchBase = "OU=Disabled Objects,$YourDomain"
$script:TestBackupPath = Join-Path $RepoRoot 'tests\mocks\mock-data\disabled-users-backup.json'
$script:TestCalendarPath = Join-Path $RepoRoot 'tests\mocks\mock-data\calendar-permissions.json'
$script:TestLogPath = Join-Path $RepoRoot 'tests\mocks\mock-data\logs'