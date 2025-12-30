# ecto_libsql Development Guide

Reference guide for building ecto_libsql targeting the libsql Rust crate API.

## Project Scope

### ✅ Target: libsql Production Features
- Basic SQLite compatibility
- Embedded replicas (local sync) - **killer feature**
- Remote connections via HTTP/WebSocket (sqld protocol)
- Vector search
- Encryption at rest
- Extended ALTER TABLE support
- Turso Platform API integration

### ❌ Do NOT Target: Experimental Turso Rewrite Features
- `BEGIN CONCURRENT` / MVCC
- Native CDC tables
- DBSP incremental views
- Native async query subscriptions

These features only exist in the Rust rewrite (github.com/tursodatabase/turso) and are not production-ready.

## Architecture Decision: Rust NIF is Correct

```
Elixir → Rustler NIF → libsql Rust crate → (libsql C library internally)
```

**Why Rust NIF over C NIF:**
- Embedded replica functionality lives in Rust crate, not C library
- C library alone = just SQLite fork without replication
- Rust crate = replication + sync + HTTP client + async interface
- Rustler provides memory safety and good Elixir integration

## libsql Rust Crate API Reference

**Documentation:** https://docs.rs/libsql/latest/libsql/

### Core Types

#### `Builder` - Connection Factory
```rust
// Local SQLite file only
Builder::new_local(path)

// Remote connection only (requires network)
Builder::new_remote(url, token)

// Embedded replica (local + remote sync) - THE KILLER FEATURE
Builder::new_remote_replica(path, url, token)
```

#### `Database` - Connection Pool Handle
```rust
let db = builder.build().await?;
let conn = db.connect()?;
```
- Manages underlying connection state
- Connection pool semantics
- Call `.connect()` to get `Connection` instances

#### `Connection` - Query Interface
```rust
// Execute writes
conn.execute(sql, params).await?;

// Query reads
let rows = conn.query(sql, params).await?;

// Transactions
let tx = conn.transaction().await?;

// Batch operations
conn.batch(statements).await?;
```

### Key Methods for Embedded Replicas

```rust
// Manual sync from remote to local
db.sync().await?;

// Can be called periodically or on-demand
// Consider: background process vs explicit Repo.sync()
```

## Cargo.toml Feature Flags

Enable these features in your Rust NIF:

```toml
[dependencies]
libsql = { version = "0.x", features = ["core", "replication", "remote"] }
```

- `core` - Basic local database support
- `replication` - Embedded replica functionality
- `remote` - HTTP/WebSocket client for remote connections

## Async Considerations

**Critical:** libsql Rust crate is fully async (async/await).

Your NIF will need to:
1. Bridge async Rust → synchronous Elixir
2. Consider using Tokio runtime in your NIF
3. Block on async operations or use scheduler threads

Example pattern:
```rust
#[rustler::nif]
fn execute(query: String) -> Result<(), Error> {
    // Need a runtime to block on async
    tokio::runtime::Runtime::new()?
        .block_on(async {
            connection.execute(&query, ()).await
        })
}
```

Or use `rustler::task` for non-blocking:
```rust
#[rustler::nif(schedule = "DirtyCpu")]
fn execute_async(query: String) -> Result<(), Error> {
    // Runs on dirty scheduler
}
```

## Ecto Adapter Mapping

### Query Protocol
```
Ecto Query → Ecto.Adapters.SQL → Your Adapter → libsql Connection
```

Map these operations:
- `Ecto.Repo.all()` → `conn.query()`
- `Ecto.Repo.insert()` → `conn.execute()`
- `Ecto.Repo.transaction()` → `conn.transaction()`

### Connection Configuration

```elixir
# Local only
config :my_app, MyApp.Repo,
  database: "/path/to/local.db"

# Remote only  
config :my_app, MyApp.Repo,
  url: "libsql://my-db.turso.io",
  auth_token: System.get_env("TURSO_TOKEN")

# Embedded replica (recommended)
config :my_app, MyApp.Repo,
  url: "libsql://my-db.turso.io",
  auth_token: System.get_env("TURSO_TOKEN"),
  local_db: "/path/to/local.db",
  sync_interval: 60_000  # Optional: auto-sync every 60s
```

### Sync Strategy Options

**Option 1: Background Process**
```elixir
# Auto-sync in background GenServer
def handle_info(:sync, state) do
  Repo.sync()
  Process.send_after(self(), :sync, @sync_interval)
  {:noreply, state}
end
```

**Option 2: Explicit API**
```elixir
# Manual sync when needed
MyApp.Repo.sync()
```

