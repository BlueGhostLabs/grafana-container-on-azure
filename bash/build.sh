#! /bin/bash

# Initial Setup
resource_group_name="grafana-eus-rg"
location="eastus"
storage_account_name="grafanaeusst"
app_plan_name="grafana-eus-ap"
app_service_name="grafana-eus-as"

# Generating a Grafana password
gf_password=$(date +%s | sha256sum | base64 | head -c 12 ;)

# Getting tenant id for use later
tenant_id=$(az account show --query 'tenantId' --output tsv)

# Create Resource Group
az group create \
    --name $resource_group_name \
    --location $location \
    --output none

# Create Storage Account
az storage account create \
    --name $storage_account_name \
    --resource-group $resource_group_name \
    --location $location \
    --sku Standard_LRS \
    --output none

# Get Storage Account Key
storage_account_key=$(az storage account keys list \
    --account-name $storage_account_name \
    --resource-group $resource_group_name \
    --query '[0].value' \
    --output tsv)

# Create Grafana Container
az storage container create \
    --name grafana \
    --account-name $storage_account_name 

# Create App Service Plan
az appservice plan create \
    --name $app_plan_name \
    --resource-group $resource_group_name \
    --sku B1 \
    --is-linux \
    --output none

# Create App Service
az webapp create \
    --resource-group $resource_group_name \
    --plan $app_plan_name \
    --name $app_service_name \
    --deployment-container-image-name grafana/grafana \
    --output none

# Set the storage account and mount point
az webapp config storage-account add \
    --resource-group $resource_group_name \
    --name $app_service_name \
    --custom-id GrafanaData \
    --storage-type AzureBlob \
    --share-name grafana \
    --account-name $storage_account_name \
    --access-key $storage_account_key \
    --mount-path /var/lib/grafana/ \
    --output none

# Get the hostname
hostname=$(az webapp show \
    --name $app_service_name \
    --resource-group $resource_group_name \
    --query 'defaulthostname' \
    --output tsv)

client_secret=$(uuidgen)

# App Registration
# https://grafana.com/docs/auth/generic-oauth/#set-up-oauth2-with-azure-active-directory
application_id=$(az ad app create \
    --display-name Grafana \
    --reply-urls https://$hostname/login/generic_oauth \
    --password $client_secret \
    --query 'appId' \
    --output tsv)

# Configuring the settings that will become environment variables
az webapp config appsettings set \
    --resource-group $resource_group_name \
    --name $app_service_name \
    --settings \
    GF_SERVER_ROOT_URL=https://$hostname \
    GF_SECURITY_ADMIN_PASSWORD=$gf_password \
    GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource,grafana-azure-monitor-datasource \
    GF_AUTH_GENERIC_OAUTH_NAME="Azure AD" \
    GF_AUTH_GENERIC_OAUTH_ENABLED=true \
    GF_AUTH_GENERIC_OAUTH_ALLOW_SIGN_UP=true \
    GF_AUTH_GENERIC_OAUTH_CLIENT_ID=$application_id \
    GF_AUTH_GENERIC_OAUTH_client_secret=$client_secret \
    GF_AUTH_GENERIC_OAUTH_SCOPES="openid email name" \
    GF_AUTH_GENERIC_OAUTH_AUTH_URL=https://login.microsoftonline.com/$tenant_id/oauth2/authorize \
    GF_AUTH_GENERIC_OAUTH_TOKEN_URL=https://login.microsoftonline.com/$tenant_id/oauth2/token \
    GF_AUTH_GENERIC_OAUTH_API_URL="" \
    GF_AUTH_GENERIC_OAUTH_TEAM_IDS="" \
    GF_AUTH_GENERIC_OAUTH_ALLOWED_ORGANIZATIONS="" \
    --output none

# Printing out information you will need to know
echo Grafana password is: $gf_password
echo Grafana address is: https://$hostname
echo Client Secret is: $client_secret