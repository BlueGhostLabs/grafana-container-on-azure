#! /bin/env pwsh

# Initial Setup
$resourceGroupName = "grafana-eus-rg"
$location = "East US"
$storageAccountName = "grafanaeusst"
$appPlanName = "grafana-eus-ap"
$appServiceName = "grafana-eus-as"

# Generating a Grafana and AD App password
$grafanaPassword = -join ((65..90) + (97..122) | Get-Random -Count 12 | % { [char]$_ })
$clientSecret = New-Guid

# Getting tenant id for use later
$tenantId = (Get-AzTenant).Id

# Create Resource Group
New-AzResourceGroup -Name $resourceGroupName -Location $location

# Create Storage Account
$StorageAccountParams = @{
    ResourceGroupName = $resourceGroupName
    Name              = $storageAccountName
    Location          = $location
    SkuName           = "Standard_LRS"
} 

New-AzStorageAccount @StorageAccountParams

# Get Storage Account Key
$AccountKeyParams = @{
    ResourceGroupName = $resourceGroupName
    Name              = $storageAccountName
}

$storageAccountKey = (Get-AzStorageAccountKey @AccountKeyParams).Value[0]

# Create Grafana Container
$storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
New-AzStorageContainer -Name grafana -Context $storageContext

# Create App Service Plan
$AppPlanParams = @{
    ResourceGroupName = $resourceGroupName
    ResourceName      = $appPlanName
    Location          = $location
    ResourceType      = "microsoft.web/serverfarms"
    kind              = "linux"
    Properties        = @{reserved = "true" }
    Sku               = @{name = "B1"; tier = "Basic"; size = "B1"; family = "B"; capacity = "1" }
}

New-AzResource @AppPlanParams -Force

# Create App Service
$AppServiceParams = @{
    ResourceGroupName = $resourceGroupName
    Name              = $appServiceName
    AppServicePlan    = $appPlanName
}

$webApp = New-AzWebApp @AppServiceParams

# Set the storage account and mount point
$StoragePathParams = @{
    Name        = "GrafanaData"
    AccountName = $storageAccountName
    Type        = "AzureBlob"
    ShareName   = "grafana"
    AccessKey   = $storageAccountKey
    MountPath   = "/var/lib/grafana/"
}

$storagePath = New-AzWebAppAzureStoragePath @StoragePathParams

# App Registration
# https://grafana.com/docs/auth/generic-oauth/#set-up-oauth2-with-azure-active-directory
$SecureClientSecret = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force
$AdAppParams = @{
    DisplayName    = "Grafana"
    Password       = $SecureClientSecret
    IdentifierUris = "http://Grafana"
    ReplyUrls      = "https://$($webApp.DefaultHostName)/login/generic_oauth"
}
$adApp = New-AzADApplication @AdAppParams

# Configuring the settings that will become environment variables
$settings = @{
    GF_SERVER_ROOT_URL                          = "https://$($webApp.DefaultHostName)"
    GF_SECURITY_ADMIN_PASSWORD                  = "$($grafanaPassword)"
    GF_INSTALL_PLUGINS                          = "grafana-clock-panel,grafana-simple-json-datasource,grafana-azure-monitor-datasource"
    GF_AUTH_GENERIC_OAUTH_NAME                  = "Azure AD"
    GF_AUTH_GENERIC_OAUTH_ENABLED               = "true"
    GF_AUTH_GENERIC_OAUTH_CLIENT_ID             = "$($adApp.Id)"
    GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET         = "$($clientSecret)"
    GF_AUTH_GENERIC_OAUTH_SCOPES                = "openid email name"
    GF_AUTH_GENERIC_OAUTH_AUTH_URL              = "https://login.microsoftonline.com/$tenantId/oauth2/authorize"
    GF_AUTH_GENERIC_OAUTH_TOKEN_URL             = "https://login.microsoftonline.com/$tenantId/oauth2/token"
    GF_AUTH_GENERIC_OAUTH_API_URL               = ""
    GF_AUTH_GENERIC_OAUTH_TEAM_IDS              = ""
    GF_AUTH_GENERIC_OAUTH_ALLOWED_ORGANIZATIONS = ""
}

$AppConfig = @{
    ResourceGroup      = $resourceGroupName
    Name               = $appServiceName
    AppSettings        = $settings
    AzureStoragePath   = $storagePath
    ContainerImageName = "grafana/grafana"
}

Set-AzWebApp @AppConfig

# Printing out information you will need to know
Write-Host Grafana password is: $grafanaPassword
Write-Host Grafana address is: https://$($webApp.DefaultHostName)
Write-Host Client Secret is: $clientSecret