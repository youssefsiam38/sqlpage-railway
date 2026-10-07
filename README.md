# SQLPage on Railway

One-click [Railway](https://railway.com) template for [SQLPage](https://github.com/sqlpage/SQLPage):
build web apps out of `.sql` files. This template bundles PostgreSQL, stores your pages **in the
database** (the `sqlpage_files` table), and ships an in-browser page editor, so you can build and
change an app without rebuilding an image or redeploying.

> Community-maintained. Not affiliated with or endorsed by the SQLPage project. The icon is generic,
> not the SQLPage logo.

- Upstream: SQLPage 0.46.3, MIT, official image `lovasoa/sqlpage` (digest-pinned).
- Wrapper image: `ghcr.io/youssefsiam38/sqlpage-railway` (MIT), built `FROM` the official image.

## What you get

| Service | Image | Public | Volume |
|---|---|---|---|
| `sqlpage` | `ghcr.io/youssefsiam38/sqlpage-railway` (SQLPage + Caddy front door) | yes, port 8080 | none (pages live in PostgreSQL) |
| `db` | `postgres:16.15` (digest-pinned) | no | `/var/lib/postgresql` |

- A starter app at `/`: a guestbook whose form writes to PostgreSQL and reads the rows back.
- A page editor at `/admin/`: list, create, edit and delete pages stored in `sqlpage_files`. A new
  page is live about a second after you save it.
- HTTP basic authentication in front of the site. User `admin`, password generated into
  `ADMIN_PASSWORD` on the `sqlpage` service.

## Deploy

1. Click **Deploy** on the template. No input is required.
2. When it is up, open the `sqlpage` service's **Variables** tab and copy `ADMIN_PASSWORD`.
3. Open the public URL, sign in as `admin`, then go to `/admin/` to edit pages.

### Site access

| `SITE_ACCESS` | Who can see pages | Who can use `/admin/` |
|---|---|---|
| `private` (default) | only the admin login | only the admin login |
| `public` | everyone | only the admin login |

Switch to `public` when your app is ready for visitors. The starter guestbook accepts anonymous
posts in that mode, so replace or remove it first.

## Adding pages

- **Editor:** `/admin/` → **New page** → path `hello.sql`, contents
  `SELECT 'text' AS component, 'Hello' AS contents;` → Save → open `/hello.sql`.
- **SQL:** insert into the table directly, from Railway's database view or any client:
  `INSERT INTO sqlpage_files (path, contents) VALUES ('hello.sql', convert_to('…', 'UTF8'));`
- Create your own tables with a page that runs `CREATE TABLE IF NOT EXISTS …`, or from a SQL client.

Components and functions: [sql-page.com](https://sql-page.com).

## Security in one line

SQLPage pages run arbitrary SQL against your database and the editor writes pages, so the editor is
always behind the admin login (checked by Caddy **and** again inside SQLPage), writes are POST-only
with a same-origin check, and SQLPage itself listens only on loopback. See [SECURITY.md](SECURITY.md).

## Repository layout

| Path | Purpose |
|---|---|
| `Dockerfile`, `scripts/entrypoint.sh` | the wrapper image (Caddy front door + supervision) |
| `sqlpage/` | SQLPage configuration and migrations (create `sqlpage_files`, seed the starter app) |
| `www/` | files baked into the image: `/admin/` editor and the `/healthz` probe |
| `compose.yaml` | local topology mirroring Railway (db + sqlpage) |
| `tests/` | `static.sh`, `smoke.sh`, `persistence.sh`, `railway-smoke.sh` |
| `marketplace/OVERVIEW.md` | marketplace page |

## Local development

```bash
tests/static.sh        # no build: syntax, shellcheck, pins, security invariants
tests/smoke.sh         # build, start, exercise front door, starter app, editor, public mode
tests/persistence.sh   # write data and pages, recreate containers, verify
docker compose up -d --build   # then http://127.0.0.1:8080 (admin / local-test-only-sqlpage-password)
```

## Template

Published at https://railway.com/deploy/sqlpage (category Starters). Exact configuration:
[RAILWAY_TEMPLATE.md](RAILWAY_TEMPLATE.md).
