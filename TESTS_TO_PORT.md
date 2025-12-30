# Specific Tests to Port from ecto_sql

This document lists specific test cases from ecto_sql that should be ported to ecto_libsql, with adaptation notes.

---

## 1. SQL Fragment & Type Tests
**Source**: `/Users/drew/code/ecto_sql/integration_test/sql/sql.exs`  
**Target**: `test/ecto_sql_compatibility_test.exs`

### Tests to Include (Lines Indicated)

```elixir
# Fragment tests - these handle type coercion in SQL expressions
test "fragmented types" (line 12)
  # Verify datetime fragments work correctly
  # Ecto generates: fragment("? >= ?", p.inserted_at, ^datetime)
  
test "fragmented schemaless types" (line 19)
  # Test fragment with type/2 in schemaless context
  
test "type casting negative integers" (line 24)
  # Edge case: negative integers in type/2
  
# Array handling (mark with @tag :sqlite_json)
test "Converts empty array correctly" (line 38)
  # ADAPTATION: SQLite doesn't have native arrays
  # Use JSON arrays instead:
  # tag.uuids stored as JSON: ["uuid1", "uuid2"]
  # Query: where t.uuids == [] becomes json_array_length(uuids) = 0

# Type edge cases
test "null coalesce" (if exists)
  # COALESCE behavior in SQLite
  
test "decimals" (if exists)
  # SQLite stores as DECIMAL text
  
test "uuid" (if exists)
  # TEXT column for UUIDs
  
test "json" (if exists)
  # Native JSON1 extension support
```

### Adaptation Notes
- **Arrays**: Mark with `@tag :requires_json`. Adapt tests to use `json_array()` or JSON columns
- **Type precision**: SQLite doesn't have true DECIMAL; test TEXT storage
- **Date/Time**: Ensure ISO8601 string format works
- **Boolean**: Test that 0/1 integer encoding works

---

## 2. Transaction Semantics
**Source**: `/Users/drew/code/ecto_sql/integration_test/sql/transaction.exs`  
**Target**: `test/ecto_sql_transaction_compat_test.exs`

### Critical Tests to Include

```elixir
# Basic transaction behavior
test "transaction returns value" (line 29)
  # Verify nested transaction semantics work
  # In SQLite, nested transactions become SAVEPOINT
  
test "transaction re-raises" (line 45)
  # Errors in transaction should abort and rollback
  
test "transaction is not started on errors" (line ~65)
  # Failed query shouldn't leave transaction open
  
test "transaction rollback on manual rollback" (line ~80)
  # Explicit rollback handling
  
test "transaction with savepoint" (line ~120)
  # Nested transaction support via SAVEPOINT
  
test "multiple transactions are isolated" (line ~150)
  # Verify transaction isolation (SQLite SERIALIZABLE mode)
```

### SQLite-Specific Adaptations

```elixir
# Test transaction modes available in LibSQL
test "transaction with DEFERRED mode" do
  # BEGIN DEFERRED (default, locks on first write)
  {:ok, result} = Repo.transaction(fn ->
    Repo.insert!(%User{name: "Alice"})
    :ok
  end, options: [mode: :deferred])
end

test "transaction with IMMEDIATE mode" do
  # BEGIN IMMEDIATE (locks immediately)
  {:ok, result} = Repo.transaction(fn ->
    Repo.insert!(%User{name: "Bob"})
  end, options: [mode: :immediate])
end

test "transaction with EXCLUSIVE mode" do
  # BEGIN EXCLUSIVE (exclusive lock, blocks all)
  {:ok, result} = Repo.transaction(fn ->
    Repo.update_all(User, set: [active: false])
  end, options: [mode: :exclusive])
end

test "transaction with READ_ONLY mode" do
  # BEGIN READ ONLY (no locks)
  {:ok, result} = Repo.transaction(fn ->
    Repo.all(User)
  end, options: [mode: :read_only])
end
```

### Savepoint Tests

