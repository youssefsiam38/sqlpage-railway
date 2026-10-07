#!/usr/bin/env bash
# shellcheck disable=SC2015  # `cond && pass || fail` is intentional; pass/fail always succeed
# Shared helpers for sqlpage-railway tests. Source this file; do not execute it.
# Secrets are never echoed. Only names, lengths, and pass/fail results are printed.

: "${BASE_URL:=http://127.0.0.1:8080}"
: "${TEST_TIMEOUT:=300}"

TEST_TMP="${TEST_TMP:-$(mktemp -d)}"
export TEST_TMP
_PASS=0; _FAIL=0

pass() { _PASS=$((_PASS+1)); printf '  PASS  %s\n' "$*"; }
fail() { _FAIL=$((_FAIL+1)); printf '  FAIL  %s\n' "$*" >&2; }
die()  { printf 'FATAL: %s\n' "$*" >&2; exit 1; }
section() { printf '\n== %s ==\n' "$*"; }
summary() { printf '\n%d passed, %d failed\n' "$_PASS" "$_FAIL"; [ "$_FAIL" -eq 0 ]; }

# here-strings, not pipes: `grep -q` exits on the first match and a pipe writer would get SIGPIPE
assert_eq() { if [ "$2" = "$3" ]; then pass "$1 ($3)"; else fail "$1: expected [$2] got [$3]"; fi; }
assert_contains() { if grep -qF -- "$2" <<<"$3"; then pass "$1"; else fail "$1: missing [$2]"; fi; }
assert_not_contains() { if grep -qF -- "$2" <<<"$3"; then fail "$1: found forbidden [$2]"; else pass "$1"; fi; }

# CREDS_FILE holds "username:password" and is never printed. curl reads it from a mode-600 config
# file (-K), so the password is not on any command line.
_curlrc() {
  local rc="$TEST_TMP/curlrc"
  if [ ! -s "$rc" ]; then
    ( umask 077; printf 'user = "%s"\n' "$(cat "${CREDS_FILE:?CREDS_FILE not set}")" > "$rc" )
  fi
  printf '%s' "$rc"
}

http_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$@"; }
auth_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 30 -K "$(_curlrc)" "$@"; }
auth_get()  { curl -s --max-time 30 -K "$(_curlrc)" "$@"; }

wait_for_code() {
  local url=$1 want=$2 timeout=${3:-$TEST_TIMEOUT} start code
  start=$(date +%s)
  while :; do
    code=$(http_code "$url" || true)
    [ "$code" = "$want" ] && return 0
    if [ $(( $(date +%s) - start )) -ge "$timeout" ]; then printf 'timed out waiting for %s -> %s (last %s)\n' "$url" "$want" "$code" >&2; return 1; fi
    sleep 3
  done
}

# sign_guestbook AUTHOR MESSAGE -> prints "<http code> <redirect url path>"
sign_guestbook() {
  curl -s -o /dev/null -w '%{http_code} %{redirect_url}' --max-time 30 -K "$(_curlrc)" -X POST "$BASE_URL/" \
    --data-urlencode "author=$1" --data-urlencode "message=$2" | sed -E 's#https?://[^/]*##'
}

# save_page PATH CONTENTS [ORIGIN] -> prints the HTTP code. ORIGIN defaults to this site (what a browser sends).
save_page() {
  local origin=${3-$BASE_URL}
  local hdr=()
  [ -n "$origin" ] && hdr=(-H "Origin: $origin")
  curl -s -o /dev/null -w '%{http_code}' --max-time 30 -K "$(_curlrc)" "${hdr[@]}" -X POST \
    "$BASE_URL/admin/save.sql" --data-urlencode "path=$1" --data-urlencode "contents=$2"
}

# delete_page PATH -> prints the HTTP code
delete_page() {
  curl -s -o /dev/null -w '%{http_code}' --max-time 30 -K "$(_curlrc)" -H "Origin: $BASE_URL" -X POST \
    "$BASE_URL/admin/delete.sql" --data-urlencode "path=$1" --data-urlencode confirm=yes
}

# page_text PATH -> the page body, retried briefly: SQLPage re-checks a cached page at most once a second
page_text() { sleep 1.2; auth_get "$BASE_URL/$1"; }

compose() { docker compose -f "$REPO_ROOT/compose.yaml" "$@"; }
