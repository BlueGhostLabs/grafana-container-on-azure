# Defining variables
resource_group_name="grafana-eus-rg"

# Removing Resources
az group delete --name $resource_group_name

# Removing AD App
ad_application_id=$(az ad app list \
    --display-name Grafana \
    --query '[0].appId' \
    --output tsv)

az ad app delete --id $ad_application_id