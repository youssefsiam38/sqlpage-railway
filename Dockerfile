# syntax=docker/dockerfile:1
#
# sqlpage-railway: thin wrapper around the official SQLPage image.
#
# What it adds (SQLPage itself is unchanged):
#   - a configuration directory with migrations that create the `sqlpage_files` table and seed a small
#     starter app into it, so pages live in PostgreSQL and can be edited without rebuilding an image;
#   - a password-protected page editor under /admin/ (read-only files on disk, so the database cannot
#     overwrite it; disk files take precedence over sqlpage_files);
#   - Caddy as the only public listener, with HTTP basic authentication in front of the whole site
#     (SITE_ACCESS=private, the default) or only in front of /admin/ (SITE_ACCESS=public).
#     SQLPage listens on loopback, where nothing outside the container can reach it.
#
# Both images are pinned by tag AND digest. Update the image and version args together.
ARG CADDY_IMAGE=docker.io/library/caddy:2.11.7-alpine@sha256:d8542f48d34a9cf4e4c11a478865229840e87e4c96ea3f439101f31a5d35f75f
ARG SQLPAGE_IMAGE=docker.io/lovasoa/sqlpage:v0.46.3@sha256:354c683a50f541be01d427b3b664f1d5b36c28739f45bfb809be14b99b6ff649

FROM ${CADDY_IMAGE} AS caddy

FROM ${SQLPAGE_IMAGE}

ARG SQLPAGE_VERSION=0.46.3
ARG CADDY_VERSION=2.11.7
ARG WRAPPER_VERSION=0.0.0-dev
ARG VCS_REF=unknown
ARG BUILD_DATE=1970-01-01T00:00:00Z

# Caddy ships as a static Go binary, so the alpine-built one runs on the busybox base unchanged.
COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
COPY licenses/ /usr/share/licenses/sqlpage-railway/
# Owned by root and not writable by the sqlpage user: the editor and the migrations are part of the image.
COPY sqlpage/ /etc/sqlpage/
COPY www/ /var/www/
COPY --chmod=0755 scripts/entrypoint.sh /usr/local/bin/sqlpage-railway-entrypoint

ENV SQLPAGE_CONFIGURATION_DIRECTORY=/etc/sqlpage \
    SQLPAGE_WEB_ROOT=/var/www \
    SQLPAGE_LISTEN_ON=127.0.0.1:8081 \
    XDG_CONFIG_HOME=/tmp/caddy \
    XDG_DATA_HOME=/tmp/caddy

LABEL org.opencontainers.image.title="sqlpage-railway" \
      org.opencontainers.image.description="Community Railway wrapper for SQLPage: pages stored in PostgreSQL, an in-browser page editor, and a password front door. Not affiliated with the SQLPage project." \
      org.opencontainers.image.source="https://github.com/youssefsiam38/sqlpage-railway" \
      org.opencontainers.image.url="https://github.com/youssefsiam38/sqlpage-railway" \
      org.opencontainers.image.documentation="https://github.com/youssefsiam38/sqlpage-railway#readme" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${WRAPPER_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.base.name="docker.io/lovasoa/sqlpage:v${SQLPAGE_VERSION}" \
      io.sqlpage-railway.upstream.version="${SQLPAGE_VERSION}" \
      io.sqlpage-railway.caddy.version="${CADDY_VERSION}"

# The upstream image already runs as the unprivileged `sqlpage` user; keep it that way.
USER sqlpage
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/sqlpage-railway-entrypoint"]
