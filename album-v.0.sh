RESOURCE_GROUP="album-containerapps-rg"
LOCATION="francecentral"
ENVIRONMENT="env-album-containerapps"
APPLICATION_NAME="album"
PREFFIX_VNET="10.0.0.0/16"
PREFFIX_SUBNET_ENV="10.0.0.0/27"
PREFFIX_SUBNET_BASTION="10.0.0.64/27"
ACR_NAME="acaalbumacr"
IDENTITY="aca-mi"


API_NAME=album-api
VERSION_API="v.1.0.0"


FRONTEND_NAME=album-ui
VERSION_FRONTEND="v.1.0.0"





####################################################################################################

echo "Creating resource group: $RESOURCE_GROUP in location: $LOCATION"
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

####################################################################################################
  
echo "Creating Vnet: $APPLICATION_NAME-vnet in resource group: $RESOURCE_GROUP"
az network vnet create \
  --name $APPLICATION_NAME-vnet \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --address-prefixes $PREFFIX_VNET

####################################################################################################

echo "Creating subnet: $APPLICATION_NAME-env-subnet in Vnet: $APPLICATION_NAME-vnet"
az network vnet subnet create \
  --name $APPLICATION_NAME-env-subnet \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $APPLICATION_NAME-vnet \
  --address-prefixes $PREFFIX_SUBNET_ENV \
  --delegations Microsoft.App/environments

echo "getting subnet ID for the environment: $APPLICATION_NAME-env-subnet in Vnet: $APPLICATION_NAME-vnet"
SUBNET_ENV_ID=$(
    az network vnet subnet show \
      --name $APPLICATION_NAME-env-subnet \
      --resource-group $RESOURCE_GROUP \
      --vnet-name $APPLICATION_NAME-vnet \
      --query id \
      --output tsv
    )
echo "SUBNET_ID: $SUBNET_ENV_ID"

echo "creating subnet bastion in Vnet: $APPLICATION_NAME-vnet"
az network vnet subnet create \
  --name $APPLICATION_NAME-bastion-subnet \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $APPLICATION_NAME-vnet \
  --address-prefixes $PREFFIX_SUBNET_BASTION

###################################################################################################

echo "Creating coantainer app ennvironment: $ENVIRONMENT in resource group: $RESOURCE_GROUP"
az containerapp env create \
  --name $ENVIRONMENT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --infrastructure-subnet-resource-id $SUBNET_ENV_ID \
  --internal-only false \
  --logs-destination none

##################################################################################################

echo "Creating Azure Container Registry: $ACR_NAME in resource group: $RESOURCE_GROUP"
az acr create \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --name $ACR_NAME \
  --sku Basic

echo "building the API image in ACR: $ACR_NAME"
cd /Users/peterochesne/repos/startup/aca_album_azCli/code-to-cloud/src
az acr build --registry $ACR_NAME --image $API_NAME:$VERSION_API .

echo "building the frontend image in ACR: $ACR_NAME"
cd /Users/peterochesne/repos/startup/aca_album_azCli/code-to-cloud-ui/src
az acr build --registry $ACR_NAME --image $FRONTEND_NAME:$VERSION_FRONTEND .

#################################################################################################

echo "Creating Managed Identity: $IDENTITY in resource group: $RESOURCE_GROUP"

az identity create \
  --name $IDENTITY \
  --resource-group $RESOURCE_GROUP


IDENTITY_ID=$(
    az identity show \
      --name $IDENTITY \
      --resource-group $RESOURCE_GROUP \
      --query id \
      --output tsv
    )
echo "IDENTITY_ID: $IDENTITY_ID"

#################################################################################################

echo "deploying the API container app: $API_NAME in resource group: $RESOURCE_GROUP"
az containerapp create \
  --name $API_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $ENVIRONMENT \
  --image $ACR_NAME.azurecr.io/$API_NAME:$VERSION_API \
  --target-port 8080 \
  --ingress internal \
  --min-replicas 1 \
  --max-replicas 3 \
  --registry-server $ACR_NAME.azurecr.io \
  --user-assigned "$IDENTITY_ID" \
  --registry-identity "$IDENTITY_ID" \
  --query properties.configuration.ingress.fqdn

FQDN=$(az containerapp show \
  --name $API_NAME \
  --resource-group $RESOURCE_GROUP \
  --query properties.configuration.ingress.fqdn \
  --output tsv)

FQDN_ALBUMS="${FQDN}/albums"
echo $FQDN_ALBUMS

###################################################################################################

echo "deploying the frontend container app: $FRONTEND_NAME in resource group: $RESOURCE_GROUP"
az containerapp create \
  --name $FRONTEND_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $ENVIRONMENT \
  --image $ACR_NAME.azurecr.io/$FRONTEND_NAME:$VERSION_FRONTEND \
  --target-port 3000 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 3 \
  --user-assigned "$IDENTITY_ID" \
  --registry-identity "$IDENTITY_ID" \
  --env-vars API_BASE_URL=https://$FQDN \
  --registry-server $ACR_NAME.azurecr.io \
  --query properties.configuration.ingress.fqdn