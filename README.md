# Hoover IAM DevSecOps Portfolio

## About This Project
This repository contains **sanitized automation patterns** from my work as an Information Security Automation Engineer at the City of Hoover. The code demonstrates enterprise-grade identity and access management (IAM) security controls used for 850+ municipal employees.

## Security Patterns Demonstrated
| Control | Implementation |
|--------|----------------|
| **Automated Deprovisioning** | Zero-touch user disable with audit trail |
| **Secrets Management** | No hardcoded credentials; environment variables for config |
| **Least Privilege** | Group membership removal on termination |
| **Audit Readiness** | JSON-based logging for compliance (SOX/HIPAA/CJIS) |

## Architecture (Production)
In production at City of Hoover, this automation integrates:
- Active Directory (on-premise)
- Exchange Online (cloud)
- Duo Security MFA (API)
- Azure Key Vault (secrets)

## Running This Demo
```powershell
# Clone the repo
git clone https://github.com/JLTopping/hoover-iam-devsecops.git
cd hoover-iam-devsecops

# Run the demo with mock data
.\src\Disable-User.ps1 -Username "jsmith" -UseLocalMockData