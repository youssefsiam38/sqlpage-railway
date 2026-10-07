# Security

## The risk this template handles

A SQLPage page is SQL that runs against your database with the app's database user. Whoever can
write pages can read or change all of your data. The bundled editor writes pages. So the editor, and
by default the whole site, must not be reachable by strangers on the public URL Railway assigns.

## What the template does

- **Front door.** Caddy is the only public listener and requires HTTP basic authentication
  (`ADMIN_USERNAME` / generated `ADMIN_PASSWORD`). With `SITE_ACCESS=private` (default) every path
  is gated; with `public`, only `/admin` and `/admin/*` are. Caddy matches paths case-insensitively
  and after normalisation, and the tests probe aliases (`/ADMIN/`, `//admin/`, `/%61dmin/`,
  `/x/../admin/`).
- **Second check inside SQLPage.** Every `/admin/` page starts with SQLPage's `authentication`
  component, verifying the same credentials against an argon2id hash computed at start. The
  plaintext password is removed from SQLPage's environment, so no page can read it back.
- **Loopback only.** SQLPage listens on `127.0.0.1:8081`; the entrypoint refuses any other address.
- **CSRF.** Browsers resend basic-auth credentials on cross-site requests, so `save.sql` and
  `delete.sql` accept only POST with an `Origin` header naming this host.
- **Path rules.** The editor refuses paths outside `[A-Za-z0-9_./-]`, containing `..`, or under
  `admin/` or `sqlpage/`. The editor and the healthcheck are files in the image and cannot be
  replaced from the database.
- **Health route.** `/healthz` (GET/HEAD only) runs a fixed query and returns `{"status":"ok"}`.
- **Secrets.** `ADMIN_PASSWORD` and `POSTGRES_PASSWORD` are generated per deployment. PostgreSQL is
  only on Railway's private network (no TCP proxy).

## What you should do

- Keep `ADMIN_PASSWORD` in a password manager; rotate it by editing the variable (redeploys).
- Before `SITE_ACCESS=public`, review every page: anything a page does, any visitor can trigger.
  Use `:param` placeholders (never string-built SQL), and remove the starter guestbook.
- `sqlpage.exec` is disabled (`allow_exec` false); leave it so.
- Back up the `db` volume (Railway volume backups) or `pg_dump` regularly.

## Reporting

Template issues: https://github.com/youssefsiam38/sqlpage-railway/issues. SQLPage vulnerabilities:
see the upstream [SECURITY.md](https://github.com/sqlpage/SQLPage/blob/main/SECURITY.md).
