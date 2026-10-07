#!/usr/bin/env bash
# shellcheck disable=SC2015
# Persistence: guestbook rows and pages written through the editor live in PostgreSQL, so they survive
# recreating both containers on the same database volume (and migrations do not re-run).
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

up() { if [ -n "${SQLPAGE_RAILWAY_IMAGE:-}" ]; then compose up -d --no-build; else compose up -d --build; fi; }

section "fresh stack"
compose down -v --remove-orphans >/dev/null 2>&1 || true
up; wait_for_code "$BASE_URL/healthz" 200 300 || die "not ready"

section "write state"
msg="persist-$RANDOM-$RANDOM"
assert_eq "guestbook entry saved" "302 /?signed=1" "$(sign_guestbook "Persist Tester" "$msg")"
assert_eq "page saved" "302" "$(save_page kept.sql "SELECT 'text' AS component, 'kept-marker' AS contents;")"
assert_eq "starter page edited" "302" "$(save_page index.sql "SELECT 'text' AS component, 'edited-home-marker' AS contents;")"
assert_contains "edited home served" "edited-home-marker" "$(page_text "")"

section "recreate both containers on the same volume"
compose down >/dev/null 2>&1
up; wait_for_code "$BASE_URL/healthz" 200 300 || die "not ready after recreate"

section "verify"
assert_contains "edited home page kept (migrations did not re-seed it)" "edited-home-marker" "$(page_text "")"
assert_contains "editor-created page kept" "kept-marker" "$(page_text kept.sql)"
listing=$(auth_get "$BASE_URL/admin/")
assert_contains "page still listed" "kept.sql" "$listing"
assert_contains "guestbook table still listed" "guestbook" "$listing"
probe="SELECT 'text' AS component, 'rows-' || count(*) || '-' || max(message) AS contents FROM guestbook;"
assert_eq "probe page saved" "302" "$(save_page probe.sql "$probe")"
assert_contains "guestbook row kept" "rows-1-$msg" "$(page_text probe.sql)"
assert_eq "credentials unchanged" "200" "$(auth_code "$BASE_URL/admin/")"
assert_eq "anonymous still refused" "401" "$(http_code "$BASE_URL/")"
summary
