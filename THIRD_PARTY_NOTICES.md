# Third-party notices

This template deploys software written by other people. Their licences apply to what runs; the
wrapper code in this repository is MIT.

| Component | Version | Licence | Source | How it is used |
|---|---|---|---|---|
| SQLPage | 0.46.3 | MIT | https://github.com/sqlpage/SQLPage | base image of the wrapper, unmodified |
| Caddy | 2.11.7 | Apache-2.0 | https://github.com/caddyserver/caddy | static binary copied into the wrapper, unmodified |
| PostgreSQL | 16.15 | PostgreSQL Licence | https://www.postgresql.org | official `postgres` image, separate service, unmodified |

The SQLPage and Caddy licence texts are in [`licenses/`](licenses) and inside the image at
`/usr/share/licenses/sqlpage-railway/`. The admin editor pages are original to this repository,
modelled on the MIT-licensed "SQLPage developer user interface" upstream example.

All licences are permissive and require preserving copyright notices, which the image does.

## Trademarks

"SQLPage" is used only to name the software this template deploys. The marketplace icon is generic
and original to this repository. This template is not affiliated with, endorsed by, or supported by
the SQLPage project.
