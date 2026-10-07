#!/usr/bin/env bash
# shellcheck disable=SC2015
# Static validation: shell syntax, shellcheck, compose config, image pins, security invariants.
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd); export REPO_ROOT
cd "$REPO_ROOT"
# shellcheck source=tests/lib.sh
. "$REPO_ROOT/tests/lib.sh"
trap 'rm -rf "$TEST_TMP"' EXIT

section "shell syntax"
if sh -n scripts/entrypoint.sh 2>/dev/null; then pass "parses (sh): scripts/entrypoint.sh"; else fail "syntax error: scripts/entrypoint.sh"; fi
for f in tests/*.sh; do
  if bash -n "$f" 2>/dev/null; then pass "parses: $f"; else fail "syntax error: $f"; fi
done

section "shellcheck"
if command -v shellcheck >/dev/null; then
  # the image is busybox: the entrypoint must stay POSIX sh (plus busybox's wait -n)
  if shellcheck -s sh -e SC3045 scripts/entrypoint.sh; then pass "shellcheck entrypoint (POSIX sh)"; else fail "shellcheck entrypoint"; fi
  if shellcheck -x -s bash tests/*.sh; then pass "shellcheck tests"; else fail "shellcheck tests"; fi
else
  echo "  SKIP  shellcheck not installed"
fi

section "compose"
if docker compose -f compose.yaml config -q; then pass "compose config"; else fail "compose config"; fi
cc=$(cat compose.yaml)
assert_contains "postgres pinned by tag and digest" 'postgres:16.15@sha256:' "$cc"
assert_contains "postgres volume at the parent directory" 'pg:/var/lib/postgresql' "$cc"
assert_contains "PGDATA below the volume root" 'PGDATA: /var/lib/postgresql/pgdata' "$cc"
assert_contains "app port bound to loopback on the host" "'127.0.0.1:" "$cc"

section "dockerfile pins"
df=$(cat Dockerfile)
if grep -qE 'lovasoa/sqlpage:v[0-9.]+@sha256:[0-9a-f]{64}' Dockerfile; then pass "SQLPage pinned by tag and digest"; else fail "SQLPage not digest-pinned"; fi
if grep -qE 'caddy:[0-9.]+-alpine@sha256:[0-9a-f]{64}' Dockerfile; then pass "Caddy pinned by tag and digest"; else fail "Caddy not digest-pinned"; fi
assert_contains "entrypoint is the wrapper" 'ENTRYPOINT ["/usr/local/bin/sqlpage-railway-entrypoint"]' "$df"
assert_contains "SQLPage bound to loopback in the image" 'SQLPAGE_LISTEN_ON=127.0.0.1:8081' "$df"
assert_contains "runs unprivileged" 'USER sqlpage' "$df"

section "the front door cannot be configured away"
ep=$(cat scripts/entrypoint.sh)
assert_contains "refuses a non-loopback SQLPAGE_LISTEN_ON" 'keeps SQLPage on loopback on purpose' "$ep"
assert_contains "requires an admin password" 'missing required variable: ADMIN_PASSWORD' "$ep"
assert_contains "minimum password length" '-ge 12' "$ep"
assert_contains "rejects unknown SITE_ACCESS values" 'SITE_ACCESS must be' "$ep"
assert_contains "health route is GET/HEAD only" 'method GET HEAD' "$ep"
assert_contains "editor gated in public mode" '@admin path /admin /admin/*' "$ep"
assert_contains "password hashed from stdin, not argv" "printf '%s\\n' \"\$ADMIN_PASSWORD\" | caddy hash-password" "$ep"
assert_contains "SQLPage never sees the plaintext password" 'env -u PORT -u SQLPAGE_PORT -u ADMIN_PASSWORD' "$ep"
assert_contains "generated config is validated" 'caddy validate' "$ep"

section "editor pages"
for f in www/admin/*.sql; do
  if grep -q "'authentication' AS component" "$f" && grep -q "ADMIN_PASSWORD_HASH" "$f"; then pass "login re-checked in $f"; else fail "$f has no authentication check"; fi
done
for f in www/admin/save.sql www/admin/delete.sql; do
  if grep -q "sqlpage.header('origin')" "$f" && grep -q "request_method() = 'POST'" "$f"; then pass "CSRF guard in $f"; else fail "$f has no CSRF guard"; fi
done
assert_contains "save rejects admin/ and sqlpage/ paths" "NOT IN ('admin', 'sqlpage')" "$(cat www/admin/save.sql)"
extra=""
for f in www/*.sql; do [ "$f" = www/healthz.sql ] || extra="$extra $f"; done
if [ -n "$extra" ]; then fail "unexpected public .sql on disk (disk files shadow the database):$extra"; else pass "only healthz.sql is public on disk"; fi

section "migrations"
for f in sqlpage/migrations/*.sql; do
  if [[ $(basename "$f") =~ ^[0-9]{4}_[a-z0-9_]+\.sql$ ]]; then pass "migration name: $f"; else fail "bad migration name: $f"; fi
done
assert_contains "sqlpage_files created" 'CREATE TABLE IF NOT EXISTS sqlpage_files' "$(cat sqlpage/migrations/0001_sqlpage_files.sql)"
assert_contains "last_modified bumped on update" 'BEFORE UPDATE ON sqlpage_files' "$(cat sqlpage/migrations/0001_sqlpage_files.sql)"
assert_contains "starter page not overwritten on re-run" 'ON CONFLICT (path) DO NOTHING' "$(cat sqlpage/migrations/0002_starter_app.sql)"

section "workflows"
override=$(grep -oE '[A-Z_]*_RAILWAY_IMAGE' compose.yaml | head -1)
for wf in .github/workflows/*.yml; do
  if grep -q 'candidate' "$wf" && ! grep -q "$override" "$wf"; then
    fail "$wf tests a candidate image but never sets $override"
  else
    pass "image override name matches compose in $wf"
  fi
  if grep -qE 'uses: .*@[0-9a-f]{40}' "$wf" && ! grep -qE 'uses: .*@v[0-9]+\s*$' "$wf"; then
    pass "actions pinned by SHA in $wf"
  else
    fail "unpinned action in $wf"
  fi
done

section "log streams"
if grep -q '^log()' scripts/entrypoint.sh && ! grep '^log()' scripts/entrypoint.sh | grep -q '>&2'; then
  pass "routine logs go to stdout"
else
  fail "log() writes to stderr; Railway would show every start-up line as an error"
fi
if grep '^fail()' scripts/entrypoint.sh | grep -q '>&2'; then pass "failures go to stderr"; else fail "fail() does not write to stderr"; fi

section "no tracked secrets"
if git rev-parse --git-dir >/dev/null 2>&1; then
  if git grep -nIE '(BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-)' -- . >/dev/null 2>&1; then
    fail "credential pattern in tracked files"
  else
    pass "no credential patterns in tracked files"
  fi
  if git ls-files --error-unmatch .env >/dev/null 2>&1; then fail ".env is tracked"; else pass ".env not tracked"; fi
else
  echo "  SKIP  not a git checkout"
fi
summary
