# Deploy and Host SQLPage on Railway

SQLPage turns plain SQL files into web applications: forms, tables, charts, maps and APIs, with no
front-end code. This template deploys SQLPage with its own PostgreSQL database, stores your pages in
that database, and adds a password-protected in-browser editor, so you can build and change an app
without rebuilding an image or redeploying. The admin password is generated for you.
Community-maintained; not affiliated with the SQLPage project; the icon is generic.

## About Hosting SQLPage

SQLPage is a single Rust binary. Here it runs behind a small Caddy front door in one container and
talks to a bundled PostgreSQL 16 over Railway's private network. Pages are rows in the
`sqlpage_files` table, so your app and its data live in one database on one volume. A starter
guestbook shows a form writing to PostgreSQL and reading it back; the editor at `/admin/` lists,
creates, edits and deletes pages, and a saved page is live within a second. Because a SQLPage page
can run any SQL, the editor is always behind the admin login (checked twice), writes must come from
the site itself, and by default the whole site is private until you set `SITE_ACCESS=public`.

## Common Use Cases

- Internal tools and admin panels over a PostgreSQL database, written in SQL only.
- Dashboards, reports and charts that analysts can edit in the browser.
- Data-entry forms, small CRUD apps and JSON APIs without a front-end build.
- Prototyping a database-backed site before committing to a framework.

## Dependencies for SQLPage Hosting

- PostgreSQL, bundled as a private service with its own volume.
- Nothing external: no API keys, no managed database.

### Deployment Dependencies

- SQLPage: https://github.com/sqlpage/SQLPage (MIT)
- Caddy front door: https://caddyserver.com (Apache-2.0)
- PostgreSQL: https://www.postgresql.org (PostgreSQL Licence)
- Template repository, wrapper image and tests: https://github.com/youssefsiam38/sqlpage-railway

### Implementation Details

The official `lovasoa/sqlpage` image (pinned by digest) is wrapped, unmodified, with migrations that
create `sqlpage_files` and the starter app, the `/admin/` editor, and Caddy. SQLPage listens only on
loopback; Caddy serves `PORT` 8080 with HTTP basic authentication (user `admin`, generated
`ADMIN_PASSWORD`) and an unauthenticated `/healthz` that queries the database. PostgreSQL 16 is
pinned by digest, uses a volume at `/var/lib/postgresql`, and has a generated password. Tested in CI
and on a live Railway deployment: login gate, form write read back from PostgreSQL, a new page added
in the editor and served, CSRF and path guards, and data surviving a redeploy.

## Why Deploy SQLPage on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your
infrastructure so you don't have to deal with configuration, while allowing you to vertically and
horizontally scale it.

By deploying SQLPage on Railway, you are one step closer to supporting a complete full-stack
application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
