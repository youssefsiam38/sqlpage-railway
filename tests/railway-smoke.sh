#!/usr/bin/env bash
# shellcheck disable=SC2015
# End-to-end test against a deployed instance, over HTTPS.
#   CREDS_FILE=/path/creds tests/railway-smoke.sh https://your-app.up.railway.app
# CREDS_FILE holds "admin:<ADMIN_PASSWORD>" (mode 600); it is never printed.
# Optional: STATE_OUT=/path/state.json (write data), STATE_IN=/path/state.json (verify it after a redeploy).
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
BASE_URL=${1:?usage: railway-smoke.sh https://domain}; BASE_URL=${BASE_URL%/}; export BASE_URL
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
trap 'rm -rf "$TEST_TMP"' EXIT
host=${BASE_URL#https://}

section "TLS and routing"
# Railway's edge serves 404 for a few seconds while a deployment takes over.
wait_for_code "$BASE_URL/healthz" 200 180 || true
assert_eq "health over https" "200" "$(http_code "$BASE_URL/healthz")"
assert_eq "health body" '{"status":"ok"}' "$(curl -s --max-time 20 "$BASE_URL/healthz")"
# curl verifies by default; a bad certificate fails the request (code 000) and sets ssl_verify_result
assert_eq "valid certificate" "0" "$(curl -s -o /dev/null -w '%{ssl_verify_result}' --max-time 20 "$BASE_URL/healthz" || echo failed)"
assert_contains "http -> https" "https://$host" "$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' --max-time 20 "http://$host/healthz")"

section "front door"
assert_eq "home page refused" "401" "$(http_code "$BASE_URL/")"
assert_eq "editor refused" "401" "$(http_code "$BASE_URL/admin/")"
assert_eq "anonymous form post refused" "401" "$(http_code -X POST "$BASE_URL/" --data 'author=x&message=y')"
assert_eq "anonymous page save refused" "401" "$(http_code -X POST "$BASE_URL/admin/save.sql" --data 'path=x.sql&contents=y')"
assert_eq "wrong password refused" "401" "$(http_code -u 'admin:wrong-password-entirely' "$BASE_URL/")"
assert_eq "editor case alias refused" "401" "$(http_code "$BASE_URL/ADMIN/")"

[ -n "${CREDS_FILE:-}" ] || { summary; exit $?; }

section "starter app over HTTPS"
assert_contains "home page renders from sqlpage_files" "Your SQLPage app is running" "$(auth_get "$BASE_URL/")"
assert_contains "served by SQLPage 0.46.3" "SQLPage v0.46.3" "$(auth_get "$BASE_URL/")"
msg="railway-$(date +%s)-$RANDOM"
r=$(sign_guestbook "Railway Tester" "$msg")
assert_contains "form write redirects" "302 /?signed=" "$r"
assert_contains "entry read back from PostgreSQL" "$msg" "$(auth_get "$BASE_URL/")"

section "page editor over HTTPS"
pg="e2e-$RANDOM.sql"
assert_eq "new page absent" "404" "$(auth_code "$BASE_URL/$pg")"
assert_eq "save a page" "302" "$(save_page "$pg" "SELECT 'text' AS component, 'e2e-marker ' || count(*) || ' rows' AS contents FROM guestbook WHERE message = '$msg';")"
assert_contains "new page served from the database" "e2e-marker 1 rows" "$(page_text "$pg")"
assert_eq "cross-site save refused (CSRF)" "403" "$(save_page "evil-$RANDOM.sql" "SELECT 1;" "https://evil.example")"
assert_eq "write under admin/ refused" "400" "$(save_page admin/x.sql "SELECT 1;")"

if [ -n "${STATE_OUT:-}" ]; then
  jq -n --arg m "$msg" --arg p "$pg" '{message:$m, page:$p}' > "$STATE_OUT"
  pass "state written ($pg)"
fi

if [ -n "${STATE_IN:-}" ]; then
  section "data from before the redeploy"
  old_msg=$(jq -r .message "$STATE_IN"); old_pg=$(jq -r .page "$STATE_IN")
  assert_contains "guestbook entry survived" "$old_msg" "$(auth_get "$BASE_URL/")"
  assert_contains "editor-created page survived" "e2e-marker 1 rows" "$(page_text "$old_pg")"
  assert_contains "page still listed in the editor" "$old_pg" "$(auth_get "$BASE_URL/admin/")"
fi
summary
