---
name: sqlgo
description: 'Use sqlgo CLI to run SQL queries, export results, and manage database connections from the terminal. Use when: executing SQL against databases (Postgres, MySQL, SQL Server, SQLite, Oracle, Firebird, flat files like CSV/TSV/JSONL), exporting query results to files, managing saved connections, SSH tunneling to remote databases, scripting database operations headlessly.'
---

# sqlgo CLI

Headless SQL client. Query, export, manage connections from terminal. No TUI when verb is first arg.

## Databases

Postgres, MySQL, SQL Server, SQLite, Oracle, Firebird, Turso/libSQL, Cloudflare D1, flat files (CSV/TSV/JSONL -> in-memory SQLite).

DSN schemes: `postgres://`, `mysql://`, `mssql://` / `sqlserver://`, `sqlite://`, `oracle://`, `firebird://`, `libsql://`, `d1://`.
Aliases work as schemes/drivers: `cockroachdb`, `supabase`, `neon`, `yugabytedb`, `timescaledb`, `mariadb`.

## Verbs

| Verb | Purpose |
|------|---------|
| `exec` | Run SQL, print. Table on tty, TSV piped. |
| `export` | Run SQL, write to file/stdout. Default CSV. |
| `open` | Load CSV/TSV/JSONL files into ephemeral in-memory SQLite. Headless with `-q`/`-f`/stdin, else launches TUI. |
| `edit` | Launch TUI with a `.sql`/`.txt` file preloaded in editor. |
| `conns` | Saved connections (add/set/rm/test/list/show/import/export). |
| `history` | History (list/search/clear). |
| `version` | Print sqlgo version. |
| `help` | Show top-level help or per-verb help (`sqlgo help <verb>`). |
| `completion` | Print shell-completion script: `bash`, `zsh`, `fish`, `powershell`, `pwsh`. |

## exec & export Flags

| Flag | Effect |
|------|--------|
| `-c NAME` / `--conn` | Saved connection. |
| `--dsn URL` | Inline DSN: `scheme://user:pass@host:port/db?opt=val` |
| `-q SQL` / `--query` | Inline SQL. |
| `-f PATH` / `--file` | SQL from file. `-` = stdin. |
| `--format FMT` | `csv`, `tsv`, `json`, `jsonl`, `markdown`, `table` |
| `-o PATH` / `--output` | Output file. Format from extension unless `--format` set. |
| `--max-rows N` | Stop after N rows. Exit 5. |
| `--timeout DUR` | Abort after duration. |
| `--allow-unsafe` | Permit destructive DML/DDL (UPDATE/DELETE no WHERE, TRUNCATE, DROP). Without = exit 4. |
| `--continue-on-error` | Keep running on failure. |
| `--record-history` | Save to history. Off by default. |
| `--password-stdin` | Read password from stdin. |

Password precedence: `--password-stdin` > `$SQLGO_PASSWORD` > DSN/keyring.

## open Flags

`sqlgo open FILE [FILE...]` - each file becomes a table named after the filename.

| Flag | Effect |
|------|--------|
| `-q SQL` / `--query` | Inline SQL (switches to headless). |
| `-f PATH` / `--file` | SQL from file. `-` = stdin (switches to headless). |
| `--format FMT` | Headless output format: `csv`, `tsv`, `json`, `jsonl`, `markdown`, `table` |
| `-o PATH` / `--output` | Headless output path (default stdout). |
| `--max-rows N` | Stop after N rows (headless). |
| `--timeout DUR` | Abort each statement after duration (headless). |
| `--allow-unsafe` | Permit destructive statements (headless). |
| `--continue-on-error` | Keep running after a failure (headless). |

Without `-q`/`-f`/stdin the TUI launches pre-connected to the files. Nothing is persisted; no saved connection is created.

## edit

`sqlgo edit FILE.sql` - launches TUI with FILE preloaded in the query editor. Allowed extensions: `.sql`, `.txt`.

## conns Subcommands

| Subcommand | Flags |
|------------|-------|
| `list`/`ls` | `--format FMT` |
| `show NAME` | - |
| `add NAME` | `--driver NAME` (required), `--host`, `--port`, `--user`, `--database`, `--option k=v` (repeatable), `--password-stdin`, `--keyring=true\|false` (default true), `--force`, `--ssh-host`, `--ssh-port`, `--ssh-user`, `--ssh-key PATH`, `--ssh-password-stdin` |
| `set NAME` | Same as add. Upserts - only supplied fields change. |
| `rm NAME` | `--force` (no error if missing). |
| `test NAME` | `--timeout DUR` (default 10s), `--password-stdin`. |
| `import` | `-i FILE` / `--input FILE` (default stdin). |
| `export` | `-o FILE` / `--output FILE` (default stdout). |

