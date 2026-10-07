# Marketplace audit

| | |
|---|---|
| App | SQLPage 0.46.3 — SQL-only web app builder (single Rust binary) |
| Upstream | https://github.com/sqlpage/SQLPage, MIT, actively maintained, official multi-arch image |
| Marketplace gap | no SQLPage template found (gapscan 2026-10-07) |
| Brand | name used descriptively; generic icon; not affiliated |
| Verdict | **shippable** |

## Security review

- No built-in users or first-run page in SQLPage. The risk is the page editor (arbitrary SQL) and
  the starter form on a public URL → Caddy front door with a generated password, editor re-checked
  inside SQLPage, CSRF origin check, loopback-only SQLPage, private-only PostgreSQL.
- `sqlpage.exec` stays disabled; `environment=production` hides SQL errors from visitors.

## Tests

| Script | Assertions | Covers |
|---|---|---|
| `tests/static.sh` | 48 | syntax, shellcheck, pins, compose shape, security invariants, workflows, secret scan |
| `tests/smoke.sh` | 52 | health, front door, starter form write/read, editor create/update/nested/delete, CSRF, path guards, password not readable from pages, in-app auth, public mode + 10 path aliases |
| `tests/persistence.sh` | 12 | pages, edited home page and rows survive recreating both containers; migrations do not re-seed |
| `tests/railway-smoke.sh` | 22 | the same flows over HTTPS against a deployment, plus redeploy persistence via STATE_OUT/STATE_IN |

## Deploy-time inputs

None required. `ADMIN_PASSWORD` and `POSTGRES_PASSWORD` are generated.
