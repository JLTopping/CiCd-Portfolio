# Identity Offboarding Architecture: City of Hoover

**Last Updated:** 2026-02-20  
**Author:** Lockwood Topping  
**Status:** Production Implementation (Sanitized for Public Portfolio)

---

## Overview

This document describes the architecture of the automated user offboarding system implemented at the City of Hoover (850+ employees). The system ensures **timely revocation of access**, **compliance with legal hold requirements**, and **auditability** across all termination events.

The architecture follows a **defense-in-depth** approach, balancing **security** (immediate access revocation) with **operational safety** (grace period for recovery) and **reliability** (self-healing license verification).

---

## High-Level Architecture

```
[HR System] → [Manual Trigger] → [Disable-User] → [Revokes User Access & Updates JSON Audit Trail]
                                         ↓
                              [Start-LitigationHold ScheduledTask] → [Enable Litigation Hold & Verify License Removal]
                                         ↓
                              [4-Hour Delay (Safety Window)]
                                         ↓
                              [RetrieveLicenses ScheduledTask] → [License Removal]
                                                               → [Update Audit Logs]
```

---

### Key Principles

| Principle | Implementation |
|-----------|----------------|
| **Least Privilege** | Access revoked immediately upon termination |
| **Defense in Depth** | 4-hour delay before license removal allows recovery |
| **Compliance** | Litigation hold applied automatically with 7-year retention |
| **Auditability** | Every action logged to JSON and SIEM |
| **Separation of Concerns** | Each function has single responsibility |
| **Self-Healing** | Failed license removals are detected and retried automatically |

---

## Component 1: `Disable-User`

**Purpose:** Immediately revoke access, preserve state for compliance, and schedule final cleanup.

### Actions Performed

| Action | Why | Compliance Mapping |
|--------|-----|-------------------|
| **Disable AD Account** | Prevents authentication | NIST AC-2(3) |
| **Rotate Password** | Ensures credential can't be reused | NIST IA-5(7) |
| **Remove from Duo MFA Groups** | Revokes MFA access | NIST AC-3 |
| **Remove from Mail-Enabled Groups** | Prevents email access | NIST AC-2(7)(B) |
| **Revoke Calendar Permissions** | Prevents meeting access | NIST AC-2(7)(B) |
| **Backup Group Membership to JSON** | Preserves state for audit | NIST AU-3 |
| **Record Calendar Permissions** | Documents data access | NIST AU-2 |

### JSON Audit Trail Schema

`disabled-users-backup.json`:
```json
[
  {
    "Name": "John Smith",
    "SamAccountName": "jsmith",
    "DistinguishedName": "CN=John Smith,OU=Users,DC=ourdomain,DC=com",
    "Mail": "jsmith@ourdomain.com",
    "_DisabledDate": "02/15/2026",
    "MemberOf": [
      "CN=O365_Users,OU=Groups,DC=ourdomain,DC=com",
      "CN=All City Employees,OU=Groups,DC=ourdomain,DC=com"
    ],
    "CalendarPermissions": [
      {
        "Calendar": "some-calendar@ourdomain.com",
        "Permissions": "Editor"
      }
    ]
  }
]
```

**Why JSON?** JSON was chosen because:
- Human-readable for audits
- Easily parsed by any programming language
- Can be imported directly into SIEM tools
- Lightweight, no database required

---

## Component 2: `Start-LitigationHold`

**Purpose:** Apply legal hold to newly disabled users and verify that licenses were successfully removed.

### Why Separate Functions?

| Consideration | If Combined | Current Design |
|--------------|-------------|----------------|
| **Recovery** | No window for reversal | 4-hour window |
| **Complexity** | Monolithic, hard to test | Each function testable |
| **Scheduling** | Requires complex logic | Simple task trigger |
| **Audit Trail** | All actions in one log | Separate logs per phase |

### Why License Verification Happens Here?

