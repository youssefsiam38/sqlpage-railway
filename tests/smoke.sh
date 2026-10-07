#!/usr/bin/env bash
# shellcheck disable=SC2015
# Local smoke test: build/start the stack, then exercise the front door, the starter app (a form write
# to PostgreSQL read back), the page editor (a new page stored in sqlpage_files and served), its CSRF
# and path guards, and SITE_ACCESS=public.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
umask 077
CREDS_FILE="$TEST_TMP/creds"; export CREDS_FILE
printf 'admin:%s' 'local-test-only-sqlpage-password' > "$CREDS_FILE"

cleanup() {
  local rc=$?
  if [ "$rc" -ne 0 ]; then compose logs --no-color --tail 80 || true; fi
  compose down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$TEST_TMP"
  exit "$rc"
}
trap cleanup EXIT

section "start"
compose down -v --remove-orphans >/dev/null 2>&1 || true
if [ -n "${SQLPAGE_RAILWAY_IMAGE:-}" ]; then compose up -d --no-build; else compose up -d --build; fi
wait_for_code "$BASE_URL/healthz" 200 300 || die "not healthy"
pass "healthy"

section "health route"
assert_eq "health body" '{"status":"ok"}' "$(curl -s --max-time 20 "$BASE_URL/healthz")"
assert_eq "health refuses writes" "401" "$(http_code -X POST "$BASE_URL/healthz")"

section "front door (SITE_ACCESS=private)"
assert_eq "home page refused" "401" "$(http_code "$BASE_URL/")"
assert_eq "editor refused" "401" "$(http_code "$BASE_URL/admin/")"
assert_eq "form post refused" "401" "$(http_code -X POST "$BASE_URL/" --data 'author=x&message=y')"
assert_eq "wrong password refused" "401" "$(http_code -u 'admin:wrong-password-entirely' "$BASE_URL/")"
assert_eq "wrong user refused" "401" "$(http_code -u "nobody:$(cut -d: -f2- "$CREDS_FILE")" "$BASE_URL/")"
assert_eq "reserved sqlpage/ prefix refused" "403" "$(auth_code "$BASE_URL/sqlpage/sqlpage.json")"

section "starter app"
home=$(auth_get "$BASE_URL/")
assert_contains "home page renders from sqlpage_files" "Your SQLPage app is running" "$home"
assert_contains "guestbook starts empty" "Guestbook (0 entries)" "$home"
msg="smoke-$RANDOM-$RANDOM"
r=$(sign_guestbook "Smoke Tester" "$msg")
assert_eq "form write redirects (POST/redirect/GET)" "302 /?signed=1" "$r"
home=$(auth_get "$BASE_URL/?signed=1")
assert_contains "entry read back from PostgreSQL" "$msg" "$home"
assert_contains "count updated" "Guestbook (1 entries)" "$home"
assert_contains "confirmation shown" "your message was saved" "$home"
assert_eq "empty message ignored" "200" "$(auth_code -X POST "$BASE_URL/" --data 'author=x&message=')"

section "page editor"
ed=$(auth_get "$BASE_URL/admin/")
assert_contains "editor lists the starter page" "index.sql" "$ed"
assert_eq "new page not there yet" "404" "$(auth_code "$BASE_URL/report.sql")"
page="SELECT 'text' AS component, 'report-marker ' || count(*) || ' entries' AS contents FROM guestbook;"
assert_eq "save a new page" "302" "$(save_page report.sql "$page")"
assert_contains "new page served from the database" "report-marker 1 entries" "$(page_text report.sql)"
assert_contains "editor shows its source" "report-marker" "$(auth_get "$BASE_URL/admin/edit.sql?path=report.sql")"
assert_eq "update the page" "302" "$(save_page report.sql "SELECT 'text' AS component, 'report-v2' AS contents;")"
assert_contains "update served (cache refreshed)" "report-v2" "$(page_text report.sql)"
assert_eq "nested path" "302" "$(save_page reports/daily.sql "SELECT 'text' AS component, 'daily-marker' AS contents;")"
assert_contains "nested page served" "daily-marker" "$(page_text reports/daily.sql)"
assert_eq "delete the page" "302" "$(delete_page report.sql)"
assert_eq "deleted page answers 404 at once" "404" "$(sleep 1.2; auth_code "$BASE_URL/report.sql")"
assert_not_contains "deleted page left the list" "report.sql" "$(auth_get "$BASE_URL/admin/")"

section "editor guards"
assert_eq "save without Origin refused (CSRF)" "403" "$(save_page evil.sql "SELECT 1;" "")"
assert_eq "save from another site refused (CSRF)" "403" "$(save_page evil.sql "SELECT 1;" "https://evil.example")"
assert_eq "save over GET refused" "403" "$(auth_code "$BASE_URL/admin/save.sql?path=evil.sql&contents=x")"
assert_eq "evil page not created" "404" "$(auth_code "$BASE_URL/evil.sql")"
assert_eq "cannot write under admin/" "400" "$(save_page admin/x.sql "SELECT 1;")"
assert_eq "cannot traverse" "400" "$(save_page ../x.sql "SELECT 1;")"
assert_eq "cannot shadow the healthcheck" "400" "$(save_page healthz.sql "SELECT 1;")"
probe="SELECT 'text' AS component, 'pw-' || coalesce(sqlpage.environment_variable('ADMIN_PASSWORD'), 'absent') AS contents;"
assert_eq "save an env probe" "302" "$(save_page probe.sql "$probe")"
assert_contains "pages cannot read the admin password" "pw-absent" "$(page_text probe.sql)"
cid=$(compose ps -q sqlpage)
inner=$(docker exec "$cid" wget -S -q -O /dev/null http://127.0.0.1:8081/admin/ 2>&1 | head -1 || true)
assert_contains "editor re-checks the login inside SQLPage" "401" "$inner"
assert_eq "SQLPage not reachable except through the front door" "" "$(docker exec "$cid" sh -c 'netstat -ltn 2>/dev/null | grep ":8081" | grep -v "127.0.0.1:8081"' || true)"

section "SITE_ACCESS=public"
SITE_ACCESS=public compose up -d --no-build sqlpage >/dev/null 2>&1
wait_for_code "$BASE_URL/" 200 120 || fail "public home did not open"
assert_contains "home page public" "Your SQLPage app is running" "$(curl -s "$BASE_URL/")"
assert_contains "data survived the restart" "$msg" "$(curl -s "$BASE_URL/")"
for p in /admin /admin/ /admin/index.sql /admin/save.sql /ADMIN/ /Admin/edit.sql //admin/ /%61dmin/ /./admin/ /x/../admin/; do
  assert_eq "editor still locked: $p" "401" "$(http_code --path-as-is "$BASE_URL$p")"
done
assert_eq "editor open with the login" "200" "$(auth_code "$BASE_URL/admin/")"
summary
