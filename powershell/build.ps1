#! /bin/env pwsh

# Initial Setup
$RESOURCE_GROUP_NAME="grafana-eus-rg"
$LOCATION="East US"
$STORAGE_ACCOUNT_NAME="grafanaeusst"
$APP_PLAN_NAME="grafana-eus-ap"
$APP_SERVICE_NAME="grafana-eus-as"

# Generating a Grafana password
$GF_PASSWORD = -join ((65..90) + (97..122) | Get-Random -Count 12 | % {[char]$_})


# Getting tenant id for use later
$TENANT_ID = (Get-AzTenant).Id

# Create Resource Group
New-AzResourceGroup -Name $RESOURCE_GROUP_NAME -Location $LOCATION

# Create Storage Account
New-AzStorageAccount -ResourceGroupName $RESOURCE_GROUP_NAME -Name $STORAGE_ACCOUNT_NAME -Location $LOCATION -SkuName Standard_LRS

# Get Storage Account Key
$STORAGE_ACCOUNT_KEY = (Get-AzStorageAccountKey -ResourceGroupName $RESOURCE_GROUP_NAME -Name $STORAGE_ACCOUNT_NAME).Key1

# Create Grafana Container
$STORAGE_CONTEXT = New-AzStorageContext -StorageAccountName $STORAGE_ACCOUNT_NAME
New-AzStorageContainer -Name grafana -Context $STORAGE_CONTEXT

# Create App Service Plan
New-AzResource -ResourceGroupName $RESOURCE_GROUP_NAME -Location $LOCATION -ResourceType microsoft.web/serverfarms -ResourceName $APP_PLAN_NAME -kind linux -Properties @{reserved="true"} -Sku @{name="B1";tier="Basic"; size="B1"; family="B"; capacity="1"} -Force

# Create App Service
New-AzWebApp -ResourceGroupName $RESOURCE_GROUP_NAME -Name $APP_SERVICE_NAME -AppServicePlan $APP_PLAN_NAME -ContainerImageName grafana/grafana

# Set the storage account and mount point
New-AzWebAppAzureStoragePath
az webapp config storage-account add \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $APP_SERVICE_NAME \
    --custom-id GrafanaData \
    --storage-type AzureBlob \
    --share-name GrafanaData \
    --account-name $STORAGE_ACCOUNT_NAME \
    --access-key $STORAGE_ACCOUNT_KEY \
    --mount-path /var/lib/grafana/ \
    --output none

# Get the hostname
HOSTNAME=$(az webapp show \
    --name $APP_SERVICE_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --query 'defaultHostName' \
    --output tsv)

CLIENT_SECRET=$(uuidgen)

# App Registration
# https://grafana.com/docs/auth/generic-oauth/#set-up-oauth2-with-azure-active-directory
APP_ID=$(az ad app create \
    --display-name Grafana \
    --reply-urls https://$HOSTNAME/login/generic_oauth \
    --password $CLIENT_SECRET \
    --query 'appId' \
    --output tsv)

# Configuring the settings that will become environment variables
az webapp config appsettings set \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $APP_SERVICE_NAME \
    --settings \
    GF_SERVER_ROOT_URL=https://$HOSTNAME \
    GF_SECURITY_ADMIN_PASSWORD=$GF_PASSWORD \
    GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource,grafana-azure-monitor-datasource \
    GF_AUTH_GENERIC_OAUTH_ENABLED=true \
    GF_AUTH_GENERIC_OAUTH_CLIENT_ID=$APP_ID \
    GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=$CLIENT_SECRET \
    GF_AUTH_GENERIC_OAUTH_SCOPES="openid email name" \
    GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://login.microsoftonline.com/$TENANT_ID/oauth2/authorize \
    GF_AUTH_GENERIC_OAUTH_TOKEN_URL=https://login.microsoftonline.com/$TENANT_ID/oauth2/token \
    GF_AUTH_GENERIC_OAUTH_API_URL="" \
    GF_AUTH_GENERIC_OAUTH_TEAM_IDS="" \
    GF_AUTH_GENERIC_OAUTH_ALLOWED_ORGANIZATIONS="" \
    --output none

# Printing out information you will need to know
echo Grafana password is: $GF_PASSWORD
echo Grafana address is: https://$HOSTNAME
echo Client Scecret is: $CLIENT_SECRET