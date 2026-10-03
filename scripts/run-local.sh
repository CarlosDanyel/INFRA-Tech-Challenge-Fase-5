#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/docker-public-config.sh
source scripts/repositories.sh
if [ ! -f .env ]; then echo 'Create .env from .env.example first'; exit 1; fi
java_bin="${JAVA_HOME:+$JAVA_HOME/bin/java}"
java_bin="${java_bin:-java}"
java_version="$("$java_bin" -version 2>&1)"
if [[ "$java_version" != *'version "21'* && "$java_version" != *'openjdk 21'* ]]; then
  echo 'Java 21 is required; set JAVA_HOME or put Java 21 in PATH' >&2
  exit 1
fi
set -a
source .env
set +a
docker compose up -d --wait postgres rabbitmq redis minio mailpit
until curl -fsS http://localhost:9000/minio/health/live >/dev/null; do sleep 2; done
docker compose up -d prometheus grafana
base="$(cd .. && pwd)"
for entry in 'video-api-Tech-Challenge-Fase-5:fiapx:18080' 'video-processor-Tech-Challenge-Fase-5:fiapx:18081' 'notification-service-Tech-Challenge-Fase-5:fiapx_notifications:18082'; do
  IFS=: read -r directory database port <<< "$entry"
  repository="$(resolve_repository "$base" "$directory")"
  (cd "$repository" && ./gradlew bootJar --no-daemon)
  pushd "$repository" >/dev/null
  nohup env DB_NAME="$database" DB_HOST=localhost SERVER_PORT="$port" RABBIT_HOST=localhost REDIS_HOST=localhost S3_ENDPOINT=http://localhost:9000 SMTP_HOST=localhost "$java_bin" -jar build/libs/app.jar > "/tmp/fiapx-$port.log" 2>&1 < /dev/null &
  echo "$!" > "/tmp/fiapx-$port.pid"
  popd >/dev/null
done
echo 'API: http://localhost:18080/swagger-ui/index.html'
echo 'Mailpit: http://localhost:8025'
echo 'Keep this terminal open while the services run.'
wait
