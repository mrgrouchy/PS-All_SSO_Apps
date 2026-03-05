# Get-SSOEnterpriseApps

A PowerShell script that uses Microsoft Graph to list all Entra ID Enterprise Applications configured with **SAML SSO** or **OIDC SSO**.

## Prerequisites

### PowerShell Module

```powershell
Install-Module Microsoft.Graph.Applications -Scope CurrentUser
```

### Permissions

| Permission | Type | Description |
|---|---|---|
| `Application.Read.All` | Delegated or Application | Read all applications and service principals |

## Usage

```powershell
# List all SAML and OIDC SSO apps
.\Get-SSOEnterpriseApps.ps1

# SAML apps only
.\Get-SSOEnterpriseApps.ps1 -SSOType SAML

# OIDC apps only
.\Get-SSOEnterpriseApps.ps1 -SSOType OIDC

# Export results to CSV
.\Get-SSOEnterpriseApps.ps1 -ExportCsvPath C:\Reports\SSOApps.csv

# Use device code authentication (MFA / non-interactive sessions)
.\Get-SSOEnterpriseApps.ps1 -UseDeviceCode
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `-SSOType` | String | `All` | Filter by SSO type: `All`, `SAML`, or `OIDC` |
| `-ExportCsvPath` | String | — | Path to export results as a UTF-8 CSV file |
| `-UseDeviceCode` | Switch | — | Authenticate via device code flow |

## Output

The script displays a grouped table per SSO type and returns a `PSCustomObject` list with the following properties:

| Property | Description |
|---|---|
| `DisplayName` | Application display name |
| `ApplicationId` | App (client) ID |
| `ObjectId` | Service principal object ID |
| `SSOType` | `SAML` or `OIDC` |
| `AccountEnabled` | Whether sign-in is enabled |
| `ServicePrincipalType` | e.g. `Application`, `ManagedIdentity` |
| `LoginUrl` | Sign-on URL (SAML) |
| `ReplyUrls` | Redirect/reply URIs |
| `PublisherName` | Publisher of the application |
| `AppOwnerOrganizationId` | Tenant ID of the app owner |
| `Tags` | Tags on the service principal |

## Example Output

```
Connecting to Microsoft Graph...
Fetching SAML SSO applications...
  Found 12 SAML SSO application(s).
Fetching OIDC SSO applications...
  Found 4 OIDC SSO application(s).

Total applications found: 16

  [OIDC SSO - 4 app(s)]
  DisplayName         ApplicationId                        AccountEnabled LoginUrl
  -----------         -------------                        -------------- --------
  My OIDC App         xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx           True

  [SAML SSO - 12 app(s)]
  DisplayName         ApplicationId                        AccountEnabled LoginUrl
  -----------         -------------                        -------------- --------
  Salesforce          xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx           True https://...
  ...
```
