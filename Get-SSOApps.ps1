<#
.SYNOPSIS
    Generates a unified report of Enterprise Applications ('Application' and 'Legacy') in CSV format.
    Includes SSO details (SAML/OIDC), URLs, and assignments, with performance optimizations and a test mode.

.DESCRIPTION
    This script uses Microsoft Graph (unattended authentication) to list Service Principals of type 'Application' or 'Legacy'.
    Key features:
    - SSO type identification (SAML, OIDC, or Other).
    - Extraction of Identifiers and Reply URLs.
    - Count of assigned users and groups (modern apps only).
    - Test Mode: Allows processing a limited number of apps for quick validation.
    - Parallel Processing: Uses 'ForEach-Object -Parallel' to maximize speed on large tenants.

.REQUIREMENTS
    - Module: Microsoft.Graph (Submodules: Applications, Identity.Directory, Users.Actions).
    - 'config.json' file with credentials (Client Credentials + Certificate).
    - Minimum permissions: Application.Read.All, Directory.Read.All.

.NOTES
    Author: Juan Sanchez
    Date: 2026-02-11
    Version: 7.1 - Massive optimization (Parallel), Test Mode (-Top), and extended details (URLs).
#>

# --- CONNECTION AND CONFIGURATION BLOCK ---
$configFilePath = Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath "config.json"
if (-not (Test-Path $configFilePath)) {
    Write-Error "Configuration file 'config.json' not found at: $configFilePath"
    return
}

try {
    $config = Get-Content -Path $configFilePath -Raw | ConvertFrom-Json
    $tenantId = $config.tenantId
    $clientId = $config.clientId
    $certThumbprint = $config.certThumbprint
}
catch {
    Write-Error "Could not read or process 'config.json'. Please verify the file format."
    return
}

try {
    Write-Host "Connecting to Microsoft Graph with certificate..." -ForegroundColor Cyan
    Connect-MgGraph -TenantId $tenantId -AppId $clientId -CertificateThumbprint $certThumbprint
    Write-Host "Connection successful." -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to Microsoft Graph. Verify the details in config.json and the certificate."
    return
}

# --- MAIN LOGIC ---
$reportData = [System.Collections.Generic.List[object]]::new()

try {
    # --- TEST MODE: Allows limiting execution for quick validation ---
    $testMode = Read-Host "Do you want to run a test? (Y/N)"
    $maxApps = 0
    if ($testMode -eq 'Y' -or $testMode -eq 'y' -or $testMode -eq 'Yes' -or $testMode -eq 'yes' -or $testMode -eq 'YES') {
        $maxApps = Read-Host "How many applications do you want to process?"
        Write-Host "Test mode activated. The first $maxApps applications will be processed." -ForegroundColor Yellow
    }

    # Retrieve all applications of type 'Application' and 'Legacy' for the report
    Write-Host "Retrieving 'Application' and 'Legacy' applications from the tenant... (this may take several minutes)"
    $properties = "id,displayName,appId,accountEnabled,appRoleAssignmentRequired,preferredSingleSignOnMode,servicePrincipalType,identifierUris,replyUrls"

    # --- App Retrieval (Optimized with -Top for testing) ---
    if ($testMode -eq 'Y' -or $testMode -eq 'y' -or $testMode -eq 'Yes' -or $testMode -eq 'yes' -or $testMode -eq 'YES') {
        Write-Host "Test Mode: Retrieving only the first $maxApps applications..." -ForegroundColor Cyan
        $enterpriseApps = Get-MgServicePrincipal -Filter "servicePrincipalType in ('Application', 'Legacy')" -Top $maxApps -Property $properties
    }
    else {
        Write-Host "Production Mode: Retrieving ALL applications..." -ForegroundColor Cyan
        $enterpriseApps = Get-MgServicePrincipal -Filter "servicePrincipalType in ('Application', 'Legacy')" -All -Property $properties
    }

    $totalApps = $enterpriseApps.Count
    Write-Host "Found $totalApps applications to analyze."

    Write-Host "Processing $($enterpriseApps.Count) applications in parallel (ThrottleLimit: 20)..." -ForegroundColor Cyan

    # --- Parallel Processing: Speeds up per-app detail queries ---
    $reportData = $enterpriseApps | ForEach-Object -Parallel {
        $app = $_

        # Initialize variables
        $ssoType = "N/A"
        $userCount = "N/A"
        $groupCount = "N/A"

        # SSO and assignment logic applies only to 'Application' type apps
        if ($app.ServicePrincipalType -eq 'Application') {
            try {
                $assignedUsersAndGroups = Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $app.Id -All -ErrorAction SilentlyContinue
                if ($assignedUsersAndGroups) {
                    $userCount = ($assignedUsersAndGroups | Where-Object { $_.PrincipalType -eq 'User' }).Count
                    $groupCount = ($assignedUsersAndGroups | Where-Object { $_.PrincipalType -eq 'Group' }).Count
                }
                else {
                    $userCount = 0
                    $groupCount = 0
                }
            }
            catch {
                $userCount = "Error"
                $groupCount = "Error"
            }

            $ssoType = "Other"

            if ($app.PreferredSingleSignOnMode -eq "saml") {
                $ssoType = "SAML"
            }
            elseif ([string]::IsNullOrEmpty($app.PreferredSingleSignOnMode)) {
                try {
                    $oAuthGrants = Get-MgServicePrincipalOauth2PermissionGrant -ServicePrincipalId $app.Id -ErrorAction SilentlyContinue

                    $isOidc = $false
                    if ($oAuthGrants) {
                        foreach ($grant in $oAuthGrants) {
                            if ($grant.Scope -match "openid" -or $grant.Scope -match "profile" -or $grant.Scope -match "email") {
                                $isOidc = $true
                                break
                            }
                        }
                    }

                    if ($isOidc) {
                        $ssoType = "OIDC"
                    }
                }
                catch {}
            }
        }

        # Return the object for the collection
        [PSCustomObject]@{
            "ApplicationName"         = $app.DisplayName
            "Application (Client) ID" = $app.AppId
            "App_Type"                = $app.ServicePrincipalType
            "Status"                  = if ($app.AccountEnabled) { "Enabled" } else { "Disabled" }
            "AssignmentRequired"      = if ($app.ServicePrincipalType -eq 'Application') { if ($app.AppRoleAssignmentRequired) { "Yes" } else { "No (Open)" } } else { "N/A" }
            "SSO_Type"                = $ssoType
            "AssignedUsers"           = $userCount
            "AssignedGroups"          = $groupCount
            "Identifier (SAML)"       = ($app.IdentifierUris -join ", ")
            "Reply URL"               = ($app.ReplyUrls -join ", ")
        }
    } -ThrottleLimit 20
}
catch {
    Write-Error "A critical error occurred during processing: $($_.Exception.Message)"
}
finally {
    if ($reportData.Count -gt 0) {
        $timestamp = Get-Date -Format "yyyy-MM-dd-HHmm"
        $reportFileName = "Report_All_EnterpriseApps_$timestamp.csv"
        $reportFilePath = Join-Path -Path $PSScriptRoot -ChildPath $reportFileName

        $reportData | Export-Csv -Path $reportFilePath -NoTypeInformation -Encoding UTF8 -Delimiter ";"

        Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
        Write-Host "Process complete. Report generated at:" -ForegroundColor Green
        Write-Host $reportFilePath -ForegroundColor White
        Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
    }
    else {
        Write-Warning "No applications were processed to generate a report."
    }

    if (Get-MgContext) {
        Write-Host "`nDisconnecting from the Microsoft Graph session."
        Disconnect-MgGraph | Out-Null
    }
}
