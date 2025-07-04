RESOURCE_GROUP="album-containerapps-rg"
LOCATION="francecentral"
ENVIRONMENT="env-album-containerapps"
APPLICATION_NAME="album"
PREFFIX_VNET="10.0.0.0/16"
PREFFIX_SUBNET_ENV="10.0.0.0/27"
PREFFIX_SUBNET_JUMP="10.0.0.64/27"
PREFFIX_SUBNET_APPGW="10.0.1.0/24"
ACR_NAME="acaalbumacr"
IDENTITY="aca-mi"
LOG_ANALYTICS_WORKSPACE="${APPLICATION_NAME}-law"
API_NAME=album-api
VERSION_API="v.1.0.0"
FRONTEND_NAME=album-ui
VERSION_FRONTEND="v.1.0.0"


########################################################################################################


echo "Creating resource group: $RESOURCE_GROUP in location: $LOCATION"
az group create \
--name $RESOURCE_GROUP \ 
--location $LOCATION


##########################################################################################################


echo "Creating Vnet: $APPLICATION_NAME-vnet in resource group: $RESOURCE_GROUP"
az network vnet create \
  --name $APPLICATION_NAME-vnet \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --address-prefixes $PREFFIX_VNET
  
  VNET_ID=$(#  az network vnet show \
      --name $APPLICATION_NAME-vnet \
      --resource-group $RESOURCE_GROUP \
      --query id \
      --output tsv#)
      
    echo "VNET_ID: $VNET_ID"


##########################################################################################################


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

echo "creating subnet Jump in Vnet: $APPLICATION_NAME-vnet"
az network vnet subnet create \
  --name $APPLICATION_NAME-jump-subnet \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $APPLICATION_NAME-vnet \
  --address-prefixes $PREFFIX_SUBNET_JUMP \

echo "creating application gateway subnet in Vnet: $APPLICATION_NAME-vnet"
az network vnet subnet create \
  --name $APPLICATION_NAME-appgw-subnet \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $APPLICATION_NAME-vnet \
  --address-prefixes $PREFFIX_SUBNET_APPGW \
  --delegations Microsoft.Network/applicationGateways


######################################################################################################


echo "Creating Log Analytics Workspace: $LOG_ANALYTICS_WORKSPACE in : $RESOURCE_GROUP"
az monitor log-analytics workspace create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $LOG_ANALYTICS_WORKSPACE \
  --location $LOCATION

LOG_ANALYTICS_WORKSPACE_ID=$(
    az monitor log-analytics workspace show \
      --resource-group $RESOURCE_GROUP \
      --workspace-name $LOG_ANALYTICS_WORKSPACE \
      --query customerId \
      --output tsv
  )
echo "LOG_ANALYTICS_WORKSPACE_ID: $LOG_ANALYTICS_WORKSPACE_ID"

KEY_LOG_ANALYTICS=$(az monitor log-analytics workspace get-shared-keys \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $LOG_ANALYTICS_WORKSPACE \
  --query primarySharedKey --output tsv)
echo "KEY_LOG_ANALYTICS: $KEY_LOG_ANALYTICS"


########################################################################################################


echo "Creating coantainer app ennvironment: $ENVIRONMENT in resource group: $RESOURCE_GROUP"
az containerapp env create \
  --name $ENVIRONMENT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --infrastructure-subnet-resource-id $SUBNET_ENV_ID \
  --internal-only true \
  --enable-workload-profiles true \
  --logs-workspace-key $KEY_LOG_ANALYTICS \
  --logs-workspace-id $LOG_ANALYTICS_WORKSPACE_ID

ENVIRONMENT_DEFAULT_DOMAIN=$(az containerapp env show \
  --name $ENVIRONMENT \
  --resource-group $RESOURCE_GROUP \
  --query properties.defaultDomain --output tsv)
echo "ENVIRONMENT_DEFAULT_DOMAIN: $ENVIRONMENT_DEFAULT_DOMAIN"

ENVIRONMENT_STATIC_IP=$(az containerapp env show \
  --name $ENVIRONMENT \
  --resource-group $RESOURCE_GROUP \
  --query properties.staticIp --output tsv)
echo "ENVIRONMENT_STATIC_IP: $ENVIRONMENT_STATIC_IP"


############################################################################################################
echo "Creating Private DNS Zone: $ENVIRONMENT_DEFAULT_DOMAIN in resource group: $RESOURCE_GROUP"

az network.private-dns.zone.create \
  --resource-group $RESOURCE_GROUP \
  --name $ENVIRONMENT_DEFAULT_DOMAIN

echo "Linking Private DNS Zone: $ENVIRONMENT_DEFAULT_DOMAIN to Vnet: $APPLICATION_NAME-vnet in resource group: $RESOURCE_GROUP"
az network private-dns link vnet create \
  --resource-group $RESOURCE_GROUP \
  --zone-name $ENVIRONMENT_DEFAULT_DOMAIN \
  --name ${APPLICATION_NAME}-dns-link \
  --virtual-network $VNET_ID \
  --registration-enabled true

echo "Adding A records to Private DNS Zone: $ENVIRONMENT_DEFAULT_DOMAIN for static IP: $ENVIRONMENT_STATIC_IP"
az network private-dns record-set a add-record \
  --resource-group $RESOURCE_GROUP \
  --zone-name $ENVIRONMENT_DEFAULT_DOMAIN \
  --record-set-name '*' \
  --ipv4-address $ENVIRONMENT_STATIC_IP

echo "Adding A records to Private DNS Zone: $ENVIRONMENT_DEFAULT_DOMAIN for root domain '@' with static IP: $ENVIRONMENT_STATIC_IP"
az network private-dns record-set a add-record \
  --resource-group $RESOURCE_GROUP \
  --zone-name $ENVIRONMENT_DEFAULT_DOMAIN \
  --record-set-name '@' \
  --ipv4-address $ENVIRONMENT_STATIC_IP


###########################################################################################################


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


######################################################################################################


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


#########################################################################################################


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
  --env-vars API_BASE_URL=https://$FQDN \
  --registry-identity "$IDENTITY_ID" \
  --registry-server $ACR_NAME.azurecr.io \
  --query properties.configuration.ingress.fqdn



###################################################################################################

APPLICATION_GATEWAY_NAME="${APPLICATION_NAME}-app-gateway"
APPLICATION_GATEWAY_SKU="Standard"
APPLICATION_GATEWAY_PIP_NAME="${APPLICATION_NAME}-app-gateway-pip"
APPLICATION_GATEWAY_SKU_TIER="Regional"



# Créer l'IP publique pour l'Application Gateway
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name $APPLICATION_GATEWAY_PIP_NAME \
  --sku Standard \
  --tier Regional \
  --zone 1 2 3 \
  --location $LOCATION

# Obtenir l'ID du subnet pour l'Application Gateway
 =$(
    az network vnet subnet show \
      --name $APPLICATION_NAME-appgw-subnet \
      --resource-group $RESOURCE_GROUP \
      --vnet-name $APPLICATION_NAME-vnet \
      --query id \
      --output tsv
    )
echo "SUBNET_APPGW_ID: $SUBNET_APPGW_ID"

# Créer l'Application Gateway avec listener HTTPS et certificat PFX
az network application-gateway create \
  --name $APPLICATION_GATEWAY_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_v2 \
  --capacity 2 \
  --vnet-name $APPLICATION_NAME-vnet \
  --subnet $APPLICATION_NAME-appgw-subnet \
  --public-ip-address $APPLICATION_GATEWAY_PIP_NAME \
  --http-settings-cookie-based-affinity Disabled \
  --http-settings-port 80 \
  --http-settings-protocol Http \
  --frontend-port 443 \
  --cert-file ./infra/cert/certificate.pfx \
  --cert-password "VotreMotDePasseCertificat" \





###################################################################################################
#
#
#az network nsg create \
#  --resource-group $RESOURCE_GROUP \
#  --name $APPLICATION_NAME-jump-nsg \
#  --location $LOCATION
#
#az network nsg rule create \
#  --resource-group $RESOURCE_GROUP \
#  --nsg-name $APPLICATION_NAME-jump-nsg \
#  --name Allow-RDP \
#  --protocol Tcp \
#  --direction Inbound \
#  --priority 1000 \
#  --source-address-prefixes '*' \
#  --source-port-ranges '*' \
#  --destination-address-prefixes '*' \
#  --destination-port-ranges 3389 \
#  --access Allow
#
#az network public-ip create \
#  --resource-group $RESOURCE_GROUP \
#  --name $APPLICATION_NAME-jump-pip \
#  --sku Standard \
#  --allocation-method Static \
#  --zone 1 2 3 \
#  --location $LOCATION
#
#az network nic create \
#  --resource-group $RESOURCE_GROUP \
#  --name $APPLICATION_NAME-jump-nic \
#  --vnet-name $APPLICATION_NAME-vnet \
#  --subnet $APPLICATION_NAME-jump-subnet \
#  --public-ip-address $APPLICATION_NAME-jump-pip
#
#az network nic update \
#  --resource-group $RESOURCE_GROUP \
#  --name $APPLICATION_NAME-jump-nic \
#  --network-security-group $APPLICATION_NAME-jump-nsg
#
#az vm create \
#  --resource-group $RESOURCE_GROUP \
#  --name $APPLICATION_NAME-jump-vm \
#  --nics $APPLICATION_NAME-jump-nic \
#  --image Win2019Datacenter \
#  --admin-username pierrc \
#  --admin-password "P@ssword123!" \
#  --location $LOCATION \
#  --size Standard_B2ms