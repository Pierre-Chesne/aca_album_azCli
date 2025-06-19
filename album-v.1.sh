#!/bin/bash
LOCATION="francecentral"
APPLICATION_NAME="hello-world-0"
PREFFIX_VNET="10.0.0.0/16"
PREFFIX_SUBNET_ENV="10.0.0.0/27"
PREFFIX_SUBNET_JUMP="10.0.0.64/27"
PREFFIX_SUBNET_APP_GATEWAY="10.0.1.0/24"
ENVIRONMENT="env-${APPLICATION_NAME}-containerapps"
JUMP_VM_ADMIN_USERNAME="pierrc"

#####################################################################################################


az group create \
  --name $APPLICATION_NAME-rg \
  --location $LOCATION


####################################################################################################
  

az network vnet create \
  --name $APPLICATION_NAME-vnet \
  --resource-group $APPLICATION_NAME-rg \
  --location $LOCATION \
  --address-prefixes $PREFFIX_VNET

echo "Creating subnet: $APPLICATION_NAME-env-subnet in Vnet: $APPLICATION_NAME-vnet"

VNET_ID=$(
  az network vnet show \
    --name $APPLICATION_NAME-vnet \
    --resource-group $APPLICATION_NAME-rg \
    --query id \
    --output tsv
)
echo "VNET_ID: $VNET_ID"

az network vnet subnet create \
  --name $APPLICATION_NAME-env-subnet \
  --resource-group $APPLICATION_NAME-rg \
  --vnet-name $APPLICATION_NAME-vnet \
  --address-prefixes $PREFFIX_SUBNET_ENV \
  --delegations Microsoft.App/environments


SUBNET_ENV_ID=$(
    az network vnet subnet show \
      --name $APPLICATION_NAME-env-subnet \
      --resource-group $APPLICATION_NAME-rg \
      --vnet-name $APPLICATION_NAME-vnet \
      --query id \
      --output tsv
    )
echo "SUBNET_ID: $SUBNET_ENV_ID"


#####################################################################################################


az containerapp env create \
  --name $ENVIRONMENT \
  --resource-group $APPLICATION_NAME-rg \
  --location $LOCATION \
  --infrastructure-subnet-resource-id $SUBNET_ENV_ID \
  --internal-only true \
  --logs-destination none




ENVIRONMENT_DEFAULT_DOMAIN=$(az containerapp env show \
  --name $ENVIRONMENT \
  --resource-group $APPLICATION_NAME-rg \
  --query properties.defaultDomain --output tsv)
echo "ENVIRONMENT_DEFAULT_DOMAIN: $ENVIRONMENT_DEFAULT_DOMAIN"


ENVIRONMENT_STATIC_IP=$(az containerapp env show \
  --name $ENVIRONMENT \
  --resource-group $APPLICATION_NAME-rg \
  --query properties.staticIp --output tsv)
echo "ENVIRONMENT_STATIC_IP: $ENVIRONMENT_STATIC_IP"





#####################################################################################################



az containerapp create \
  --name $APPLICATION_NAME \
  --resource-group $APPLICATION_NAME-rg \
  --environment $ENVIRONMENT \
  --image mcr.microsoft.com/k8se/quickstart:latest\
  --target-port 80 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 3 \
  --query properties.configuration.ingress.fqdn


######################################################################################################



az network private-dns zone create \
  --resource-group $APPLICATION_NAME-rg \
  --name $ENVIRONMENT_DEFAULT_DOMAIN 

az network private-dns link vnet create \
  --resource-group $APPLICATION_NAME-rg \
  --zone-name $ENVIRONMENT_DEFAULT_DOMAIN \
  --name ${APPLICATION_NAME}-dns-link \
  --virtual-network $VNET_ID \
  --registration-enabled false

az network private-dns record-set a add-record \
  --resource-group $APPLICATION_NAME-rg \
  --zone-name $ENVIRONMENT_DEFAULT_DOMAIN \
  --record-set-name '*' \
  --ipv4-address $ENVIRONMENT_STATIC_IP

az network private-dns record-set a add-record \
  --resource-group $APPLICATION_NAME-rg \
  --zone-name $ENVIRONMENT_DEFAULT_DOMAIN \
  --record-set-name '@' \
  --ipv4-address $ENVIRONMENT_STATIC_IP


#####################################################################################################


az network vnet subnet create \
  --name $APPLICATION_NAME-jump-subnet \
  --resource-group $APPLICATION_NAME-rg \
  --vnet-name $APPLICATION_NAME-vnet \
  --address-prefixes $PREFFIX_SUBNET_JUMP \


az network nsg create \
  --resource-group $APPLICATION_NAME-rg \
  --name $APPLICATION_NAME-jump-nsg \
  --location $LOCATION

az network nsg rule create \
  --resource-group $APPLICATION_NAME-rg \
  --nsg-name $APPLICATION_NAME-jump-nsg \
  --name Allow-SSH \
  --protocol Tcp \
  --direction Inbound \
  --priority 1000 \
  --source-address-prefixes '*' \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 22 \
  --access Allow

az network vnet subnet update \
  --resource-group $APPLICATION_NAME-rg \
  --vnet-name $APPLICATION_NAME-vnet \
  --name $APPLICATION_NAME-jump-subnet \
  --network-security-group $APPLICATION_NAME-jump-nsg

az network public-ip create \
  --resource-group $APPLICATION_NAME-rg \
  --name $APPLICATION_NAME-jump-pip \
  --sku Standard \
  --allocation-method Static \
  --zone 1 2 3 \
  --location $LOCATION

az network nic create \
  --resource-group $APPLICATION_NAME-rg \
  --name $APPLICATION_NAME-jump-nic \
  --vnet-name $APPLICATION_NAME-vnet \
  --subnet $APPLICATION_NAME-jump-subnet \
  --public-ip-address $APPLICATION_NAME-jump-pip

az vm create \
  --resource-group $APPLICATION_NAME-rg \
  --name $APPLICATION_NAME-jump-vm \
  --image Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest \
  --admin-username $JUMP_VM_ADMIN_USERNAME \
  --generate-ssh-keys \
  --size Standard_B2ms \
  --nics $APPLICATION_NAME-jump-nic


######################################################################################################################

az network vnet subnet create \
  --name $APPLICATION_NAME-appgw-subnet \
  --resource-group $APPLICATION_NAME-rg \
  --vnet-name $APPLICATION_NAME-vnet \
  --address-prefixes $PREFFIX_SUBNET_APP_GATEWAY