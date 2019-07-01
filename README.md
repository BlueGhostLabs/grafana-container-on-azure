# Grafana Container on Azure

This repo is a set of scripts that walks you through configuring and running the Grafan container on an Azure App Service for Linux, using Azure Blog storage as the mounted filesystem to store your plugins and database if using SQLite.

## Bash

You will find a *build.sh* in the Bash folder that can be used to create the resources using the Azure CLI and when you are finished there a *cleanup.sh* provided to remove them all. Both scripts will require parameters to be set at the top of each file, everything else is computed along the way.

## PowerShell

You will find a *build.ps1* in the PowerShell folder that can be used to create the resources using the PowerShell Az module and when you are finished there a *cleanup.ps1* provided to remove them all. Both scripts will require parameters to be set at the top of each file, everything else is computed along the way.

## Terrafrom

You will find a set of Terraform files in the Terraform folder that can be used to create the resources, you will only need to change the *variables.tf* file for any changes that you need to make, everything else is computed. In addition to Terraform, you will need the Azure CLI installed as it is required to create the path mapping to the blob storage because Terraform does not yet support that.
