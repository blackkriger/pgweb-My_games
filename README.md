# pgweb-black

A fork of [sosedoff/pgweb](https://github.com/sosedoff/pgweb) — a simple, cross-platform, web-based PostgreSQL database explorer — with **inline cell editing** and a set of data-browsing conveniences added on top. 

<sub>Originally forked for use within the [My_games](https://my-games.uk) project.</sub>

## What this fork adds

- **Inline cell editing in the table rows view.** Double-click a cell to edit its value in place — `Enter` saves, `Shift+Enter` inserts a newline, `Esc` cancels. Saving runs a primary-key–scoped, parameterized `UPDATE`, so only the exact row is touched and values are cast to their own column types.
- Editing is available only while **browsing a table's rows** (not on arbitrary query results) and only for tables that have a **primary key**.
- **Visual schema diagram (ER viewer).** Browse the schema as draggable table cards linked by their foreign keys, with pan, zoom and PK/FK markers. Cards show row counts and table size, columns are marked as index / unique / not-null / default / identity / generated, and the whole diagram exports to PNG or SVG in the current theme.
- **Multi-row selection & bulk actions.** A select-all checkbox plus per-row checkboxes let you pick rows, then **delete the selection** or **export it** as CSV / JSON / XML from the toolbar's export-selected submenu.
- **JSON(B) tree viewer/editor.** Expand, browse, and edit `json` / `jsonb` cell values as a collapsible tree.
- **Foreign-key navigation.** A "Go to *table.column*" item in the row context menu jumps straight to the referenced row.
- **Copy Row as INSERT.** Right-click a row to copy a ready-to-run `INSERT` statement.
- **Client-side row filtering.** A "Filter rows" box filters the current page locally.
- **Column filters with operators.** Filter a column by `=`, `!=`, `>`, `<`, `LIKE` and friends from the header menu; the condition survives paging and sorting.
- **Precise query timing.** The Query page shows the real sub-millisecond server-side execution time. 
- **Dark theme.** The sun/moon button switches the UI to a dark, purple-tinted look. 

## Installation

Grab a binary from the [Releases](https://github.com/blackkriger/pgweb-black/releases) page, or run it in Docker:

```
docker build -t pgweb-black .
docker run --rm -p 8081:8081 pgweb-black --url postgres://user:password@host:5432/database
```

The image runs as an unprivileged user, ships `pg_dump` so table exports work, and answers a healthcheck on `/api/info`. The entrypoint already binds `0.0.0.0:8081`, so anything you pass is appended as extra flags. Reaching a database on the host machine needs `--network host` (Linux) or `host.docker.internal` as the host name.

Bookmarks, saved queries, `~/.pgpass` and the default SSH key are read from the `pgweb` user's home, so mount them to use those features:

```
docker run --rm -p 8081:8081 -v "$(pwd)/bookmarks:/home/pgweb/.pgweb/bookmarks:ro" pgweb-black
```

Nothing is ever written to disk at runtime — dumps stream straight to the response — so the container also runs with a read-only root filesystem:

```
docker run --rm -p 8081:8081 --read-only pgweb-black --url postgres://...
```

Stamp the build with its commit, and cross-build for another architecture. A multi-platform build cannot be loaded into the local image store, so it goes straight to a registry; drop to one platform with `--load` to keep it local:

```
docker buildx build --platform linux/amd64,linux/arm64 \
  --build-arg GIT_COMMIT=$(git rev-parse --short=8 HEAD) \
  -t ghcr.io/blackkriger/pgweb-black:latest --push .
```

## Usage

```
pgweb --url postgres://user:password@host:port/database?sslmode=[mode]
```

Or with individual flags:

```
pgweb --host localhost --user myuser --db mydb
```

A local socket works too:

```
pgweb --url "postgres:///database?host=/absolute/path/to/unix/socket/dir"
```

Inline editing issues `UPDATE` statements, so it needs a writable connection — running with `--readonly` (or a read-only bookmark) disables it.

### Multiple database sessions

To let several people connect to their own databases from one instance, start it with:

```
pgweb --sessions
```

Or set the environment variable:

```
PGWEB_SESSIONS=1 pgweb
```

## Building

Static assets are embedded via `go:embed`, so a plain Go build bundles the frontend too — no Node.js toolchain required. Requires Go 1.25+.

```
make build                                                  # current platform
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o pgweb .    # Linux server binary
```

Prebuilt binaries are published on the [Releases](https://github.com/blackkriger/pgweb-black/releases) page.

## License

The MIT License (MIT). See [LICENSE](https://github.com/blackkriger/pgweb-black/blob/main/LICENSE) for details. Original work done by Dan Sosedoff and the pgweb contributors.