```elixir
# These are unique to SQLite (SAVEPOINT)
test "savepoint within transaction" do
  {:ok, result} = Repo.transaction(fn ->
    {:ok, user1} = Repo.insert(%User{name: "Alice"})
    
    # Create savepoint
    Repo.savepoint(:sp1)
    
    {:ok, user2} = Repo.insert(%User{name: "Bob"})
    
    # Rollback to savepoint
    Repo.rollback_to_savepoint(:sp1)
    
    # user2 insertion is rolled back
    Repo.all(User)  # Should only have user1
  end)
end

test "multiple savepoints" do
  {:ok, result} = Repo.transaction(fn ->
    Repo.savepoint(:sp1)
    Repo.insert!(%User{name: "Alice"})
    
    Repo.savepoint(:sp2)
    Repo.insert!(%User{name: "Bob"})
    
    Repo.rollback_to_savepoint(:sp2)  # Rollback Bob
    Repo.release_savepoint(:sp1)       # Commit Alice
    
    Repo.all(User)  # Should have 1 user
  end)
end
```

### Replica Mode Specific

```elixir
# These tests should be marked with @tag :replica_mode
test "transaction on replica syncs to primary" do
  # WRITE in transaction should trigger sync
  {:ok, result} = Repo.transaction(fn ->
    Repo.insert!(%User{name: "Alice"})
  end)
  
  # Verify write made it to remote
  assert {:ok, user} = remote_query_user("Alice")
end
```

---

## 3. Streaming & Cursor Operations
**Source**: `/Users/drew/code/ecto_sql/integration_test/sql/stream.exs`  
**Target**: `test/ecto_stream_compat_test.exs`

### Tests to Port

```elixir
# Basic streaming
test "stream all" do
  # Insert 10K records
  records = Enum.map(1..10_000, fn i ->
    %User{name: "User#{i}", email: "user#{i}@example.com"}
  end)
  Repo.insert_all(User, records)
  
  # Stream without loading all into memory
  count = 0
  Repo.stream(User)
  |> Stream.each(fn _user -> count = count + 1 end)
  |> Stream.run()
  
  assert count == 10_000
end

test "stream with max_rows" do
  # Fetch in chunks of 100
  Repo.stream(User, max_rows: 100)
  |> Enum.each(fn result ->
    assert length(result.rows) <= 100
  end)
end

test "stream with query" do
  # Stream filtered results
  from u in User, where: u.active == true
  |> Repo.stream()
  |> Stream.map(fn user -> user.name end)
  |> Enum.to_list()
end

test "stream with limit" do
  # Streaming respects LIMIT
  from u in User, limit: 100
  |> Repo.stream()
  |> Enum.count()
  |> then(&assert &1 == 100)
end
```

### Memory Efficiency Tests

```elixir
# Verify memory doesn't explode with large datasets
test "streaming 1M records doesn't consume excessive memory" do
  # This is a property test - memory usage stays constant
  :ok
end

test "cursor cleanup on error" do
  # If stream raises, cursor should still close
  assert_raise RuntimeError, fn ->
    Repo.stream(User)
    |> Stream.map(fn user ->
      if user.id > 1000 do
        raise "Stop"
      end
      user
    end)
    |> Enum.to_list()
  end
  
  # Next stream should work fine (cursor cleaned up)
  count = Repo.stream(User) |> Enum.count()
  assert count > 0
end
```

---

## 4. Prepared Statement Features
**Source**: `/Users/drew/code/ecto_sql/integration_test/pg/prepare_test.exs`  
**Target**: `test/ecto_prepared_stmt_advanced_test.exs`

### Tests to Include

