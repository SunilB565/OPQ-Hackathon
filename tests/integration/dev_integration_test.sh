#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <alb_dns> <admin_token>"
  exit 2
fi
ALB="$1"
ADMIN_TOKEN="$2"

# Prefer HTTPS (if available), fall back to HTTP
if curl -sS --head "https://${ALB}" >/dev/null 2>&1; then
  BASE_URL="https://${ALB}"
else
  BASE_URL="http://${ALB}"
fi

echo "Using endpoint: $BASE_URL"

# helper
http() { curl -sS -w "\nHTTP_STATUS:%{http_code}\n" -X "$1" "$2" -H "Content-Type: application/json" ${3:-} -d '${4:-}'; }

echo "1) GET /api/storage/notes"
# 1) list notes
echo "1) GET /api/storage/notes"
resp=$(http GET "$BASE_URL/api/storage/notes")
echo "$resp"

echo "2) POST /api/storage/requests"
# 2) create request for alice for note 1
echo "2) POST /api/storage/requests"
req_payload='{"student":"alice","noteId":1}'
resp=$(curl -sS -X POST "$BASE_URL/api/storage/requests" -H "Content-Type: application/json" -d "$req_payload")
echo "$resp"

# extract request id
req_id=$(echo "$resp" | python3 -c 'import sys, json
try:
  obj=json.load(sys.stdin)
  print(obj.get("id", ""))
except:
  print("")')
if [ -z "$req_id" ]; then
  echo "Failed to create request"
  exit 1
fi

echo "Created request id: $req_id"

# 3) approve as admin
echo "3) POST /api/storage/approve"
approve_payload=$(printf '{"requestId":%s}' "$req_id")
if [ -n "$ADMIN_TOKEN" ]; then
  resp=$(curl -sS -X POST "$BASE_URL/api/storage/approve" -H "Content-Type: application/json" -H "X-ADMIN-TOKEN: $ADMIN_TOKEN" -d "$approve_payload")
else
  resp=$(curl -sS -X POST "$BASE_URL/api/storage/approve" -H "Content-Type: application/json" -d "$approve_payload")
fi

echo "$resp"

# 4) fetch content as alice
echo "4) GET /api/storage/notes/1/content?student=alice"
resp=$(curl -sS "$BASE_URL/api/storage/notes/1/content?student=alice")
echo "$resp"

# simple check that response contains 'content'
if echo "$resp" | grep -q "content"; then
  echo "Integration test: SUCCESS"
  exit 0
else
  echo "Integration test: FAILED"
  exit 1
fi
