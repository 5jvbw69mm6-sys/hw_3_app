#!/usr/bin/env bash
set -euo pipefail

PROJECT="hw3check-$$"
COMPOSE="docker compose -p $PROJECT -f compose.yaml"
PORT=8099
export APP_PORT=$PORT
APP_URL="http://127.0.0.1:${PORT}"
TIMEOUT=30

cleanup() {
  echo "[cleanup] removing project $PROJECT"
  $COMPOSE down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

wait_code() {
  local url=$1 want=$2
  local deadline=$((SECONDS + TIMEOUT))
  until [ "$(curl -s -o /dev/null -w '%{http_code}' "$url")" = "$want" ]; do
    [ $SECONDS -lt $deadline ] || fail "timeout waiting for $url == $want"
    sleep 1
  done
}

get_count() {
  curl -fsS "$APP_URL/" | python3 -c "import sys,json; print(json.load(sys.stdin)['count'])"
}

echo "[1] starting fresh stack"
$COMPOSE up -d --build
wait_code "$APP_URL/readyz" 200

echo "[2] checking initial counter == 0"
[ "$(get_count)" = "0" ] || fail "initial counter is not 0"

N=5
echo "[3] sending $N increments"
for i in $(seq 1 "$N"); do curl -fsS -X POST "$APP_URL/increment" >/dev/null; done
[ "$(get_count)" = "$N" ] || fail "counter after increments is wrong"

echo "[4] recreating app only, checking persistence"
$COMPOSE up -d --force-recreate --no-deps app
wait_code "$APP_URL/readyz" 200
[ "$(get_count)" = "$N" ] || fail "counter lost after app recreate"

echo "[5] stopping redis, checking degraded mode"
$COMPOSE stop redis
wait_code "$APP_URL/readyz" 503
[ "$(curl -s -o /dev/null -w '%{http_code}' "$APP_URL/healthz")" = "200" ] || fail "healthz not 200 while redis down"

echo "[6] starting redis, checking recovery"
$COMPOSE start redis
wait_code "$APP_URL/readyz" 200
[ "$(get_count)" = "$N" ] || fail "counter changed unexpectedly after recovery"
curl -fsS -X POST "$APP_URL/increment" >/dev/null
[ "$(get_count)" = "$((N+1))" ] || fail "increment after recovery failed"

echo "[7] making a backup"
$COMPOSE stop app redis
BACKUP_DIR="./backup-$(date +%s)"
mkdir -p "$BACKUP_DIR"
VOLUME_NAME="${PROJECT}_redis-data"
docker run --rm -v "${VOLUME_NAME}:/data:ro" -v "$(pwd)/$BACKUP_DIR:/backup" alpine \
  sh -c "cp -a /data/. /backup/"
echo "backup saved to $BACKUP_DIR"

echo "ALL CHECKS PASSED"