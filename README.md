# Get-SSOApps

A PowerShell script that uses Microsoft Graph to generate a unified CSV report of all Entra ID Enterprise Applications (`Application` and `Legacy` types), including SSO details (SAML/OIDC), URLs, and user/group assignment counts. Uses parallel processing for performance on large tenants.

## Prerequisites

### PowerShell Modules

```powershell
Install-Module Microsoft.Graph.Applications -Scope CurrentUser
Install-Module Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser
```

### Permissions

| Permission | Type | Description |
|---|---|---|
| `Application.Read.All` | Delegated | Read all applications and service principals |
| `Directory.Read.All` | Delegated | Read directory data (assignments) |

## Usage

```powershell
.\Get-SSOApps.ps1
```

The script authenticates interactively via `Connect-MgGraph` if not already connected, then prompts:

1. **Test mode?** — Enter `Y` to process a limited number of apps (useful for validation), or `N` to process all apps in the tenant.
2. **How many apps?** — (Test mode only) Enter the number of apps to retrieve.

The report is automatically saved as a CSV file in the same directory as the script, named `Report_All_EnterpriseApps_<timestamp>.csv`.

## Output (CSV columns)

| Column | Description |
|---|---|
| `ApplicationName` | Application display name |
| `Application (Client) ID` | App (client) ID |
| `App_Type` | Service principal type: `Application` or `Legacy` |
| `Status` | `Enabled` or `Disabled` |
| `AssignmentRequired` | Whether assignment is required (`Yes`, `No (Open)`, or `N/A` for Legacy) |
| `SSO_Type` | `SAML`, `OIDC`, `Other`, or `N/A` (Legacy apps) |
| `AssignedUsers` | Number of directly assigned users (Application type only) |
| `AssignedGroups` | Number of assigned groups (Application type only) |
| `Identifier (SAML)` | SAML identifier URIs (semicolon-separated) |
| `Reply URL` | Reply/redirect URLs (semicolon-separated) |

## Example Output

```
Connecting to Microsoft Graph...
Connection successful.
Do you want to run a test? (Y/N): N
Production Mode: Retrieving ALL applications...
Found 350 applications to analyze.
Processing 350 applications in parallel (ThrottleLimit: 20)...
--------------------------------------------------------
Process complete. Report generated at:
C:\Scripts\Report_All_EnterpriseApps_2026-03-05-1430.csv
--------------------------------------------------------
```
