# Railway template configuration

The template's exact configuration. Reproduce it from this file if it ever has to be rebuilt.

| | |
|---|---|
| Name | SQLPage |
| Code | `sqlpage` |
| Template id | `af7ee0b8-1460-4d03-b5c8-566f4f5e3aba` |
| Deploy URL | https://railway.com/deploy/sqlpage |
| Category | Starters |
| Card description | Build web apps in SQL: bundled Postgres, pages in the DB, browser editor |
| Icon | `assets/icon.png` |
| Overview markdown | `marketplace/OVERVIEW.md` (Railway enforces its section headings) |

Generated values use Railway's `secret()` function: `hexN` is `${{secret(N, "abcdef0123456789")}}` and `alnumN` is
`${{secret(N, "a-zA-Z0-9")}}` spelled out. Alphanumeric passwords are used wherever a value is embedded in a
connection URL, so nothing needs percent-encoding. Images are pinned by tag and digest (the Source rows below).

## Services

### `db`

| Field | Value |
|---|---|
| Source | `postgres:16.15@sha256:65b16a8b326e0cfbdf33fa7e783f2a0cb352a61448616ccccfd616ef42aa0f65` |
| Public domain | none |
| Volume | `/var/lib/postgresql` |
| Restart policy | on failure, 10 retries |

| Variable | Value |
|---|---|
| `POSTGRES_USER` | `sqlpage` |
| `POSTGRES_DB` | `sqlpage` |
| `POSTGRES_PASSWORD` | generated, alnum40 |
| `PGDATA` | `/var/lib/postgresql/pgdata` |

### `sqlpage`

| Field | Value |
|---|---|
| Source | `ghcr.io/youssefsiam38/sqlpage-railway:1.0.0@sha256:a8c7bf3744495188430ce7953f7f4e32566cc28ea85c9a1ad944ba6e60c8c7a5` |
| Public domain | target port 8080 |
| Volume | none |
| Healthcheck | `/healthz`, timeout from `RAILWAY_HEALTHCHECK_TIMEOUT_SEC` |
| Restart policy | on failure, 10 retries |

| Variable | Value |
|---|---|
| `PORT` | `8080` |
| `ADMIN_USERNAME` | `admin` |
| `ADMIN_PASSWORD` | generated, alnum32 |
| `SITE_ACCESS` | `private` |
| `DATABASE_URL` | `postgres://${{db.POSTGRES_USER}}:${{db.POSTGRES_PASSWORD}}@${{db.RAILWAY_PRIVATE_DOMAIN}}:5432/${{db.POSTGRES_DB}}` |
| `SQLPAGE_ENVIRONMENT` | `production` |
| `RAILWAY_HEALTHCHECK_TIMEOUT_SEC` | `300` |
| `SQLPAGE_MAX_UPLOADED_FILE_SIZE` | optional, unset |
| `SQLPAGE_SITE_PREFIX` | optional, unset |
| `SMTP_HOST` | optional, unset |

## Notes

- Pages live in PostgreSQL (`sqlpage_files`); the `sqlpage` service has no volume. Back up the `db` volume.
- `/admin/` editor and `/healthz` are files baked into the wrapper image; disk files take precedence over the database, so they cannot be overwritten from the editor.
- `SITE_ACCESS=private` (default) gates the whole site with basic auth; `public` gates only `/admin*`. The editor re-checks the login inside SQLPage against an argon2id hash; the plaintext password is not in SQLPage's environment.
- Deleting a `.sql` page writes a 404 tombstone (SQLPage's cache does not notice deleted rows).
- Live e2e (clean room of the template, then again of the published code): front door, starter form write read back from PostgreSQL, new page saved in the editor and served, CSRF and path guards, and data/pages surviving a redeploy of both `db` and `sqlpage`.
