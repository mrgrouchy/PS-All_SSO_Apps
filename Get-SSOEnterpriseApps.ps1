<#
.SYNOPSIS
    Lists all Enterprise Applications with SAML SSO or OIDC SSO configured in Entra ID.

.DESCRIPTION
    Connects to Microsoft Graph and retrieves all service principals where
    preferredSingleSignOnMode is 'saml' or 'oidc', then outputs a formatted report.

.PARAMETER SSOType
    Filter by SSO type: All (default), SAML, or OIDC.

.PARAMETER ExportCsvPath
    Optional path to export results as a CSV file.

.PARAMETER UseDeviceCode
    Use device code flow for authentication (useful in non-interactive environments).

.NOTES
    Requires: Microsoft.Graph.Applications module
    Permissions: Application.Read.All (or Directory.Read.All)

.EXAMPLE
    .\Get-SSOEnterpriseApps.ps1

.EXAMPLE
    .\Get-SSOEnterpriseApps.ps1 -SSOType SAML -ExportCsvPath C:\Reports\SAMLApps.csv

.EXAMPLE
    .\Get-SSOEnterpriseApps.ps1 -SSOType OIDC -UseDeviceCode
#>

#Requires -Modules Microsoft.Graph.Applications

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('All', 'SAML', 'OIDC')]
    [string]$SSOType = 'All',

    [Parameter()]
    [string]$ExportCsvPath,

    [Parameter()]
    [switch]$UseDeviceCode
)

# --- Connect to Microsoft Graph ---
$connectParams = @{
    Scopes = 'Application.Read.All'
}
if ($UseDeviceCode) {
    $connectParams['UseDeviceCode'] = $true
}

Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph @connectParams -NoWelcome

# --- Helper: Fetch apps by SSO mode ---
function Get-SSOApps {
    param([string]$Mode)

    $label = $Mode.ToUpper()
    Write-Host "Fetching $label SSO applications..." -ForegroundColor Yellow

    $selectFields = @(
        'id', 'appId', 'displayName', 'preferredSingleSignOnMode',
        'loginUrl', 'replyUrls', 'servicePrincipalType',
        'accountEnabled', 'appOwnerOrganizationId', 'tags', 'publisherName'
    ) -join ','

    $apps = Get-MgServicePrincipal -All `
        -Filter "preferredSingleSignOnMode eq '$Mode'" `
        -Property $selectFields `
        -ConsistencyLevel eventual `
        -CountVariable count

    Write-Host "  Found $count $label SSO application(s)." -ForegroundColor Green

    foreach ($app in $apps) {
        [PSCustomObject]@{
            DisplayName              = $app.DisplayName
            ApplicationId            = $app.AppId
            ObjectId                 = $app.Id
            SSOType                  = $label
            AccountEnabled           = $app.AccountEnabled
            ServicePrincipalType     = $app.ServicePrincipalType
            LoginUrl                 = $app.LoginUrl
            ReplyUrls                = ($app.ReplyUrls -join '; ')
            PublisherName            = $app.PublisherName
            AppOwnerOrganizationId   = $app.AppOwnerOrganizationId
            Tags                     = ($app.Tags -join '; ')
        }
    }
}

# --- Collect results ---
$results = [System.Collections.Generic.List[PSCustomObject]]::new()

switch ($SSOType) {
    'SAML' { Get-SSOApps -Mode 'saml' | ForEach-Object { $results.Add($_) } }
    'OIDC' { Get-SSOApps -Mode 'oidc' | ForEach-Object { $results.Add($_) } }
    'All'  {
        Get-SSOApps -Mode 'saml' | ForEach-Object { $results.Add($_) }
        Get-SSOApps -Mode 'oidc' | ForEach-Object { $results.Add($_) }
    }
}

# --- Output ---
Write-Host "`nTotal applications found: $($results.Count)" -ForegroundColor Cyan

if ($results.Count -gt 0) {
    $grouped = $results | Group-Object SSOType | Sort-Object Name
    foreach ($group in $grouped) {
        Write-Host "`n  [$($group.Name) SSO - $($group.Count) app(s)]" -ForegroundColor Magenta
        $group.Group | Sort-Object DisplayName |
            Format-Table DisplayName, ApplicationId, AccountEnabled, LoginUrl -AutoSize
    }

    if ($ExportCsvPath) {
        $results | Sort-Object SSOType, DisplayName |
            Export-Csv -Path $ExportCsvPath -NoTypeInformation -Encoding UTF8
        Write-Host "Results exported to: $ExportCsvPath" -ForegroundColor Green
    }
} else {
    Write-Host "No enterprise applications found with the specified SSO type(s)." -ForegroundColor Yellow
}

return $results
