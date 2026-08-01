---
name: sqlgo
description: Use sqlgo CLI when running SQL, querying SQLite/Postgres/MySQL/SQL Server/Oracle/Firebird/Turso/D1, querying CSV/TSV/JSONL files, exporting results, managing saved connections, SSH tunneling, or scripting database operations headlessly.
---

# sqlgo

Headless SQL CLI. Use terminal mode, not TUI, by passing verb first.

## First Check

Use built-in help for advanced or uncertain options:

```sh
sqlgo help
sqlgo help exec
sqlgo help export
sqlgo help open
sqlgo help conns
```

## Verbs

- `exec`: run SQL, print results.
- `export`: run SQL, write file/stdout.
- `open`: load CSV/TSV/JSONL into temp SQLite.
- `conns`: manage saved connections.
- `history`: list/search/clear history.
- `version`: print version.
- `completion`: shell completions.

## DSN

Use `--dsn` inline:

```sh
sqlgo exec --dsn "sqlite:///C:/path/db.sqlite3" -q "SELECT COUNT(*) FROM table"
sqlgo exec --dsn "postgres://user:pass@host:5432/db" -q "SELECT version()"
```

Schemes include:

```text
sqlite:// postgres:// mysql:// mssql:// sqlserver:// oracle:// firebird:// libsql:// d1://
```

Aliases include:

```text
cockroachdb supabase neon yugabytedb timescaledb mariadb
```

## Query

Inline SQL:

```sh
sqlgo exec --dsn "sqlite:///db.sqlite3" -q "SELECT * FROM files LIMIT 10" --format table
```

SQL file:

```sh
sqlgo exec --dsn "sqlite:///db.sqlite3" -f query.sql --format jsonl
```

Timeout:

```sh
sqlgo exec --dsn "sqlite:///db.sqlite3" -q "SELECT ..." --timeout 30s
```

## Export

```sh
sqlgo export --dsn "sqlite:///db.sqlite3" -q "SELECT * FROM files" -o files.csv
sqlgo export --dsn "sqlite:///db.sqlite3" -q "SELECT * FROM files" --format jsonl -o files.jsonl
```

Formats:

```text
csv tsv json jsonl markdown table
```

Row cap:

```sh
sqlgo export --dsn "sqlite:///db.sqlite3" -q "SELECT * FROM big_table" --max-rows 1000 -o sample.csv
```

`--max-rows` exits 5 after partial output.

## Flat Files

Load local files into temp SQLite:

```sh
sqlgo open data.csv -q "SELECT * FROM data WHERE amount > 100"
sqlgo open users.csv orders.jsonl -q "SELECT u.name, o.total FROM users u JOIN orders o ON u.id = o.user_id"
```

No persistence. Table name comes from filename.

## Connections

Use saved connection:

```sh
sqlgo exec -c myconn -q "SELECT version()"
```

Manage:

```sh
sqlgo conns list
sqlgo conns show myconn
sqlgo conns test myconn
sqlgo conns rm myconn --force
```

Add connection with password from stdin:

```sh
echo -n "$PASSWORD" | sqlgo conns add myconn --driver postgres --host db.local --port 5432 --user me --database app --password-stdin
```

Passwords use OS keyring by default. `--keyring=false` stores plaintext.

## Safety

Destructive SQL blocked unless `--allow-unsafe`:

```sh
sqlgo exec --dsn "sqlite:///db.sqlite3" -q "DROP TABLE x" --allow-unsafe
```

Do not use `--allow-unsafe` unless user explicitly intends mutation.

## SSH

`conns add`/`set` support:

```text
--ssh-host --ssh-port --ssh-user --ssh-key --ssh-password-stdin
```

Key file preferred. `ssh-agent` not supported. Host keys checked via `~/.ssh/known_hosts`.

## Output Rules

- Prefer `exec` for quick inspection.
- Prefer `export` for files or large results.
- Use `--format jsonl` for pipelines.
- Use `--timeout` for risky/remote queries.
- Use help commands for advanced flags before guessing.
