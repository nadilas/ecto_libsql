# Test Extraction & Adaptation Guide
## How to Systematically Port Tests from ecto_sql

This guide provides step-by-step instructions for extracting tests from sibling projects and adapting them for ecto_libsql.

---

## High-Level Process

```
1. Identify test → 2. Extract code → 3. Adapt for SQLite → 4. Create test file → 5. Run & fix
```

---

## Step 1: Identify Test Files

The highest-value tests come from these sources:

### ecto_sql/integration_test/sql/ (Generic SQL-level tests)
- Most portable
- Work with any SQL database
- Minimal SQLite-specific changes needed

**Files**:
- `sql.exs` - Fragment handling, type coercion, edge cases
- `transaction.exs` - Transaction semantics, nesting, savepoints
- `stream.exs` - Streaming large result sets
- `migration.exs` - DDL operations
- `subquery.exs` - Subquery handling
- `sandbox.exs` - Connection isolation (may skip)

### ecto_sql/integration_test/pg/ (PostgreSQL-specific, some adaptable)
- Test adapter-specific features
- Need more modification
- Worth porting for completeness

**Files**:
- `prepare_test.exs` - Prepared statement features (our caching is unique!)
- `constraints_test.exs` - FK, unique, check constraints
- `exceptions_test.exs` - Error handling and messages
- `transactions_test.exs` - Transaction isolation levels

---

## Step 2: Extract Code

### Method A: Automated Copy-Paste

1. Open source file in editor
2. Copy entire test function (including `test "name" do ... end`)
3. Paste into target test file
4. Note line number for reference

**Good for**: Tests under 30 lines, minimal dependencies

### Method B: Manual Selection

1. Read test carefully
2. Identify what's being tested
3. Rewrite using ecto_libsql patterns
4. Add comments explaining adaptations

**Good for**: Tests with complex assertions, DB-specific setup

### Method C: Conceptual Port

1. Understand what test validates
2. Check if it applies to LibSQL
3. Write completely new test using our API

**Good for**: Features unique to LibSQL (savepoints, replica sync)

---

## Step 3: Adapt for SQLite/LibSQL

### Pattern: Array/JSON Handling

**Before** (PostgreSQL):
```elixir
test "array handling" do
  tag = TestRepo.insert!(%Tag{uuids: ["uuid1", "uuid2"]})
  assert [^tag] = TestRepo.all(from t in Tag, where: t.uuids == [])
end
```

**After** (SQLite):
```elixir
@tag :requires_json
test "array handling as json" do
  tag = Repo.insert!(%Tag{uuids: ["uuid1", "uuid2"]})
  
  # SQLite: arrays stored as JSON
  assert [^tag] = Repo.all(from t in Tag, where: t.uuids == [])
  
  # Raw JSON function query
  {:ok, _, result, _} = EctoLibSql.handle_execute(
    "SELECT * FROM tags WHERE json_array_length(uuids) = 0",
    [],
    [],
    state
  )
  assert result.rows == []
end
```

### Pattern: Transaction Modes

**Before** (Generic):
```elixir
test "transaction" do
  {:ok, val} = Repo.transaction(fn ->
    Repo.insert!(%User{name: "Alice"})
    42
  end)
  assert val == 42
end
```

**After** (With SQLite modes):
```elixir
test "transaction deferred mode" do
  {:ok, val} = EctoLibSql.Native.transaction(state, fn state ->
    {:ok, _, _, state} = EctoLibSql.handle_execute(
      "INSERT INTO users (name) VALUES (?)",
      ["Alice"],
      [],
      state
    )
    {:ok, state, 42}
  end, mode: :deferred)
  
  assert val == 42
end

test "transaction immediate mode" do
  # Similar, but with mode: :immediate
  # Tests write lock acquired immediately
end
```

### Pattern: Limitations (Expected Failures)

**Mark tests that document SQLite limitations**:

```elixir
@tag :sqlite_limitation
test "alter table modify column - not supported" do
  # SQLite < 3.35 doesn't support ALTER TABLE MODIFY
  # Document the workaround (recreate table)
  
  {:error, error_msg} = Repo.query("""
    ALTER TABLE users MODIFY COLUMN age TEXT
  """)
  
  assert error_msg =~ "syntax error"
  
  # Correct approach for SQLite:
  # 1. Rename old table to temp
  # 2. Create new table with modified schema  
  # 3. Copy data from temp
  # 4. Drop temp table
end
```

### Pattern: Replica-Specific Tests

**Mark tests for replica mode only**:

```elixir
@tag :replica_mode
test "write syncs to primary" do
  # Only run when database is in replica mode
  {:ok, state} = EctoLibSql.connect([
    database: "replica.db",
    uri: System.get_env("TURSO_URI"),
    auth_token: System.get_env("TURSO_TOKEN"),
    sync: true
  ])
  
  # After write, sync should happen
  {:ok, _, _, state} = EctoLibSql.handle_execute(
    "INSERT INTO users (name) VALUES (?)",
    ["Alice"],
    [],
    state
  )
  
  # Verify it made it to remote
  {:ok, frame} = EctoLibSql.Native.get_frame_number_for_replica(state)
  assert frame > 0
end
```

---

## Step 4: Create Test File

### Template Structure

```elixir
defmodule EctoLibSql.EctoSqlCompatibilityTest do
  use ExUnit.Case, async: true
  
  alias EctoLibSql.TestRepo
  import Ecto.Query
  
  setup do
    {:ok, state} = EctoLibSql.connect(database: ":memory:")
    
    # Create schema
    {:ok, _, _, state} = EctoLibSql.handle_execute(
      "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)",
      [],
      [],
      state
    )
    
    {:ok, state: state}
  end
  
  # ===== TESTS FROM ecto_sql/integration_test/sql/sql.exs =====
  
  describe "fragment handling" do
    test "fragments with operators", %{state: state} do
      # Test code here
    end
  end
  
  # ===== TESTS FROM ecto_sql/integration_test/sql/transaction.exs =====
  
  describe "transaction semantics" do
    test "nested transactions via savepoint", %{state: state} do
      # Test code here
    end
  end
end
```

### File Naming Convention

| Purpose | File Name | Location |
|---------|-----------|----------|
| SQL compatibility | `ecto_sql_compatibility_test.exs` | test/ |
| Transactions | `ecto_sql_transaction_compat_test.exs` | test/ |
| Streaming | `ecto_stream_compat_test.exs` | test/ |
| Prepared statements | `ecto_prepared_stmt_advanced_test.exs` | test/ |
| Constraints | `ecto_constraint_compat_test.exs` | test/ |
| Migrations | `ecto_migration_compat_test.exs` | test/ |

---

## Step 5: Run & Fix

### Quick Verification

```bash
# Test single file
mix test test/ecto_sql_compatibility_test.exs

# Test with output
mix test test/ecto_sql_compatibility_test.exs -v

# Show failures
mix test test/ecto_sql_compatibility_test.exs --failures-only
```

### Common Issues & Fixes

#### Issue: "Connection not found"
**Cause**: Test isn't passing state to query function  
**Fix**:
```elixir
# ❌ Wrong
{:ok, _, result, _} = EctoLibSql.handle_execute(sql, params, [])

# ✅ Right
{:ok, _, result, _} = EctoLibSql.handle_execute(sql, params, [], state)
```

#### Issue: "Table doesn't exist"
**Cause**: Setup didn't create required tables  
**Fix**: Add CREATE TABLE to setup block
```elixir
setup do
  {:ok, state} = EctoLibSql.connect(database: ":memory:")
  
  {:ok, _, _, state} = EctoLibSql.handle_execute(
    "CREATE TABLE my_table (id INTEGER PRIMARY KEY, ...)",
    [],
    [],
    state
  )
  
  {:ok, state: state}
end
```

#### Issue: "PRAGMA not found"
**Cause**: Using Ecto.Repo.query with PRAGMA  
**Fix**: Use native NIF for PRAGMA
```elixir
# ❌ Wrong
Repo.query!("PRAGMA foreign_keys = ON")

# ✅ Right  
{:ok, state} = EctoLibSql.Native.pragma(state, "foreign_keys", "ON")
```

#### Issue: "Type mismatch" or "Invalid argument"
**Cause**: Passing wrong types to parameters  
**Fix**: Check parameter types match schema
```elixir
# ❌ Wrong
EctoLibSql.handle_execute(sql, ["not_an_int"], [], state)

# ✅ Right
EctoLibSql.handle_execute(sql, [123], [], state)
```

---

## Checklist for Each Test

- [ ] Test has descriptive name
- [ ] Test has setup block (if needed)
- [ ] State is passed to all EctoLibSql.handle_execute calls
- [ ] Assertions are clear and specific
- [ ] Comments explain SQLite-specific adaptations
- [ ] Tags applied if test is DB-mode specific (@tag :replica_mode, etc.)
- [ ] Test passes in isolation: `mix test test/file.exs:LINE`
- [ ] Test passes in suite: `mix test test/file.exs`
- [ ] No hard-coded timeouts (use ExUnit.Case async: option)
- [ ] Cleanup happens in teardown (if needed)

---

## Source Files to Reference

