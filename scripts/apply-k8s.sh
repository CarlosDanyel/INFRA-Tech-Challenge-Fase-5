#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/docker-public-config.sh
source scripts/repositories.sh
if [ ! -f .env ]; then echo 'Create .env from .env.example first'; exit 1; fi
context="$(kubectl config current-context)"
if [ "$context" != docker-desktop ] && [ "${FIAPX_ALLOW_CLUSTER:-false}" != true ]; then
  echo "Refusing context $context; set FIAPX_ALLOW_CLUSTER=true for a configured remote cluster"
  exit 1
fi
if [ "${1:-}" != --skip-build ]; then
  base="$(cd .. && pwd)"
  docker build -t fiapx/video-api:local "$(resolve_repository "$base" video-api-Tech-Challenge-Fase-5)"
  docker build -t fiapx/video-processor:local "$(resolve_repository "$base" video-processor-Tech-Challenge-Fase-5)"
  docker build -t fiapx/notification-service:local "$(resolve_repository "$base" notification-service-Tech-Challenge-Fase-5)"
fi
kubectl create namespace fiapx --dry-run=client -o yaml | kubectl apply -f -
kubectl -n fiapx create secret generic fiapx-secrets --from-env-file=.env --dry-run=client -o yaml | kubectl apply -f -
kubectl -n fiapx create configmap db-init --from-file=init.sql=db/init.sql --dry-run=client -o yaml | kubectl apply -f -
kubectl -n fiapx create configmap nginx-config --from-file=default.conf=nginx/default.conf --dry-run=client -o yaml | kubectl apply -f -
kubectl -n fiapx create configmap prometheus-config --from-file=prometheus.yml=monitoring/prometheus-k8s.yml --dry-run=client -o yaml | kubectl apply -f -
kubectl -n fiapx create configmap grafana-datasource --from-file=datasource.yml=monitoring/grafana-datasource.yml --dry-run=client -o yaml | kubectl apply -f -
kubectl -n fiapx create configmap grafana-dashboard-provider --from-file=provider.yml=monitoring/grafana-dashboard-provider.yml --dry-run=client -o yaml | kubectl apply -f -
kubectl -n fiapx create configmap grafana-dashboards --from-file=fiapx.json=monitoring/dashboards/fiapx.json --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/stack.yaml
if [ "${1:-}" = --skip-build ]; then exit 0; fi
kubectl -n fiapx rollout restart deployment/video-api deployment/video-processor deployment/notification-service
kubectl -n fiapx rollout status deployment/video-api --timeout=300s
kubectl -n fiapx rollout status deployment/video-processor --timeout=300s
kubectl -n fiapx rollout status deployment/notification-service --timeout=300s