```elixir
# LibSQL v0.7.0 has automatic caching and introspection
test "statement parameter count" do
  {:ok, stmt_id} = EctoLibSql.Native.prepare(
    state,
    "SELECT * FROM users WHERE id = ? AND name = ?"
  )
  
  {:ok, param_count} = EctoLibSql.Native.stmt_parameter_count(state, stmt_id)
  assert param_count == 2
  
  :ok = EctoLibSql.Native.close_stmt(stmt_id)
end

test "statement column count" do
  {:ok, stmt_id} = EctoLibSql.Native.prepare(
    state,
    "SELECT id, name, email FROM users"
  )
  
  {:ok, col_count} = EctoLibSql.Native.stmt_column_count(state, stmt_id)
  assert col_count == 3
  
  :ok = EctoLibSql.Native.close_stmt(stmt_id)
end

test "statement column names" do
  {:ok, stmt_id} = EctoLibSql.Native.prepare(
    state,
    "SELECT id, name, email FROM users"
  )
  
  {:ok, name0} = EctoLibSql.Native.stmt_column_name(state, stmt_id, 0)
  {:ok, name1} = EctoLibSql.Native.stmt_column_name(state, stmt_id, 1)
  {:ok, name2} = EctoLibSql.Native.stmt_column_name(state, stmt_id, 2)
  
  assert [name0, name1, name2] == ["id", "name", "email"]
  
  :ok = EctoLibSql.Native.close_stmt(stmt_id)
end

test "prepared statement caching performance" do
  {:ok, stmt_id} = EctoLibSql.Native.prepare(
    state,
    "SELECT * FROM users WHERE id = ?"
  )
  
  # First execution
  start = System.monotonic_time(:microsecond)
  {:ok, result1} = EctoLibSql.Native.query_stmt(state, stmt_id, [1])
  time1 = System.monotonic_time(:microsecond) - start
  
  # Second execution (should be faster due to caching)
  start = System.monotonic_time(:microsecond)
  {:ok, result2} = EctoLibSql.Native.query_stmt(state, stmt_id, [2])
  time2 = System.monotonic_time(:microsecond) - start
  
  # Cached statement should be faster or similar
  # (avoid hard assertions on timing)
  assert result1.columns == result2.columns
  
  :ok = EctoLibSql.Native.close_stmt(stmt_id)
end

test "prepared statement auto-reset of bindings" do
  # v0.7.0 feature: bindings auto-reset between calls
  {:ok, stmt_id} = EctoLibSql.Native.prepare(
    state,
    "SELECT ? as value"
  )
  
  # First query
  {:ok, result1} = EctoLibSql.Native.query_stmt(state, stmt_id, [42])
  assert result1.rows == [[42]]
  
  # Second query with different parameter (should work, not reuse old binding)
  {:ok, result2} = EctoLibSql.Native.query_stmt(state, stmt_id, [99])
  assert result2.rows == [[99]]
  
  # NOT [[42]] - binding was reset
  
  :ok = EctoLibSql.Native.close_stmt(stmt_id)
end
```

### Performance Comparison Tests

```elixir
test "prepared vs unprepared performance" do
  # Setup: 100 users
  Enum.each(1..100, fn i ->
    Repo.insert!(%User{id: i, name: "User#{i}"})
  end)
  
  # Unprepared: re-compile each time
  start = System.monotonic_time(:microsecond)
  Enum.each(1..100, fn i ->
    {:ok, _query, result, _state} = EctoLibSql.handle_execute(
      "SELECT * FROM users WHERE id = ?",
      [i],
      [],
      state
    )
  end)
  unprepared_time = System.monotonic_time(:microsecond) - start
  
  # Prepared: compile once, reuse
  {:ok, stmt_id} = EctoLibSql.Native.prepare(state, "SELECT * FROM users WHERE id = ?")
  
  start = System.monotonic_time(:microsecond)
  Enum.each(1..100, fn i ->
    {:ok, _result} = EctoLibSql.Native.query_stmt(state, stmt_id, [i])
  end)
  prepared_time = System.monotonic_time(:microsecond) - start
  
  :ok = EctoLibSql.Native.close_stmt(stmt_id)
  
  # Prepared should be significantly faster (10x+)
  speedup = unprepared_time / prepared_time
  IO.puts("Prepared statement speedup: #{speedup}x")
  assert speedup > 5, "Expected 5x+ speedup with prepared statements"
end
```

---

## 5. Constraint Handling
**Source**: `/Users/drew/code/ecto_sql/integration_test/pg/constraints_test.exs`  
**Target**: `test/ecto_constraint_compat_test.exs`

### Tests to Adapt

