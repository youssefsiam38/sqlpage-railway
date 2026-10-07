# Upstream

| | |
|---|---|
| Project | SQLPage — https://github.com/sqlpage/SQLPage (formerly lovasoa/SQLPage) |
| Licence | MIT |
| Official image | `lovasoa/sqlpage` (Docker Hub, multi-arch amd64/arm64/arm) |
| Pinned | `lovasoa/sqlpage:v0.46.3@sha256:354c683a50f541be01d427b3b664f1d5b36c28739f45bfb809be14b99b6ff649` |
| Caddy | `caddy:2.11.7-alpine@sha256:d8542f48d34a9cf4e4c11a478865229840e87e4c96ea3f439101f31a5d35f75f` |
| PostgreSQL | `postgres:16.15@sha256:65b16a8b326e0cfbdf33fa7e783f2a0cb352a61448616ccccfd616ef42aa0f65` |
| Wrapper | `ghcr.io/youssefsiam38/sqlpage-railway:1.0.0` (digest recorded in `RAILWAY_TEMPLATE.md`) |

## Refreshing a digest

```bash
curl -s https://hub.docker.com/v2/repositories/lovasoa/sqlpage/tags/v0.46.3/ | jq -r .digest
docker buildx imagetools inspect ghcr.io/youssefsiam38/sqlpage-railway:1.0.0 --format '{{json .Manifest}}' | jq -r .digest
```