- Disable-User creates a scheduled task to run RetrieveLicenses after 4 hours
- RetrieveLicenses removes users from O365 license groups
- Start-LitigationHold (running daily) checks that no users in its processed list still appear in license groups
- If licenses are found: The user is removed from the litigation hold list and logged as an error, allowing them to be reprocessed the next day

This creates a self-healing system where temporary failures (network issues, Exchange throttling, service outages) don't result in permanent license retention.

### Actions Performed

| Action | Why | Timing |
|--------|-----|--------|
| **Connect to Exchange Online** | Required for all mailbox actions | Start of function |
| **Read Litigation Hold List** | Identify previously processed users | Before processing |
| **Verify License Removal** | Ensure RetrieveLicenses succeeded for previous users	| For all users in hold list |
| **Check License Group Membership** | If user still in license groups, retrieval failed | For each processed user |
| **Log License Verification Errors** | Track failures for reprocessing | When licenses still present |
| **Remove Failed Users from Hold List** | Allow reprocessing next cycle | After logging error |
| **Identify New Disabled Users** | Query AD for users not yet processed | After verification step |
| **Enable Litigation Hold** | Legal/compliance requirement | For newly disabled users only |
| **Update Litigation Hold List** | Add newly processed users | After successful hold |
| **Disconnect from Exchange Online** | Clean up session | Beginning of 'End' block |
| **Log All Actions to Audit File** | Compliance | Throughout and immediately after each loggable event successfully completes |
| **Send Completion Alert** | Operational visibility | End of function |

### Litigation Hold Configuration

```powershell
Set-Mailbox $UserPrincipalName -LitigationHoldEnabled $true -LitigationHoldDuration 2555
```

**Duration:** 2555 days (7 years)  
**Why:** Matches records retention requirements for municipal employees.

---

## Component 3: Retrieve Licenses

### Why a 4-Hour Delay?

**The 4-hour window is intentional and serves multiple purposes:**

1. **Microsoft Litigation Hold Requirement:** Microsoft recommends a 4-hour minimum after enabling litigation hold to ensure the entire mailbox is captured
2. **Recovery Window:** If a termination was accidental or mis-communicated, the account can be re-enabled without losing mailbox data
3. **Investigation Time:** Security team can review the termination before license removal
4. **User Notification:** Allows time for the terminated employee to receive offboarding instructions (if appropriate)
5. **Processing Buffer:** Ensures all backend processes complete successfully before license removal

### Actions Performed

| Action | Why | Timing |
|--------|-----|--------|
| **Read Disabled Users List** | Identify users needing license removal | Start of function |
| **Get Current License Group Members** | Compare against license groups | Before removal |
| **Remove from O365 License Groups** | Free up licenses for reuse | After verification |
| **Log All Actions** | Compliance and audit trail | Throughout |
| **Update Audit Database** | Central record keeping | End of function |

---

## Secrets Management

### Production Implementation

| Secret Type | Storage Method | Rotation |
|-------------|----------------|----------|
| Service Account Passwords | Azure Key Vault | Quarterly |
| Certificate Thumbprints | Azure Key Vault + Local Store | Annually |
| API Keys (Duo, Threat Advice) | Encrypted JSON files + Key Vault | On employee termination |
| Environment Paths | Environment Variables + GPO | As needed |

### Encryption Pattern

Sensitive files are encrypted using AES-256:

```powershell
# Encryption
Encrypt-File -KeyFile $keyPath -FilePath $configFile -OutFilePath $encryptedFile

# Decryption
$config = Decrypt-File -KeyFile $keyPath -FilePath $encryptedFile -Json
```

**Key Storage:** Keys are stored in a separate, restricted network share accessible only to service accounts and authorized administrators.

### Why Not Use Built-in PowerShell Secrets Management?

The City of Hoover environment predates widespread adoption of `SecretManagement` and `SecretStore`. The custom encryption framework was built to work across:
- Windows Server 2012 (no SecretManagement support)
- Scheduled tasks (no interactive sessions)
- Remote execution contexts

