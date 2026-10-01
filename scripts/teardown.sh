#!/usr/bin/env bash
# Tear down the fxwatch dev environment.
# Removes the ALB first (it's not managed by Terraform), then destroys infra/envs/dev.
# The bootstrap (state bucket, IAM roles) is left in place.

set -euo pipefail

REGION="${AWS_REGION:-ap-southeast-2}"
CLUSTER="fxwatch-dev"
ROOT="$(git rev-parse --show-toplevel)"
TF_DIR="$ROOT/infra/envs/dev"

step() { echo; echo "==> $*"; }

step "Pre-flight"
echo "AWS identity: $(aws sts get-caller-identity --query Arn --output text)"
echo
echo "This will DESTROY the $CLUSTER environment: EKS, RDS (no snapshot), ECR images, VPC."
read -r -p "Type '$CLUSTER' to confirm: " CONFIRM
[[ "$CONFIRM" == "$CLUSTER" ]] || { echo "Cancelled."; exit 1; }

VPC_ID="$(terraform -chdir="$TF_DIR" output -raw vpc_id)"

if aws eks describe-cluster --name "$CLUSTER" --region "$REGION" >/dev/null 2>&1; then
  aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" >/dev/null

  step "1/3 Removing ArgoCD apps (this deletes the Ingress and its ALB)"
  kubectl -n argocd delete application fxwatch-dev monitoring --ignore-not-found --timeout=10m
  # Safety net in case the Ingress outlived the app
  kubectl -n fxwatch delete ingress fxwatch --ignore-not-found --timeout=5m
else
  echo "Cluster not found, skipping Kubernetes cleanup."
fi

step "2/3 Waiting for the ALB to be deleted"
LBS=""
for _ in $(seq 1 30); do
  LBS="$(aws elbv2 describe-load-balancers --region "$REGION" \
    --query "LoadBalancers[?VpcId=='${VPC_ID}'].LoadBalancerName" --output text)"
  [[ -z "$LBS" ]] && break
  echo "  still deleting: $LBS"
  sleep 10
done
if [[ -n "$LBS" ]]; then
  echo "ALB still exists after 5 minutes. Check the controller logs before destroying:"
  echo "  kubectl -n kube-system logs deploy/aws-load-balancer-controller --tail=50"
  exit 1
fi
echo "ALB gone. Giving the controller a moment to clean up its security groups..."
sleep 30

step "3/3 terraform destroy"
terraform -chdir="$TF_DIR" destroy

echo
echo "✅ Teardown complete. Bring it back with ./scripts/bringup.sh"