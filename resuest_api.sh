#!/bin/sh
set -eu
PROJECT_ID=my-project2-303004
SERVICE_NAME=fast-api-server
IP_ADDRESS=`kubectl describe service ${SERVICE_NAME} | grep "LoadBalancer Ingress" | awk '{print $3}'`

# health check
curl http://${IP_ADDRESS}/health
