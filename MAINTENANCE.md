# Maintenance

## Bump SQLPage (or Caddy)

1. Resolve the new multi-arch digest (see UPSTREAM.md) and update the `ARG` in `Dockerfile`, the
   version args, `UPSTREAM.md`, `THIRD_PARTY_NOTICES.md`, and the version string asserted in
   `tests/railway-smoke.sh`.
2. Read the upstream CHANGELOG for changes to `sqlpage_files`, the file cache, `authentication`,
   `sqlpage.header`, or configuration variables.
3. `tests/static.sh && tests/smoke.sh && tests/persistence.sh`.
4. Commit, then `git tag -a vX.Y.Z -m vX.Y.Z && git push origin vX.Y.Z` → `publish-image` re-runs
   the tests against the candidate and pushes to GHCR.
5. Point the template's `sqlpage` service at the new `tag@digest` (`_audit/spec_sqlpage.py`,
   `tplkit.patch_template`), deploy a clean room, run `tests/railway-smoke.sh`, update the template.

## Migrations

`sqlpage/migrations/*.sql` are applied once and checksummed by sqlx. **Never edit a shipped
migration** — existing deployments would refuse to start (checksum mismatch). Add a new numbered
file instead, and make it idempotent (`IF NOT EXISTS`, `ON CONFLICT DO NOTHING`) and harmless to
user-edited data (never overwrite rows in `sqlpage_files`).

## Rebuilding the Railway template from scratch

`_audit/spec_sqlpage.py` in the workspace → `tplkit.skeleton` → `railway templates create` →
`tplkit.patch_template` → verify → clean-room deploy → `railway-smoke.sh` → publish.

## Gotchas specific to this template

- SQLPage reads unprefixed variables as configuration too: Railway's `PORT` would override
  `listen_on`, so the entrypoint drops `PORT` from SQLPage's environment.
- Disk files shadow database files: anything added under `www/` becomes un-editable from `/admin/`.
- Deleted rows stay cached by SQLPage until restart; the editor writes a 404 tombstone instead.
- `sqlpage.link(...)` with column arguments cannot be used in `INSERT … RETURNING` (SQLPage must
  evaluate it before the query); build redirect URLs with `||`.
- `caddy hash-password` reads the plaintext from stdin only when it ends with a newline.
- postgres:16 declares `VOLUME /var/lib/postgresql/data`; keep `PGDATA=/var/lib/postgresql/pgdata`
  with the volume at the parent, or local `down`/`up` silently loses data and Railway's `lost+found`
  breaks `initdb`.