Passwords -> OS keyring by default. `--keyring=false` = plaintext.
`conns export` writes keyring passwords as placeholders - not secret backup.

## history Subcommands

| Subcommand | Flags |
|------------|-------|
| `list`/`ls` | `-c NAME`, `--limit N` (default 50), `--format FMT` |
| `search QUERY` | `-c NAME`, `--limit N` (default 50), `--format FMT` |
| `clear` | `-c NAME` (scope one conn), `--force` (required) |

No history recorded unless `--record-history` passed.

## SSH Tunneling

SSH flags on `conns add`/`conns set`: `--ssh-host`, `--ssh-port`, `--ssh-user`, `--ssh-key PATH`, `--ssh-password-stdin`.

- Key-file preferred. Password = fallback.
- `ssh-agent` NOT supported - need key file or password.
- Host keys checked against `~/.ssh/known_hosts`.
- `$SQLGO_SSH_PASSWORD` = env equivalent of `--ssh-password-stdin`.
- Both `--password-stdin` + `--ssh-password-stdin` set -> stdin reads two newline-delimited values.

## Examples

```sh
# Query with saved connection
sqlgo exec -c myconn -q "SELECT version()"

# SQL file -> CSV file
sqlgo export -c myconn -f report.sql -o report.csv

# Inline DSN, JSONL for piping
sqlgo export --dsn "postgres://user@host:5432/db" -q "SELECT * FROM users" --format jsonl

# Add a connection (password from stdin -> OS keyring)
echo -n "$PASSWORD" | sqlgo conns add myconn --driver postgres --host db.local --port 5432 --user me --database app --password-stdin

# Test connection
sqlgo conns test myconn

# Backup/restore connections
sqlgo conns export -o conns.json
sqlgo conns import -i conns.json

# Query a flat file (CSV/TSV/JSONL loaded into SQLite)
sqlgo open data.csv -q "SELECT * FROM data WHERE amount > 100"

# Join multiple flat files
sqlgo open users.csv orders.jsonl -q "SELECT u.name, o.total FROM users u JOIN orders o ON u.id = o.user_id"

# Open flat files in TUI for interactive exploration
sqlgo open data.csv

# Multiple statements from file, keep going on error
sqlgo exec -c myconn -f migrations.sql --continue-on-error --allow-unsafe

# Export with row cap
sqlgo export -c myconn -q "SELECT * FROM big_table" -o sample.tsv --max-rows 1000
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Usage/arg error |
| 2 | Connection/store error |
| 3 | Query error |
| 4 | Refused - unsafe mutation, no `--allow-unsafe` |
| 5 | `--max-rows` hit (partial output flushed) |

## Env Vars

| Variable | Default | Effect |
|----------|---------|--------|
| `SQLGO_PASSWORD` | - | Conn password (below `--password-stdin`) |
| `SQLGO_SSH_PASSWORD` | - | SSH password (below `--ssh-password-stdin`) |
| `SQLGO_BYTE_CAP` | 2 GiB | Max bytes per result set; file-driver spill threshold |
| `SQLGO_DEBUG` | - | `1` = stack traces on panic |

## Key Behaviors

- No implicit transactions. `BEGIN`/`COMMIT`/`ROLLBACK` = yours.
- Destructive DML/DDL blocked without `--allow-unsafe`.
- `exec` output: table on tty, TSV piped. Override with `--format`.
- `export` default CSV. `-o` extension overrides format.
- Store: `%LocalAppData%\sqlgo` (Win), `~/.local/share/sqlgo` (Linux), `~/Library/Application Support/sqlgo` (mac). `sqlgo.db` (SQLite WAL) holds connections + history.

## completion

Generate shell completions: `sqlgo completion bash|zsh|fish|powershell|pwsh`.

```sh
# PowerShell - add to $PROFILE
sqlgo completion pwsh | Out-String | Invoke-Expression

# Bash
sqlgo completion bash > ~/.local/share/bash-completion/completions/sqlgo

# Zsh
sqlgo completion zsh > "${fpath[1]}/_sqlgo"

# Fish
sqlgo completion fish > ~/.config/fish/completions/sqlgo.fish
```
