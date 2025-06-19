#!/bin/bash


APPLICATION_NAME="album-api"
RESOURCE_GROUP_NAME="album-containerapps-rg"

az containerapp revision list \
  --name $APPLICATION_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --out table


az containerapp ingress traffic set \
    --name $APPLICATION_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --revision-weight album-api--0000003=50 album-api--0000002=50

az containerapp revision list \
  --name $APPLICATION_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --out table

az containerapp revision deactivate \
  --revision album-api--0000001 \
  --resource-group $RESOURCE_GROUP_NAME

az containerapp revision list \
  --name $APPLICATION_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --out table