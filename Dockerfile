# syntax=docker/dockerfile:1
# ------------------------------------------------------------------------------
# Builder Stage
# ------------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM golang:1.25-trixie AS build

ARG TARGETOS
ARG TARGETARCH
ARG CGO_ENABLED=0

# The Makefile only shells out to git when these are unset, so passing them keeps
# the repository history out of the build context entirely.
ARG GIT_COMMIT=unknown
ARG BUILD_TIME

ENV CGO_ENABLED=${CGO_ENABLED} GOOS=${TARGETOS} GOARCH=${TARGETARCH} GIT_COMMIT=${GIT_COMMIT}

WORKDIR /build

COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY Makefile main.go ./
COPY static/ static/
COPY pkg/ pkg/
# make treats an empty env var as set, so an unpassed BUILD_TIME has to be removed, not left blank
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    if [ -z "$BUILD_TIME" ]; then unset BUILD_TIME; fi; make build

# ------------------------------------------------------------------------------
# Fetch signing key
# ------------------------------------------------------------------------------
FROM debian:trixie-slim AS keyring
# Pinned: this key is what authorises the apt repository the client comes from. If PostgreSQL
# ever rotates it the build fails here, which is the point — it must not change unnoticed.
ADD --checksum=sha256:0144068502a1eddd2a0280ede10ef607d1ec592ce819940991203941564e8e76 \
    https://www.postgresql.org/media/keys/ACCC4CF8.asc keyring.asc
RUN apt-get update && \
    apt-get install -qq --no-install-recommends gpg
RUN gpg -o keyring.pgp --dearmor keyring.asc

# ------------------------------------------------------------------------------
# Release Stage
# ------------------------------------------------------------------------------
FROM debian:trixie-slim

ARG GIT_COMMIT=unknown
LABEL org.opencontainers.image.title="pgweb-black" \
      org.opencontainers.image.description="pgweb with inline cell editing, an ER diagram viewer and data-browsing extras" \
      org.opencontainers.image.source="https://github.com/blackkriger/pgweb-black" \
      org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.licenses="MIT"

# postgresql-client is not optional: table exports shell out to pg_dump.
ARG keyring=/usr/share/keyrings/postgresql-archive-keyring.pgp
COPY --from=keyring /keyring.pgp $keyring
RUN . /etc/os-release && \
    echo "deb [signed-by=${keyring}] http://apt.postgresql.org/pub/repos/apt/ ${VERSION_CODENAME}-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    apt-get install -qq --no-install-recommends ca-certificates openssl curl postgresql-client && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /build/pgweb /usr/bin/pgweb

# A home directory is not optional: bookmarks, saved queries, ~/.pgpass and the default SSH
# key all resolve under $HOME, so without one those features are silently unavailable.
RUN useradd --uid 1000 --create-home --shell /bin/false pgweb && \
    mkdir -p /home/pgweb/.pgweb/bookmarks /home/pgweb/.pgweb/queries && \
    chown -R pgweb:pgweb /home/pgweb
USER pgweb
ENV HOME=/home/pgweb

EXPOSE 8081

# /api/info answers without a database connection, so this reports the server itself
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD curl -fsS http://127.0.0.1:8081/api/info || exit 1

ENTRYPOINT ["/usr/bin/pgweb", "--bind=0.0.0.0", "--listen=8081"]
