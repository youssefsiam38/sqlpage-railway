# Architecture

```
            Internet (HTTPS, Railway edge)
                        │
                        ▼  :8080  (PORT, domain target, healthcheck /healthz)
   ┌───────────────────────────────── sqlpage service ─────────────────────────┐
   │ Caddy  ── basic auth (whole site, or /admin* only when SITE_ACCESS=public) │
   │   │         /healthz (GET/HEAD) → rewritten to /healthz.sql, unauthenticated│
   │   ▼ loopback 127.0.0.1:8081                                                │
   │ SQLPage 0.46.3 (unmodified binary, runs as uid 1000)                       │
   │   web root /var/www  : admin/*.sql, healthz.sql   (image, read-only)        │
   │   config  /etc/sqlpage: sqlpage.json, migrations/ (image, read-only)        │
   └───────────────────────┬────────────────────────────────────────────────────┘
                           │ Railway private network (IPv6), DATABASE_URL
                           ▼
   ┌──────────── db service ───────────┐
   │ PostgreSQL 16.15                   │  volume /var/lib/postgresql,
   │  sqlpage_files  (your pages)       │  PGDATA=/var/lib/postgresql/pgdata
   │  guestbook      (starter data)     │
   │  _sqlx_migrations                  │
   └────────────────────────────────────┘
```

## How pages are found

SQLPage resolves a URL to a path, looks for that file on disk under the web root, and if it is not
there reads it from `sqlpage_files` in the database. Disk wins, which is why the image keeps only
`admin/` and `healthz.sql` on disk: those cannot be overwritten from the database, and everything
else (including `/`, i.e. `index.sql`) is a database row you can edit.

SQLPage caches compiled pages (production mode) and re-checks a cached page at most once a second
by comparing `last_modified`. A trigger bumps `last_modified` on every update. A *deleted* row is
not noticed by that check, so the editor replaces a deleted `.sql` page with a tombstone that
returns 404 instead of removing the row (it is hidden from the list and overwritten if you save the
same path again). Non-`.sql` files are not cached and are deleted outright.

## Start-up

1. SQLPage connects to PostgreSQL (retrying while `db` starts) and applies the migrations in
   `/etc/sqlpage/migrations` once each (tracked in `_sqlx_migrations`): create `sqlpage_files` and
   its trigger, create `guestbook`, insert the starter `index.sql` (`ON CONFLICT DO NOTHING`).
2. The entrypoint validates variables, hashes `ADMIN_PASSWORD` twice (bcrypt for Caddy, argon2id
   for the in-SQLPage check), writes and validates a Caddyfile, starts SQLPage on loopback and Caddy
   on `PORT`, and supervises both: if either exits, the container exits and Railway restarts it.

## Why a wrapper

The stock image would need the migrations, the editor and a front door supplied at runtime. Baking
them into a thin wrapper keeps the template one click, keeps the editor immutable, and puts Caddy in
the same container so SQLPage can stay on loopback (no private-network exposure, no IPv6 binding
needed). SQLPage's own binary and behaviour are unchanged.

## Variables (sqlpage service)

| Variable | Default | Meaning |
|---|---|---|
| `ADMIN_USERNAME` | `admin` | basic-auth user |
| `ADMIN_PASSWORD` | generated (32 alnum) | basic-auth password, ≥ 12 chars |
| `SITE_ACCESS` | `private` | `private` or `public` (see README) |
| `DATABASE_URL` | built from `db` | `postgres://user:pass@db.railway.internal:5432/db` |
| `SQLPAGE_ENVIRONMENT` | `production` | `development` shows SQL errors in the browser |
| `PORT` | `8080` | public listener; keep equal to the domain's target port |
