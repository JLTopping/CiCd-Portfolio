function Disable-User {
	<#
	.SYNOPSIS
		Simulated user disable function for DevSecOps portfolio.
	.DESCRIPTION
		Demonstrates security automation patterns used at City of Hoover.
		Production version integrates with Active Directory (AD), Exchange Online, and Duo.
	.PARAMETER Username
		The SAM account name of the user to disable. Accepts pipeline input.
	.PARAMETER BackupJsonFilepath
		Path to JSON file for audit logging. In production, from environment variables.
	.PARAMETER CalendarPermissionsFilepath
		Path to JSON file containing current calendar permissions.
	.PARAMETER KeepMailGroups
		Switch to skip removal from mail-enabled groups (for testing).
	.PARAMETER KeepCalendarPermissions
		Switch to skip calendar permission revocation (for testing).
	.PARAMETER UseMockData
		Switch to use local mock data instead of production paths.
	.EXAMPLE
		Disable-User -Username 'jsmith' -UseMockData
	.EXAMPLE
		'jsmith', 'mjones' | Disable-User -UseMockData
	.NOTES
		Author: Lockwood Topping
		Production version includes custom AD functions, AD user checks, error handling with continuation checking, logging, etc.
		See /docs/ARCHITECTURE.md for full offboarding workflow design.
	#>

	[CmdletBinding()]
	param(
		[Parameter(Mandatory, ValueFromPipeline)]
		[string]$Username,

		[Parameter()]
		[string]$BackupJsonFilepath = $env:DISABLED_USERS_JSON_PATH,

		[Parameter()]
		[string]$CalendarPermissionsFilepath = $env:CALENDAR_PERMISSIONS_JSON_PATH,

		[Parameter()]
		[switch]$KeepMailGroups,

		[Parameter()]
		[switch]$KeepCalendarPermissions
	)

	begin {
		Write-Verbose 'Starting Disable-User function'
		
		# TEST to fail Trivy
		<#
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAu1+K8YJk4t9c9q6l2G3xYV7p1YFzq3Q1Yk9Xv8Wc0pXqY7p2
Q8ZpL0FzV5gKj9Kx3mN8sDf9aBcDeFgHiJkLmNoPqRsTuVwXyZaBcDeFgHiJkLmN
-----END RSA PRIVATE KEY-----
#>

		# Use environment temp with fallback
		$tempDir = if ($env:TEMP) { $env:TEMP } else { $env:TMPDIR }
		if (-not $tempDir) { $tempDir = '/tmp' }

		# Create files if needed
		$FallbackBackupJson = Join-Path $tempDir 'BackupJsonFile.json'
		$FallbackCalendarPermissionsJson = Join-Path $tempDir 'CalendarPermissionsFile.json'

        Try {
            if (-not $BackupJsonFilepath) {
				$BackupJsonFilepath = $FallbackBackupJson
				Write-Verbose "Using default backup file: '$BackupJsonFilepath'."

				if (-not $(Test-Path $BackupJsonFilepath)) {
					New-Item -Path $BackupJsonFilepath -ItemType File -Force | Out-Null
				}
            } elseif ($(Test-Path $BackupJsonFilepath) -and (gci $BackupJsonFilepath).Attributes -notlike 'Directory') {
				Write-Verbose "Using Backup file '$BackupJsonFilepath'"
			} else {
				Write-Verbose "Creating Backup file '$BackupJsonFilepath'"
				New-Item -Path $BackupJsonFilepath -ItemType File -Force | Out-Null
			}

			if (-not $CalendarPermissionsFilepath) {
				$CalendarPermissionsFilepath = $FallbackCalendarPermissionsJson
				Write-Verbose "Using default calendar permissions file: '$CalendarPermissionsFilepath'."

				if (-not $(Test-Path $CalendarPermissionsFilepath)) {
					New-Item -Path $CalendarPermissionsFilepath -ItemType File -Force | Out-Null
				}
            } elseif ($(Test-Path $CalendarPermissionsFilepath) -and (gci $CalendarPermissionsFilepath).Attributes -notlike 'Directory') {
				Write-Verbose "Using calendar permissions file '$CalendarPermissionsFilepath'"
			} else {
				Write-Verbose "Creating calendar permissions file '$CalendarPermissionsFilepath'"
				New-Item -Path $CalendarPermissionsFilepath -ItemType File -Force | Out-Null
			}
		} Catch {
			Write-Error 'Unable to create required files.'
			$_
			Return
		}

		$processedUsers = @()
	}

	process {
		Write-Host "`n=== SIMULATED USER DISABLE ===" -ForegroundColor Cyan
		Write-Host "Processing user: $Username" -ForegroundColor Yellow

		# Step 1: Normalize and validate user
		Write-Host '[1/10] Normalize and validate username (SIMULATED)' -ForegroundColor Green
		Write-Verbose "Removing improper characters from '$Username'"
		Write-Verbose 'Searching AD for [normalizedUsername]'
		Write-Verbose 'Setting [userObject], [samAccountName], and [userPrincipalName] variables to use in script'

		#For Testing:
		$samAccountName = $Username.ToLower() -replace "\s", ''
		$userPrincipalName = "$samAccountName@company.com"

		# Step 2: Disable user
		Write-Host '[2/10] Disabling Active Directory account (SIMULATED)' -ForegroundColor Green
		Write-Verbose 'Disable [samAccountName] in AD'

		# Step 3: Change user password
		Write-Host '[3/10] Rotating password (SIMULATED)' -ForegroundColor Green
		Write-Verbose 'Generating long, random, alphanumeric password and save as [password]'
		Write-Verbose 'Setting [password] for [samAccountName] in AD'

		# Step 4: Record existing calendar permissions
		Write-Host '[4/10] Recording calendar permissions (SIMULATED)' -ForegroundColor Green
		Write-Verbose 'Checking if [$CalendarPermissionsFilepath] exists'
		Write-Verbose 'If exists, retrieve current O365 calendar permissions and save as [calendarPermissions]'
		Write-Verbose "If doesn't exist, warn user that calendar permission file was invalid"

		# Step 5: Backup user memberships and permissions to JSON document
		Write-Host '[5/10] Backing up group membership to JSON audit trail (SIMULATED)' -ForegroundColor Green
		Write-Verbose 'Pulling [BackupJsonFilepath] and save as [backedUpUsers]'
		Write-Verbose 'Creating psCustomObject with user AD data and [calendarPermissions] and save as [userBackupObject]'
		Write-Verbose 'Appending [userBackupObject] to [backedUpUsers]'
		Write-Verbose 'Saving [backedUpUsers] to [BackupJsonFilepath]'

		# Step 6: Remove user from Duo MFA groups
		Write-Host '[6/10] Removing from Duo MFA groups (SIMULATED)' -ForegroundColor Green
		Write-Verbose 'Pulling Duo user via Duo API and [samAccountName]'
		Write-Verbose 'Saving group membership to [duoSyncGroups]'
		Write-Verbose 'Removing [samAccountName] in AD from [duoSyncGroups]'

		# Step 7: Remove user from mail-enabled AD groups
		if (-not $KeepMailGroups) {
			Write-Host '[7/10] Removing from mail-enabled groups (SIMULATED)' -ForegroundColor Green
			Write-Verbose 'Removing user from mail-enabled AD groups in AD'
		}

		# Step 8: Remove user permissions from O365 calendars
		if (-not $KeepCalendarPermissions) {    #Would also check for [calendarPermissions] before running this code block
			Write-Host '[8/10] Revoking calendar permissions (SIMULATED)' -ForegroundColor Green
			Write-Verbose 'Connecting to ExchangeOnline using API registered app if not connected already'
			Write-Verbose 'Removing user [calendarPermissions] from shared calendars'
		}

		# Step 9: Move user to Disabled OU
		Write-Host '[9/10] Moving user to Disabled Objects OU (SIMULATED)' -ForegroundColor Green
		Write-Verbose 'Moves [samAccountName] to DisabledObjects OU'

		# Step 10: Recording Test result
		Write-Host '[10/10] Recording result to test backup document' -ForegroundColor Green
		$processedUsers += [PSCustomObject]@{
			User = $samAccountName
			UPN = $userPrincipalName
			Status = 'Disabled (SIMULATED)'
			Timestamp = $(Get-Date -Format 'MM/dd/yyyy')
			BackupPath = $BackupJsonFilepath
		}

		Write-Verbose 'Retrieving current document'
		$BackupJsonFile = Get-Content $BackupJsonFilepath | ConvertFrom-Json
        if (-not $BackupJsonFile) {
            Get-Content $BackupJsonFilepath
            [Array]$BackupJsonFile = @()
        }

		Write-Verbose 'Checking for and renaming duplicates'
		$BackupJsonFile | ForEach {
			if ($_.User -like $samAccountName) {
				$_.User = "$($_.User)_$(get-date -Date $_.Timestamp -Format "MM_dd_yyyy")"
			}
		}

		Write-Verbose 'Appending new record'
		[Array]$BackupJsonFile += $processedUsers[-1]

		Write-Verbose 'Saving Document'
		$JsonDoc = $BackupJsonFile | ConvertTo-Json -Depth 5
		Out-File $BackupJsonFilepath -InputObject $JsonDoc -Force

		Write-Host "`nSUCCESSFULLY DISABLED: $samAccountName" -ForegroundColor Green
	}

	end {
		Write-Verbose 'Disconnecting from ExchangeOnline if connected'

		Write-Host "`n=== PROCESSING SUMMARY ===" -ForegroundColor Cyan
		Write-Host "Processed $($processedUsers.Count) users" -ForegroundColor Yellow
		
		Write-Host "`nARCHITECTURE NOTE:" -ForegroundColor Magenta
		Write-Host 'In production, a scheduled task would trigger Run-LitigationHold to' -ForegroundColor Magenta
		Write-Host 'check for newly disabled users, place a litigation hold on their mailbox,' -ForegroundColor Magenta
		Write-Host 'and remove their licenses after 4 hours. See /docs for details.' -ForegroundColor Magenta

		# Output results
		$processedUsers
    }
}

Export-ModuleMember -Function Disable-User