```elixir
# Foreign key constraints
test "foreign key constraint enforcement" do
  # SQLite requires: PRAGMA foreign_keys = ON
  {:ok, state} = EctoLibSql.Native.pragma(state, "foreign_keys", "ON")
  
  # Insert user
  {:ok, _, _, state} = EctoLibSql.handle_execute(
    "INSERT INTO users (id, name) VALUES (?, ?)",
    [1, "Alice"],
    [],
    state
  )
  
  # Try to insert post with non-existent user_id
  {:error, _reason, _, state} = EctoLibSql.handle_execute(
    "INSERT INTO posts (id, user_id, title) VALUES (?, ?, ?)",
    [1, 999, "Orphan Post"],
    [],
    state
  )
  # Should fail with foreign key constraint error
end

# Unique constraints
test "unique constraint violation" do
  Repo.insert!(%User{email: "alice@example.com"})
  
  {:error, changeset} = Repo.insert(%User{email: "alice@example.com"})
  assert {:email, {"has already been taken", [constraint: :unique]}} in changeset.errors
end

# Check constraints
test "check constraint" do
  # Table schema:
  # CREATE TABLE users (
  #   age INTEGER CHECK (age >= 18)
  # )
  
  {:error, _reason, _, state} = EctoLibSql.handle_execute(
    "INSERT INTO users (age) VALUES (?)",
    [15],
    [],
    state
  )
  # Should fail - age check constraint
end

# ON CONFLICT / UPSERT
test "on conflict replace" do
  # SQLite supports: INSERT OR REPLACE
  # PostgreSQL uses: ON CONFLICT
  
  {:ok, _, _, state} = EctoLibSql.handle_execute(
    "INSERT OR REPLACE INTO users (id, email) VALUES (?, ?)",
    [1, "alice@example.com"],
    [],
    state
  )
  
  # Second insert with same ID replaces
  {:ok, _, _, state} = EctoLibSql.handle_execute(
    "INSERT OR REPLACE INTO users (id, email) VALUES (?, ?)",
    [1, "alice.new@example.com"],
    [],
    state
  )
  
  {:ok, _, result, state} = EctoLibSql.handle_execute(
    "SELECT * FROM users WHERE id = ?",
    [1],
    [],
    state
  )
  
  # Should have new email
  [[_id, "alice.new@example.com"]] = result.rows
end
```

---

## 6. Migration Handling
**Source**: `/Users/drew/code/ecto_sql/integration_test/sql/migration.exs`  
**Target**: `test/ecto_migration_compat_test.exs`

### SQLite-Compatible Migration Tests

```elixir
# Basic DDL operations (all supported)
test "create table" do
  assert {:ok, _} = Repo.query("""
    CREATE TABLE IF NOT EXISTS test_table (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  """)
end

test "create index" do
  Repo.query!("CREATE TABLE test (id INTEGER, name TEXT)")
  
  assert {:ok, _} = Repo.query(
    "CREATE INDEX idx_test_name ON test(name)"
  )
  
  # Index should speed up queries
  assert {:ok, _} = Repo.query("SELECT * FROM test WHERE name = 'Alice'")
end

# Limitations of SQLite ALTER TABLE
test "add column" do
  Repo.query!("CREATE TABLE test (id INTEGER PRIMARY KEY)")
  
  # Add column works in SQLite
  assert {:ok, _} = Repo.query(
    "ALTER TABLE test ADD COLUMN name TEXT DEFAULT 'unknown'"
  )
end

test "rename column" do
  Repo.query!("CREATE TABLE test (id INTEGER, old_name TEXT)")
  
  # SQLite 3.25.0+ supports RENAME
  # Mark test based on version
  assert {:ok, _} = Repo.query(
    "ALTER TABLE test RENAME COLUMN old_name TO new_name"
  )
end

# These operations NOT supported - test that they fail gracefully
test "modify column type - not supported in SQLite < 3.35" do
  Repo.query!("CREATE TABLE test (id INTEGER, value INTEGER)")
  
  # This should fail with clear error
  result = Repo.query(
    "ALTER TABLE test MODIFY COLUMN value TEXT"
  )
  
  # Document that user must use recreate table pattern
  # (see AGENTS.md workaround)
  assert {:error, _} = result
end

test "drop column - not supported in SQLite < 3.35" do
  Repo.query!("CREATE TABLE test (id INTEGER, remove_me TEXT)")
  
  # Should fail
  result = Repo.query(
    "ALTER TABLE test DROP COLUMN remove_me"
  )
  
  assert {:error, _} = result
end

# Schema versioning (unique to SQLite)
test "schema version tracking with PRAGMA user_version" do
  # Get current version
  {:ok, _query, result, state} = EctoLibSql.handle_execute(
    "PRAGMA user_version",
    [],
    [],
    state
  )
  
  current_version = result.rows |> hd() |> hd()
  
  # Update version for migration tracking
  {:ok, _, _, state} = EctoLibSql.handle_execute(
    "PRAGMA user_version = #{current_version + 1}",
    [],
    [],
    state
  )
  
  # Verify update
  {:ok, _query, result, state} = EctoLibSql.handle_execute(
    "PRAGMA user_version",
    [],
    [],
    state
  )
  
  new_version = result.rows |> hd() |> hd()
  assert new_version == current_version + 1
end

# Foreign key handling in migrations
test "migration with foreign keys" do
  # First: enable foreign keys
  {:ok, state} = EctoLibSql.Native.pragma(state, "foreign_keys", "ON")
  
  # Create parent table
  {:ok, _, _, state} = EctoLibSql.handle_execute(
    "CREATE TABLE parents (id INTEGER PRIMARY KEY)",
    [],
    [],
    state
  )
  
  # Create child table with FK
  {:ok, _, _, state} = EctoLibSql.handle_execute(
    """
    CREATE TABLE children (
      id INTEGER PRIMARY KEY,
      parent_id INTEGER NOT NULL,
      FOREIGN KEY(parent_id) REFERENCES parents(id) ON DELETE CASCADE
    )
    """,
    [],
    [],
    state
  )
  
  # Verify FK works
  {:ok, _, _, state} = EctoLibSql.handle_execute(
    "INSERT INTO parents VALUES (1)",
    [],
    [],
    state
  )
  
  {:ok, _, _, state} = EctoLibSql.handle_execute(
    "INSERT INTO children VALUES (1, 1)",
    [],
    [],
    state
  )
  
  # Cascade delete
  {:ok, _, _, state} = EctoLibSql.handle_execute(
    "DELETE FROM parents WHERE id = 1",
    [],
    [],
    state
  )
  
  {:ok, _, result, state} = EctoLibSql.handle_execute(
    "SELECT * FROM children",
    [],
    [],
    state
  )
  
  # Child should be deleted
  assert result.rows == []
end
```

