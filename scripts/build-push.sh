#!/usr/bin/env bash
# Build and push fxwatch images to ECR.
#
# Usage:
#   ./scripts/build-push.sh backend    # api + worker
#   ./scripts/build-push.sh frontend   # frontend (skipped until it exists)
#   ./scripts/build-push.sh all        # everything (default)
#
# Env overrides:
#   AWS_REGION   default ap-southeast-2
#   TAG          default = short git commit SHA
#   ALLOW_DIRTY  set to 1 to build with uncommitted changes

set -euo pipefail

REGION="${AWS_REGION:-ap-southeast-2}"
ROOT="$(git rev-parse --show-toplevel)"
TAG="${TAG:-$(git rev-parse --short HEAD)}"

# ECR tags are immutable, so the tag must match committed code
if [[ "${ALLOW_DIRTY:-0}" != "1" ]] && ! git diff --quiet HEAD; then
  echo "❌ You have uncommitted changes. Commit first (or set ALLOW_DIRTY=1)."
  exit 1
fi

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "🔐 Logging in to ${REGISTRY}"
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

# build_push <repo-name> <context-dir> [docker-target]
build_push() {
  local repo="$1" context="$2" target="${3:-}"
  local image="${REGISTRY}/${repo}:${TAG}"

  if aws ecr describe-images --region "$REGION" --repository-name "$repo" \
       --image-ids imageTag="$TAG" >/dev/null 2>&1; then
    echo "⏭️  ${repo}:${TAG} already in ECR, skipping"
    return
  fi

  echo "🔨 Building ${repo}:${TAG}"
  docker build --platform linux/amd64 \
    ${target:+--target "$target"} \
    -t "$image" "$context"

  echo "🚀 Pushing ${repo}:${TAG}"
  docker push "$image"
}

backend() {
  build_push fxwatch-api    "$ROOT/app/backend" api
  build_push fxwatch-worker "$ROOT/app/backend" worker
}

frontend() {
  if [[ ! -f "$ROOT/app/frontend/Dockerfile" ]]; then
    echo "⏭️  app/frontend/Dockerfile not found, skipping frontend"
    return
  fi
  build_push fxwatch-frontend "$ROOT/app/frontend"
}

case "${1:-all}" in
  backend)  backend ;;
  frontend) frontend ;;
  all)      backend; frontend ;;
  *)
    echo "Usage: $0 [backend|frontend|all]"
    exit 1
    ;;
esac

echo "✅ Done. Tag: ${TAG}"