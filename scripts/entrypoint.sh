#!/bin/sh
# sqlpage-railway entrypoint (busybox sh).
#
#   1. validate variables (names and lengths only; values are never printed)
#   2. hash the admin password: bcrypt for Caddy, argon2id for the /admin/ pages inside SQLPage
#   3. run SQLPage on loopback and Caddy, with HTTP basic authentication, on the public port
#   4. supervise both; if either exits, the container exits and Railway restarts it
#
# SQLPage runs whatever SQL its pages contain, and the bundled editor writes pages. A public URL
# with an unauthenticated editor would hand the database to anyone, so the front door is not optional.
set -u

# Railway colours a log line by the stream it arrived on, so routine start-up messages go to stdout
# and only failures go to stderr.
log()  { printf '[sqlpage-railway] %s\n' "$*"; }
fail() { printf '[sqlpage-railway] FATAL: %s\n' "$*" >&2; exit 1; }

: "${ADMIN_USERNAME:=admin}"
: "${SITE_ACCESS:=private}"
: "${SQLPAGE_LISTEN_ON:=127.0.0.1:8081}"
RUN_DIR=/tmp/sqlpage-railway
CADDYFILE=$RUN_DIR/Caddyfile

# The public listener takes the platform's PORT; Railway health-checks that port.
PUBLIC_PORT="${PORT:-8080}"
case "$PUBLIC_PORT" in
  ''|*[!0-9]*) fail "PORT must be a number, got \"$PUBLIC_PORT\"" ;;
esac

case "$SQLPAGE_LISTEN_ON" in
  127.0.0.1:*|localhost:*|'[::1]':*) ;;
  *) fail "SQLPAGE_LISTEN_ON is \"$SQLPAGE_LISTEN_ON\". This image keeps SQLPage on loopback on purpose so that every request passes the password front door. Remove the variable." ;;
esac
INTERNAL_PORT=${SQLPAGE_LISTEN_ON##*:}
[ "$INTERNAL_PORT" != "$PUBLIC_PORT" ] || fail "PORT and the internal SQLPage port are both $PUBLIC_PORT; change PORT."

case "$SITE_ACCESS" in
  private|public) ;;
  *) fail "SITE_ACCESS must be \"private\" (whole site behind the password) or \"public\" (only /admin/ behind it), got \"$SITE_ACCESS\"" ;;
esac

[ -n "${DATABASE_URL:-}" ] || fail "missing required variable: DATABASE_URL (the template sets it from the db service)"
[ -n "${ADMIN_PASSWORD:-}" ] || fail "missing required variable: ADMIN_PASSWORD. The page editor runs arbitrary SQL; it cannot be left open."
[ "${#ADMIN_PASSWORD}" -ge 12 ] || fail "ADMIN_PASSWORD must be at least 12 characters"
case "$ADMIN_USERNAME" in
  ''|*[!A-Za-z0-9._-]*) fail "ADMIN_USERNAME may contain only letters, digits, dot, underscore and hyphen" ;;
esac

umask 077
mkdir -p "$RUN_DIR" "$XDG_DATA_HOME" || fail "cannot create $RUN_DIR"

# The plaintext goes to caddy on stdin, never on argv.
bcrypt_hash=$(printf '%s\n' "$ADMIN_PASSWORD" | caddy hash-password 2>/dev/null) || fail "could not hash ADMIN_PASSWORD"
argon_hash=$(printf '%s\n' "$ADMIN_PASSWORD" | caddy hash-password --algorithm argon2id 2>/dev/null) || fail "could not hash ADMIN_PASSWORD"
{ [ -n "$bcrypt_hash" ] && [ -n "$argon_hash" ]; } || fail "empty password hash"

UPSTREAM="127.0.0.1:${INTERNAL_PORT}"
{
  cat <<EOF
{
	admin off
	auto_https off
	persist_config off
}
:${PUBLIC_PORT} {
	# The platform healthcheck has no credentials. This route runs one trivial query against the
	# database (a fixed file baked into the image) and returns only {"status":"ok"}.
	@health {
		method GET HEAD
		path /healthz
	}
	handle @health {
		rewrite * /healthz.sql
		reverse_proxy ${UPSTREAM}
	}
EOF
  if [ "$SITE_ACCESS" = "public" ]; then
    cat <<EOF
	# SITE_ACCESS=public: pages are open to everyone; the editor is not.
	@admin path /admin /admin/*
	handle @admin {
		basic_auth {
			${ADMIN_USERNAME} ${bcrypt_hash}
		}
		reverse_proxy ${UPSTREAM}
	}
	handle {
		reverse_proxy ${UPSTREAM}
	}
}
EOF
  else
    cat <<EOF
	# SITE_ACCESS=private: every page, the editor included, needs the admin login.
	handle {
		basic_auth {
			${ADMIN_USERNAME} ${bcrypt_hash}
		}
		reverse_proxy ${UPSTREAM}
	}
}
EOF
  fi
} > "$CADDYFILE"
unset bcrypt_hash
caddy validate --config "$CADDYFILE" --adapter caddyfile >/dev/null 2>&1 \
  || fail "generated Caddy configuration is invalid"

log "site access: ${SITE_ACCESS}; admin user \"${ADMIN_USERNAME}\" (password length ${#ADMIN_PASSWORD})"
log "starting SQLPage on ${SQLPAGE_LISTEN_ON} behind the public listener on :${PUBLIC_PORT}"

# SQLPage reads unprefixed variables as configuration too: PORT would override listen_on and move it
# off loopback's private port, so drop it. The /admin/ pages get only the argon2id hash, never the
# plaintext, so no SQL page can read the password back.
cd /var/www || fail "missing web root"
env -u PORT -u SQLPAGE_PORT -u ADMIN_PASSWORD \
  ADMIN_PASSWORD_HASH="$argon_hash" ADMIN_USERNAME="$ADMIN_USERNAME" \
  /usr/local/bin/sqlpage &
sqlpage_pid=$!
unset argon_hash

env -u ADMIN_PASSWORD -u DATABASE_URL caddy run --config "$CADDYFILE" --adapter caddyfile &
caddy_pid=$!

trap 'kill -TERM "$sqlpage_pid" "$caddy_pid" 2>/dev/null' TERM INT
wait -n "$sqlpage_pid" "$caddy_pid"
status=$?
log "a supervised process exited with status ${status}; shutting down"
kill -TERM "$sqlpage_pid" "$caddy_pid" 2>/dev/null
wait 2>/dev/null
exit "$status"
