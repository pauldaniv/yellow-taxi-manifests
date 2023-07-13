#!/usr/bin/env bash

ACTION=$1
AVAILABLE_ACTIONS="Available actions: [prepare, apply, destroy, re-create]"

cd "$(cd "$(dirname "$0")/.."; pwd)"
echo 1
if [[ -z "$ACTION" ]]; then
  echo "Action not specified. $AVAILABLE_ACTIONS"
  exit 1
fi

function init() {
  echo "Preparing infrastructure..."
  echo "Connecting to cluster"
  aws eks --region us-east-2 update-kubeconfig --name yellow-taxi
  echo "Adding extra repositories"
  helm repo add aws-secrets-manager https://aws.github.io/secrets-store-csi-driver-provider-aws
  helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
  helm repo add jetstack https://charts.jetstack.io
  helm repo update
#  helm repo add external-secrets https://charts.external-secrets.io
  echo "Running helmfile init"
  helmfile init
}

function create() {
  echo "Applying CRDs..."
  kubectl create namespace yellow-taxi
  helm upgrade --install -n kube-system secrets-provider-aws aws-secrets-manager/secrets-store-csi-driver-provider-aws
  helm upgrade --install -n kube-system csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver --set syncSecret.enabled=true
#  helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.9.1 --set installCRDs=true
  helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.12.0 --set installCRDs=true
  # switch away from external secrets for now
#  kubectl create namespace external-secrets
#  kubectl apply -f charts/secret/templates/spc.yaml -n yellow-taxi

  echo "Applying infrastructure..."
  helmfile apply --file default-services.yaml
  helmfile apply --file yt-prod.yaml
  helmfile apply --file default-apps.yaml

  echo "Getting ingress details:"
  kubectl get ingress -n yellow-taxi
}

function destroy() {
  echo "Destroying infrastructure..."
  helmfile destroy --file default-apps.yaml
  helmfile destroy --file yt-prod.yaml
  helmfile destroy --file default-services.yaml
  helm uninstall --namespace kube-system csi-secrets-store
  helm uninstall --namespace kube-system secrets-provider-aws
  helm uninstall --namespace yellow-taxi cert-manager
  helm uninstall --namespace cert-manager cert-manager
  helm uninstall cert-manager --namespace cert-manager
  kubectl delete namespace cert-manager
  kubectl delete namespace yellow-taxi
}

if [[ "$ACTION" = "prepare" ]]; then
  init
elif [[ "$ACTION" = "apply" ]]; then
  create
elif [[ "$ACTION" = "destroy" ]]; then
  destroy
elif [[ "$ACTION" = "re-create" ]]; then
  echo "Re-creating infrastructure..."
  destroy
  echo "Backoff..."
  sleep 14s
  create
else
  echo "Unknown action provided: $ACTION. Available actions: $AVAILABLE_ACTIONS"
fi

echo "Done!"
