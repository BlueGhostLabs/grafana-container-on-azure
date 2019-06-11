#! /bin/bash

# Initial Setup
RESOURCE_GROUP_NAME="grafana-eus-rg"
LOCATION="eastus"
STORAGE_ACCOUNT_NAME="grafanaeusst"
APP_PLAN_NAME="grafana-eus-ap"
APP_SERVICE_NAME="grafana-eus-as"

# Generating a Grafana password
GF_PASSWORD=$(date +%s | sha256sum | base64 | head -c 12 ;)

# Getting tenant id for use later
TENANT_ID=$(az account show --query 'tenantId' --output tsv)

# Create Resource Group
az group create \
    --name $RESOURCE_GROUP_NAME \
    --location $LOCATION \
    --output none

# Create Storage Account
az storage account create \
    --name $STORAGE_ACCOUNT_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --location $LOCATION \
    --sku Standard_LRS \
    --output none

# Get Storage Account Key
STORAGE_ACCOUNT_KEY=$(az storage account keys list \
    --account-name $STORAGE_ACCOUNT_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --query '[0].value' \
    --output tsv)

# Create Grafana Container
az storage container create \
    --name grafana \
    --account-name $STORAGE_ACCOUNT_NAME 

# Create App Service Plan
az appservice plan create \
    --name $APP_PLAN_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --sku B1 \
    --is-linux \
    --output none

# Create App Service
az webapp create \
    --resource-group $RESOURCE_GROUP_NAME \
    --plan $APP_PLAN_NAME \
    --name $APP_SERVICE_NAME \
    --deployment-container-image-name grafana/grafana \
    --output none

# Set the storage account and mount point
az webapp config storage-account add \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $APP_SERVICE_NAME \
    --custom-id GrafanaData \
    --storage-type AzureBlob \
    --share-name grafana \
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
    GF_AUTH_GENERIC_OAUTH_NAME="Azure AD" \
    GF_AUTH_GENERIC_OAUTH_ENABLED=true \
    GF_AUTH_GENERIC_OAUTH_ALLOW_SIGN_UP=true \
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