---

## 7. Exception Handling
**Source**: `/Users/drew/code/ecto_sql/integration_test/pg/exceptions_test.exs`  
**Target**: Update `test/error_handling_test.exs`

### Tests to Add

```elixir
test "syntax error returns proper exception" do
  assert_raise EctoLibSql.Error, ~r/syntax error/, fn ->
    Repo.query!("SELCT * FROM users")
  end
end

test "table not found error" do
  assert_raise EctoLibSql.Error, ~r/no such table/, fn ->
    Repo.query!("SELECT * FROM nonexistent_table")
  end
end

test "constraint violation error" do
  Repo.insert!(%User{id: 1, email: "alice@example.com"})
  
  assert_raise EctoLibSql.Error, ~r/UNIQUE constraint failed/, fn ->
    Repo.insert!(%User{id: 1, email: "alice@example.com"})
  end
end

test "type mismatch error" do
  # Attempting to insert non-integer into INTEGER column
  assert_raise _ , fn ->
    Repo.query!("INSERT INTO users (id) VALUES (?)", ["not_an_int"])
  end
end

test "database locked error on replica" do
  # REPLICA MODE ONLY
  # If write happens while sync is in progress
  {:error, :database_locked} = attempt_write_during_sync()
end
```

---

## Summary Table

| Test Group | Source | Target File | Tests | Effort |
|-----------|--------|------------|-------|--------|
| Fragment & Types | sql/sql.exs | ecto_sql_compatibility_test.exs | 8-10 | 🟢 |
| Transactions | sql/transaction.exs | ecto_sql_transaction_compat_test.exs | 12-15 | 🟡 |
| Streaming | sql/stream.exs | ecto_stream_compat_test.exs | 6-8 | 🟢 |
| Prepared Stmts | pg/prepare_test.exs | ecto_prepared_stmt_advanced_test.exs | 8-10 | 🟡 |
| Constraints | pg/constraints_test.exs | ecto_constraint_compat_test.exs | 6-8 | 🟡 |
| Migrations | sql/migration.exs | ecto_migration_compat_test.exs | 10-12 | 🟡 |
| Exceptions | pg/exceptions_test.exs | error_handling_test.exs | 5-7 | 🟢 |

**Total New Tests**: ~55-70  
**Total New Lines**: ~2,000-2,500  
**Expected Test Suite Growth**: 8,765 → 11,000+ lines