**Migration Path:** Planned migration to Azure Key Vault + Managed Identities by Q3 2026.

---

## lScheduling Architecture

### Task Creation Pattern

```powershell
# Create trigger for 4 hours in the future
$triggerTime = (Get-Date).AddHours(4)
$trigger = New-ScheduledTaskTrigger -Once -At $triggerTime

# Create action to run the script
$action = New-ScheduledTaskAction -Execute 'Powershell.exe' `
    -Argument "-File `"$scriptPath\Start-LitigationHold.ps1`" -UserList `"$userList`""

# Register task (auto-deletes after execution)
Register-ScheduledTask "RemoveDisabledUsersO365Licenses_$timestamp" `
    -InputObject $taskObject
```

### Why Windows Scheduled Tasks?

| Option | Considerations |
|--------|------------|------------------|
| **Azure Automation** | Script needs to manage on-premises servers and applications inaccessible by the cloud |
| **SQL Server Agent** | Not all servers have SQL |
| **Custom Windows Service** | Overkill; scheduled tasks are built-in |
| **Windows Scheduled Tasks** | Native, reliable, auditable |

---

## Audit & Compliance

### Audit Trail Requirements

| Requirement | Implementation |
|-------------|----------------|
| **SOX** | JSON audit of all access changes |
| **HIPAA** | Litigation hold enabled by default |
| **CJIS** | Password rotation on termination |
| **Records Retention** | 7-year litigation hold |
| **Chain of Custody** | Every action logged with timestamp |

### Logging Architecture

```
[Disable-User] -> [JSON File] -> [Splunk Universal Forwarder] -> [SIEM]
        ↓
[Start-LitigationHold] -> [JSON File] -> [Splunk Universal Forwarder] -> [SIEM]
        ↓
[RetrieveLicenses] ----> [JSON File] -> [Splunk Universal Forwarder] -> [SIEM]
```

### Sample Log Entry

```json
{
  "Timestamp": "2026-02-15T14:23:45",
  "Action": "Disable-User",
  "User": "jsmith",
  "Operator": "admin1",
  "Changes": [
    "AD account disabled",
    "Password rotated",
    "Removed from 12 groups",
    "Calendar permissions revoked"
  ],
  "Status": "Success",
  "ScheduledTask": "RemoveDisabledUsersO365Licenses_202602151423"
}
```

---

## Recovery Procedures

### Scenario 1: Accidental Termination (< 24 hours)

1. Delete the scheduled task before it runs
2. Re-enable AD account: `Enable-ADAccount $username`
3. Re-add to groups (use JSON backup for reference)
4. Reset password to known value

### Scenario 2: Hold Applied, Licenses Not Yet Removed (< 28 hours)

1. Delete the scheduled RetrieveLicenses task
2. Remove litigation hold: Set-Mailbox -LitigationHoldEnabled $false
3. Re-enable AD account
4. Restore from JSON backup

### Scenario 3: Hold Applied, Licenses Removed (> 28 hours)

1. Use `Restore-User` function (restores from soft-deleted mailbox if <= 30 days or recreates account and attaches inactive mailbox if > 30 days)
2. Re-add to groups (use JSON backup)
3. Re-enable AD account
4. Notify user of password reset

### Scenario 4: License Removal Failure Detected

1. Start-LitigationHold logs error and removes user from hold list
2. User will be reprocessed automatically in next cycle
3. New RetrieveLicenses task is scheduled
4. If failures persist, investigate task execution history

---

## Review History

| Reviewer | Role | Date | Comments |
|----------|------|------|----------|
| Jason Cope | IT Director | 2022-01-15 | Approved |
| External Audit | Kroll | 2024-06-06 | No findings |

---

## Related Documents

- `/src/Disable-User.ps1` - Immediate offboarding implementation
- `/src/Start-LitigationHold.ps1` - Mailbox retention with delayed license retrieval

---

*This document is maintained as part of the City of Hoover Identity Automation framework. For questions, contact Lockwood Topping.*