### SQL Test Files (Highest Value)
```
/Users/drew/code/ecto_sql/integration_test/sql/sql.exs           (178 lines)
/Users/drew/code/ecto_sql/integration_test/sql/transaction.exs   (277 lines)
/Users/drew/code/ecto_sql/integration_test/sql/stream.exs        (150+ lines)
/Users/drew/code/ecto_sql/integration_test/sql/migration.exs     (400+ lines)
```

### PostgreSQL Adapter Files (Medium Value)
```
/Users/drew/code/ecto_sql/integration_test/pg/prepare_test.exs      (200+ lines)
/Users/drew/code/ecto_sql/integration_test/pg/constraints_test.exs  (250+ lines)
/Users/drew/code/ecto_sql/integration_test/pg/exceptions_test.exs   (150+ lines)
```

### Support Files to Reference
```
/Users/drew/code/ecto_sql/integration_test/support/      # Schemas, helpers
```

---

## Working Example: Porting a Single Test

### Original Test (from sql.exs, line 12)

```elixir
test "fragmented types" do
  datetime = ~N[2014-01-16 20:26:51]
  TestRepo.insert!(%Post{inserted_at: datetime})
  query = from p in Post, where: fragment("? >= ?", p.inserted_at, ^datetime), select: p.inserted_at
  assert [^datetime] = TestRepo.all(query)
end
```

### Step-by-Step Adaptation

**1. Understand**: Tests that fragments in WHERE clauses work with datetime values

**2. Check SQLite compatibility**: Yes, SQLite supports fragment() and datetime comparison

**3. Convert to EctoLibSql API**:

```elixir
test "fragmented types" do
  {:ok, state} = EctoLibSql.connect(database: ":memory:")
  
  # Create schema
  {:ok, _, _, state} = EctoLibSql.handle_execute("""
    CREATE TABLE posts (
      id INTEGER PRIMARY KEY,
      title TEXT,
      inserted_at DATETIME
    )
  """, [], [], state)
  
  # Insert data
  datetime = ~N[2014-01-16 20:26:51]
  {:ok, _, _, state} = EctoLibSql.handle_execute(
    "INSERT INTO posts (title, inserted_at) VALUES (?, ?)",
    ["Test", datetime],
    [],
    state
  )
  
  # Query with fragment (converted to raw SQL)
  {:ok, _, result, state} = EctoLibSql.handle_execute(
    "SELECT inserted_at FROM posts WHERE inserted_at >= ?",
    [datetime],
    [],
    state
  )
  
  # Verify result
  assert result.rows == [[datetime]]
end
```

**4. Place in file**: Add to `test/ecto_sql_compatibility_test.exs` under "Fragment handling" describe block

**5. Run**: `mix test test/ecto_sql_compatibility_test.exs:5` (specific line)

**6. Fix**: If it fails, adjust datetime handling (SQLite stores as ISO8601 text)

---

## Tips & Tricks

### Bulk Copy Pattern
When tests are very similar, use parameterized tests:

```elixir
@fragment_tests [
  {"? >= ?", [42], [[42]]},
  {"? + ?", [2, 3], [[5]]},
  {"? || ?", ["hello", " world"], [["hello world"]]}
]

for {fragment_sql, params, expected} <- @fragment_tests do
  test "fragment: #{fragment_sql}" do
    {:ok, _, result, _} = EctoLibSql.handle_execute(
      "SELECT " <> fragment_sql,
      params,
      [],
      state
    )
    assert result.rows == expected
  end
end
```

### Shared Setup Pattern
Extract common setup to helper functions:

```elixir
defp create_test_table(state, name \\ "test") do
  EctoLibSql.handle_execute(
    "CREATE TABLE #{name} (id INTEGER PRIMARY KEY, data TEXT)",
    [],
    [],
    state
  )
end

setup do
  {:ok, state} = EctoLibSql.connect(database: ":memory:")
  {:ok, _, _, state} = create_test_table(state, "users")
  {:ok, state: state}
end
```

### Skip/Tag Pattern
Mark tests that need special handling:

```elixir
@tag :skip_for_now
test "pending feature" do
  # Will be skipped
end

@tag :replica_mode
@tag :slow
test "slow replica operation" do
  # Only run when explicitly requested
  # mix test --include slow --include replica_mode
end
```

---

## Next Steps

1. **Pick one test file** from the list above
2. **Extract 3-5 tests** from it
3. **Create a new test file** in test/
4. **Run and verify** all tests pass
5. **Commit** with reference to source file
6. **Iterate** with next batch

**Estimated timeline**: 
- 2 hours per test file
- 5 files = ~2 weeks part-time
- Results in 55+ new tests, 2,000+ lines

Good luck! 🚀
