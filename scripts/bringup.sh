#!/usr/bin/env bash
# Rebuild the fxwatch dev environment from scratch:
# infra → images → gitops values → platform add-ons → monitoring → app.

set -euo pipefail

REGION="${AWS_REGION:-ap-southeast-2}"
CLUSTER="fxwatch-dev"
ROOT="$(git rev-parse --show-toplevel)"
TF_DIR="$ROOT/infra/envs/dev"
VALUES="$ROOT/gitops/envs/dev/values.yaml"

step() { echo; echo "==> $*"; }

step "Pre-flight"
for cmd in aws terraform kubectl helm docker git openssl; do
  command -v "$cmd" >/dev/null || { echo "Missing tool: $cmd"; exit 1; }
done
echo "AWS identity: $(aws sts get-caller-identity --query Arn --output text)"
[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || { echo "Switch to main first."; exit 1; }
git diff --quiet HEAD || { echo "Commit or stash your changes first."; exit 1; }
git pull --rebase

step "1/8 Terraform apply (VPC, EKS, ECR, RDS, IAM)"
terraform -chdir="$TF_DIR" init -input=false
terraform -chdir="$TF_DIR" apply

step "2/8 Connecting kubectl"
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"
kubectl get nodes

step "3/8 Building and pushing images (ECR starts empty after a teardown)"
"$ROOT/scripts/build-push.sh" all
TAG="$(git rev-parse --short HEAD)"

step "4/8 Updating gitops values (image tags, RDS address, secret ARN)"
RDS_ADDRESS="$(terraform -chdir="$TF_DIR" output -raw rds_address)"
SECRET_ARN="$(terraform -chdir="$TF_DIR" output -raw rds_secret_arn)"
VPC_ID="$(terraform -chdir="$TF_DIR" output -raw vpc_id)"

sed -i -E \
  -e "s|^(  backendTag:).*|\1 \"${TAG}\"|" \
  -e "s|^(  frontendTag:).*|\1 \"${TAG}\"|" \
  -e "s|^(  host:).*|\1 ${RDS_ADDRESS}|" \
  -e "s|^(  secretArn:).*|\1 \"${SECRET_ARN}\"|" \
  "$VALUES"

if ! git diff --quiet -- "$VALUES"; then
  git diff -- "$VALUES"
  git add "$VALUES"
  git commit -m "chore(gitops): update dev values after bring-up"
  git push
else
  echo "Values already up to date."
fi

step "5/8 Installing platform add-ons"
helm repo add eks https://aws.github.io/eks-charts >/dev/null
helm repo add external-secrets https://charts.external-secrets.io >/dev/null
helm repo add stakater https://stakater.github.io/stakater-charts >/dev/null
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo update >/dev/null

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER" \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="$REGION" \
  --set vpcId="$VPC_ID"

helm upgrade --install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace

helm upgrade --install reloader stakater/reloader \
  -n reloader --create-namespace

helm upgrade --install argocd argo/argo-cd \
  -n argocd --create-namespace \
  --set dex.enabled=false \
  --set notifications.enabled=false

kubectl -n kube-system rollout status deploy/aws-load-balancer-controller --timeout=5m
kubectl -n external-secrets rollout status deploy/external-secrets --timeout=5m
kubectl -n argocd rollout status deploy/argocd-server --timeout=5m

step "6/8 Grafana admin secret"
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
if ! kubectl -n monitoring get secret grafana-admin >/dev/null 2>&1; then
  kubectl -n monitoring create secret generic grafana-admin \
    --from-literal=admin-user=admin \
    --from-literal=admin-password="$(openssl rand -base64 18)"
else
  echo "grafana-admin already exists."
fi

step "7/8 Monitoring stack (must come first: it installs the CRDs the app chart uses)"
kubectl apply -f "$ROOT/gitops/argocd/monitoring.yaml"
echo "Waiting for monitoring CRDs..."
until kubectl get crd servicemonitors.monitoring.coreos.com prometheusrules.monitoring.coreos.com >/dev/null 2>&1; do
  sleep 10
done
kubectl wait --for=condition=Established \
  crd/servicemonitors.monitoring.coreos.com \
  crd/prometheusrules.monitoring.coreos.com --timeout=5m

step "8/8 fxwatch app"
kubectl apply -f "$ROOT/gitops/argocd/fxwatch-dev.yaml"

echo "Waiting for the ALB address (takes a few minutes)..."
ALB=""
for _ in $(seq 1 60); do
  ALB="$(kubectl -n fxwatch get ingress fxwatch \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
  [[ -n "$ALB" ]] && break
  sleep 10
done

echo
echo "✅ Bring-up complete."
echo
echo "App:      http://${ALB:-<not ready yet, check: kubectl -n fxwatch get ingress>}"
echo "          (allow 1-2 more minutes for ALB health checks)"
echo
echo "ArgoCD:   kubectl -n argocd port-forward svc/argocd-server 8081:443   → https://localhost:8081"
echo "          password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
echo
echo "Grafana:  kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3001:80   → http://localhost:3001"
echo "          password: kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d; echo"
echo
echo "Seed data now instead of waiting for the schedule:"
echo "          kubectl -n fxwatch create job --from=cronjob/fxwatch-worker worker-seed"