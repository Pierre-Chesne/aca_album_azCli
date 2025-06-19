#!/bin/bash
FRONTEND_NAME="album-ui"
ACR_NAME="acaalbumacr"
FRONTEND_VERSION="v.1.0.0"



echo "building the frontend image in ACR: $ACR_NAME"
cd /Users/peterochesne/repos/startup/aca_album_azCli/code-to-cloud-ui/src
az acr build --registry $ACR_NAME --image $FRONTEND_NAME:$FRONTEND_VERSION .