**Option 3: Hybrid**
```elixir
# Auto-sync + manual trigger
config :my_app, MyApp.Repo,
  auto_sync: true,
  sync_interval: 60_000

# Can still call manually
MyApp.Repo.sync()
```

## Connection Pooling

Consider:
- Ecto manages its own connection pool (DBConnection)
- libsql `Database` has internal connection management
- May need to tune pool size based on libsql behavior
- Embedded replicas: each connection has its own local file or shares?

## Testing Strategy

### Local Development
```elixir
# Use local SQLite file for fast tests
config :my_app, MyApp.Repo,
  database: ":memory:"  # or temp file
```

### Integration Testing
```elixir
# Test against real sqld instance
# Use Docker: ghcr.io/tursodatabase/libsql-server:latest
config :my_app, MyApp.Repo,
  url: "http://localhost:8080"
```

### Embedded Replica Testing
```elixir
# Test sync functionality
test "embedded replica syncs changes" do
  {:ok, _} = Repo.insert(%User{name: "Alice"})
  :ok = Repo.sync()
  # Verify local file has changes
end
```

## What to Ignore (For Now)

From the libsql documentation, defer these until basics work:

- **Encryption** - Complex, tackle later if needed
- **Advanced configuration** - Stick to defaults first
- **Experimental features** - Marked as such in docs
- **WebAssembly support** - Not relevant for Elixir NIF
- **Virtual WAL interfaces** - Low-level, likely not needed

## Common Pitfalls to Avoid

1. **Don't chase the Rust rewrite** - Features in github.com/tursodatabase/turso aren't in libsql yet
2. **Async handling** - Ensure proper Tokio runtime setup in NIF
3. **Connection lifecycle** - Understand when to create/drop Database vs Connection
4. **Error mapping** - Map Rust errors → Elixir errors carefully
5. **Type conversions** - SQLite types ↔ Elixir types need careful handling

## Documentation to Keep Handy

- **libsql Rust docs**: https://docs.rs/libsql/latest/libsql/
- **libsql repo**: https://github.com/tursodatabase/libsql
- **Rustler guide**: https://github.com/rusterlium/rustler
- **Ecto adapter guide**: https://hexdocs.pm/ecto/Ecto.Adapter.html
- **Turso docs**: https://docs.turso.tech/ (for platform API)

## Version Compatibility

- Target libsql 0.x (current stable)
- Document which libsql version you're wrapping
- Update CHANGELOG when bumping libsql dependency
- Test against both local and Turso-hosted instances

## Implementation Phases

### Phase 1: Basic Local Database
- [ ] Local SQLite file support
- [ ] Basic CRUD operations
- [ ] Ecto.Adapter implementation
- [ ] Tests with local database

### Phase 2: Remote Connection
- [ ] Remote URL + auth token support
- [ ] HTTP/WebSocket connection
- [ ] Error handling for network issues
- [ ] Tests against sqld instance

### Phase 3: Embedded Replicas (Killer Feature)
- [ ] Local + remote configuration
- [ ] Manual sync function
- [ ] Optional auto-sync background process
- [ ] Conflict handling
- [ ] Tests for sync behavior

### Phase 4: Advanced Features
- [ ] Vector search support
- [ ] Batch operations
- [ ] Transaction support
- [ ] Connection pooling optimization

### Phase 5: Platform Integration
- [ ] Turso Platform API for database management
- [ ] Database creation/deletion
- [ ] Auth token management
- [ ] Multi-region support

## Questions to Answer During Development

- How to expose sync to Ecto.Repo API cleanly?
- Should embedded replica be default or opt-in?
- Connection pool size recommendations?
- How to handle offline mode gracefully?
- When to sync: before queries, after writes, or timed?
- Error handling for sync conflicts?

## Success Criteria

Your library should:
1. ✅ Work seamlessly with local SQLite files
2. ✅ Connect to Turso-hosted databases
3. ✅ Support embedded replicas with sync
4. ✅ Integrate naturally with Ecto patterns
5. ✅ Have comprehensive test coverage
6. ✅ Perform well (leverage local speed)
7. ✅ Document clearly what it supports

## Getting Help

- libsql Discord: https://discord.gg/turso
- Elixir Forum: https://elixirforum.com
- Rustler issues: https://github.com/rusterlium/rustler/issues
- Turso GitHub: https://github.com/tursodatabase

---

**Remember:** Stick to the libsql Rust crate API documentation. If it's not in https://docs.rs/libsql/, don't implement it yet. Focus on making embedded replicas work excellently—that's the unique value proposition.
