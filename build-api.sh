#!/bin/bash
API_NAME="album-api"
ACR_NAME="acaalbumacr"
API_VERSION="v.1.0.0"



echo "building the API image in ACR: $ACR_NAME"
cd /Users/peterochesne/repos/startup/aca_album_azCli/code-to-cloud/src
az acr build --registry $ACR_NAME --image $API_NAME:$API_VERSION .