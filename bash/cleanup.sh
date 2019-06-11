# Defining variables
RESOURCE_GROUP_NAME="grafana-eus-rg"

# Removing Resources
az group delete --name $RESOURCE_GROUP_NAME

# Removing AD App
APP_ID = $(az ad app list \
    --display-name Grafana \
    --query '[0].appId' \
    --output tsv)

az ad app delete --id $APP_ID