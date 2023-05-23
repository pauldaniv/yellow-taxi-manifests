#!/usr/bin/env bash

ACTION=$1
AVAILABLE_ACTIONS="Available actions: [prepare, apply, destroy, re-create]"

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
  helm repo add aws-secrets-manager https://aws.github.io/secrets-store-csi-driver-provider-aws
  helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/chartst
  helm upgrade --install -n kube-system secrets-provider-aws aws-secrets-manager/secrets-store-csi-driver-provider-aws
  helm upgrade --install -n kube-system csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver
  echo "Running helmfile init"
  helmfile init
elif [[ "$ACTION" = "apply" ]]; then
#  echo "Applying CRDs..."
#  kubectl apply -f charts/secret/templates/spc.yaml
  echo "Applying infrastructure..."
  helmfile destroy --file default-apps.yaml
  helmfile destroy --file default-services.yaml
  helmfile apply --file yt-prod.yaml
  echo "Getting ingress details:"
  kubectl get ingress
elif [[ "$ACTION" = "destroy" ]]; then
  echo "Destroying infrastructure..."
  helmfile destroy --file default-apps.yaml
  helmfile destroy --file default-services.yaml
  helmfile destroy --file local-dev.yaml
  helmfile destroy --file yt-prod.yaml
  helm uninstall secrets-provider-aws -n kube-system
  helm uninstall csi-secrets-store -n kube-system
elif [[ "$ACTION" = "re-create" ]]; then
  echo "Re-creating infrastructure..."
  helmfile destroy --file default-apps.yaml
  helmfile destroy --file yt-prod.yaml
  echo "Backoff..."
  sleep 30s
  helmfile apply --file default-apps.yaml
  helmfile apply --file yt-prod.yaml
  kubectl get ingress
else
  echo "Unknown action provided: $ACTION. Available actions: $AVAILABLE_ACTIONS"
fi

echo "Done!"
