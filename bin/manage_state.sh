#!/usr/bin/env bash

ACTION=$1
AVAILABLE_ACTIONS="Available actions: [prepare, apply, destroy, re-create]"

cd "$(cd "$(dirname "$0")/.."; pwd)"

if [[ -z "$ACTION" ]]; then
  echo "Action not specified. $AVAILABLE_ACTIONS"
  exit 1
fi

function init() {
  echo "Preparing infrastructure..."
  echo "Connecting to cluster"
  aws eks --region us-east-2 update-kubeconfig --name yellow-taxi
  echo "Adding extra repositories"
  helm repo add nginx-ingress https://helm.nginx.com/stable
  helm repo add aws-secrets-manager https://aws.github.io/secrets-store-csi-driver-provider-aws
  helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
  helm upgrade --install -n kube-system secrets-provider-aws aws-secrets-manager/secrets-store-csi-driver-provider-aws
  helm upgrade --install -n kube-system csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver
  echo "Running helmfile init"
  helmfile init
}

function create() {
  echo "Applying CRDs..."
  helm upgrade --install -n kube-system secrets-provider-aws aws-secrets-manager/secrets-store-csi-driver-provider-aws
  helm upgrade --install -n kube-system csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver
  kubectl create namespace yellow-taxi
  kubectl apply -f charts/secret/templates/spc.yaml -n yellow-taxi
  echo "Applying infrastructure..."
  helmfile apply --file default-apps.yaml
  helmfile apply --file default-services.yaml
  helmfile apply --file yt-prod.yaml
}

function destroy() {
  echo "Destroying infrastructure..."
  helmfile destroy --file default-apps.yaml
  helmfile destroy --file default-services.yaml
  helmfile destroy --file local-dev.yaml
  helmfile destroy --file yt-prod.yaml
  kubectl delete -f charts/secret/templates/spc.yaml
  helm uninstall secrets-provider-aws -n kube-system
  helm uninstall csi-secrets-store -n kube-system
}

if [[ "$ACTION" = "prepare" ]]; then
  init
elif [[ "$ACTION" = "apply" ]]; then
  create
  echo "Getting ingress details:"
  kubectl get ingress
elif [[ "$ACTION" = "destroy" ]]; then
  destroy
elif [[ "$ACTION" = "re-create" ]]; then
  echo "Re-creating infrastructure..."
  destroy
  echo "Backoff..."
  sleep 30s
  create
  kubectl get ingress
else
  echo "Unknown action provided: $ACTION. Available actions: $AVAILABLE_ACTIONS"
fi

echo "Done!"
