#!/bin/sh
set -eu
PROJECT_ID=my-project2-303004
CLUSTER_NAME=fast-api-terraform-cluster
SERVICE_NAME=fast-api-server
ZONE=us-central1-b

gcloud container clusters get-credentials ${CLUSTER_NAME} --project ${PROJECT_ID} --region ${ZONE}
IP_ADDRESS=`kubectl describe service ${SERVICE_NAME} | grep "LoadBalancer Ingress" | awk '{print $3}'`
PORT=5000

# health check
curl http://${IP_ADDRESS}:${PORT}/health
