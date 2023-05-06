#!/usr/bin/env bash

ACTION=$1
AVAILABLE_ACTIONS="Available actions: [prepare, apply, destroy]"

cd "$(cd "$(dirname "$0")/.."; pwd)"

if [[ -z "$ACTION" ]]; then
  echo "Action not specified. $AVAILABLE_ACTIONS"
  exit 1
fi

if [[ "$ACTION" = "prepare" ]]; then
  echo "Preparing infrastructure..."
  echo "Connecting to cluster"
  aws eks --region us-east-2 update-kubeconfig --name yellow-taxi
  echo "Adding extra repositories"
  helm repo add nginx-ingress https://helm.nginx.com/stable
  echo "Running helmfile init"
  helmfile init
elif [[ "$ACTION" = "apply" ]]; then
  echo "Applying infrastructure..."
  aws --version
  helmfile apply
  echo "Getting ingress details:"
  kubectl get ingress
elif [[ "$ACTION" = "destroy" ]]; then
  echo "Destroying infrastructure..."
  helmfile destroy
else
  echo "Unknown action provided: $ACTION. Available actions: $AVAILABLE_ACTIONS"
fi

echo "Done!"
