# Test Import Checklist

## Phase 1: Foundation (SQL Compatibility)
**Target**: 20-25 new tests, ~1-2 weeks

### ecto_sql_compatibility_test.exs
Source: `/Users/drew/code/ecto_sql/integration_test/sql/sql.exs`

- [ ] Fragment handling (3-4 tests)
  - [ ] `test "fragmented types"` 
  - [ ] `test "fragmented schemaless types"`
  - [ ] Type conversion edge cases
  
- [ ] Type system (3-4 tests)
  - [ ] Negative integers
  - [ ] NULL handling
  - [ ] JSON/Array handling (SQLite adaptation)

- [ ] Edge cases (2-3 tests)
  - [ ] Dynamic repo in queries
  - [ ] Count aggregation
  - [ ] LIMIT/OFFSET

### ecto_stream_compat_test.exs
Source: `/Users/drew/code/ecto_sql/integration_test/sql/stream.exs`

- [ ] Basic streaming (2-3 tests)
  - [ ] Stream all records
  - [ ] Stream with max_rows
  - [ ] Cursor lifecycle

- [ ] Memory efficiency (2-3 tests)
  - [ ] Large dataset without loading all
  - [ ] Cursor cleanup on error

---

## Phase 2: Core Features
**Target**: 35-50 total tests, ~2-3 weeks

### ecto_sql_transaction_compat_test.exs
Source: `/Users/drew/code/ecto_sql/integration_test/sql/transaction.exs`

- [ ] Basic transaction behavior (3-4 tests)
  - [ ] Transaction returns value
  - [ ] Transaction re-raises errors
  - [ ] In-transaction? checks

- [ ] Rollback scenarios (2-3 tests)
  - [ ] Explicit rollback
  - [ ] Error-triggered rollback
  - [ ] Failed query rollback

- [ ] LibSQL-specific modes (4-5 tests)
  - [ ] DEFERRED mode (default)
  - [ ] IMMEDIATE mode
  - [ ] EXCLUSIVE mode
  - [ ] READ_ONLY mode

- [ ] Savepoint tests (3-4 tests) ⭐ NEW FOR SQLite
  - [ ] Create and release savepoint
  - [ ] Rollback to savepoint
  - [ ] Multiple savepoints
  - [ ] Savepoint error recovery

- [ ] Nested transaction behavior (2-3 tests)
  - [ ] Nested transactions become savepoints
  - [ ] Isolation between savepoints
  - [ ] Partial rollback

### ecto_prepared_stmt_advanced_test.exs / prepared_statement_test.exs
Source: `/Users/drew/code/ecto_sql/integration_test/pg/prepare_test.exs`

- [x] Statement introspection (3-4 tests) ✅ COMPLETE
  - [x] Parameter count
  - [x] Column count
  - [x] Column names

- [x] Caching behavior (2-3 tests) ⭐ OUR UNIQUE FEATURE ✅ COMPLETE (Dec 23, 2025)
  - [x] Auto-reset of bindings - `test "prepared statement auto-reset of bindings between executions"`
  - [x] Statement reuse with different types - `test "prepared statement reuse with different parameter types"`
  - [x] Memory efficiency - `test "prepared statement memory efficiency with many executions"`

- [x] Performance benchmarks (2-3 tests) ✅ COMPLETE (Dec 23, 2025)
  - [x] Prepared vs unprepared comparison - `test "prepared vs unprepared statement performance comparison"`
  - [x] Speedup measurements - Shows 2-2.5x speedup in practice

---

## Phase 3: Completeness
**Target**: 50-65 total tests, ~3-4 weeks

### ecto_constraint_compat_test.exs
Source: `/Users/drew/code/ecto_sql/integration_test/pg/constraints_test.exs`

- [ ] Foreign key constraints (3-4 tests)
  - [ ] FK enforcement (PRAGMA foreign_keys = ON)
  - [ ] Cascade delete
  - [ ] FK violation errors

- [ ] Unique constraints (2-3 tests)
  - [ ] Unique constraint violation
  - [ ] Error messages

- [ ] Check constraints (1-2 tests)
  - [ ] Check constraint enforcement
  - [ ] Check violation errors

- [ ] Conflict resolution (1-2 tests)
  - [ ] INSERT OR REPLACE
  - [ ] INSERT OR IGNORE

### ecto_migration_compat_test.exs
Source: `/Users/drew/code/ecto_sql/integration_test/sql/migration.exs`

- [ ] Table operations (2-3 tests)
  - [ ] CREATE TABLE
  - [ ] Drop table
  - [ ] Table exists

- [ ] Column operations (3-4 tests)
  - [ ] Add column ✅ Supported
  - [ ] Rename column ✅ Supported (3.25+)
  - [ ] Modify column ❌ NOT supported (document)
  - [ ] Drop column ❌ NOT supported < 3.35 (document)

- [ ] Index operations (2-3 tests)
  - [ ] Create index
  - [ ] Unique index
  - [ ] Index performance

- [ ] Schema versioning (1-2 tests) ⭐ SQLite-specific
  - [ ] PRAGMA user_version
  - [ ] Migration tracking

---

## Phase 4: Polish & Validation
**Target**: 65-75 total tests, ~4+ weeks

### error_handling_test.exs (update)
Source: `/Users/drew/code/ecto_sql/integration_test/pg/exceptions_test.exs`

- [ ] Syntax errors (1 test)
- [ ] Table not found (1 test)
- [ ] Constraint violations (1 test)
- [ ] Type mismatches (1 test)
- [ ] Database locked (replica mode only) (1 test)

### Cross-mode validation
- [ ] Run all tests in local mode ✅
- [ ] Run all tests in remote mode (requires Turso)
- [ ] Run all tests in replica mode (requires Turso)

### Documentation
- [ ] Create compatibility matrix (Ecto vs EctoLibSQL)
- [ ] Document all known limitations
- [ ] Document all workarounds
- [ ] Update AGENTS.md with test references

---

## Progress Tracking

### Week 1 (Phase 1)
- [ ] Monday: Create ecto_sql_compatibility_test.exs (3-4 tests)
- [ ] Tuesday: Add streaming tests to ecto_stream_compat_test.exs (4-5 tests)
- [ ] Wednesday: Run Phase 1 tests, fix failures
- [ ] Thursday: Code review & commit Phase 1
- [ ] Friday: Buffer/contingency

**Metrics**: 20-25 tests, 1,000+ LOC added

### Week 2 (Phase 2)
- [ ] Monday: Create transaction compat test file, add 5-6 tests
- [ ] Tuesday: Add savepoint tests (3-4 tests)
- [ ] Wednesday: Create prepared stmt test file, introspection (3-4 tests)
- [ ] Thursday: Add caching/performance tests (3-4 tests)
- [ ] Friday: Run Phase 2 tests, fix failures

**Metrics**: 35-50 total tests, 2,500+ LOC added

### Week 3 (Phase 3)
- [ ] Monday: Create constraint test file, add FK tests (3-4 tests)
- [ ] Tuesday: Add unique/check constraint tests (2-3 tests)
- [ ] Wednesday: Create migration test file, add DDL tests (4-5 tests)
- [ ] Thursday: Add schema versioning tests (1-2 tests)
- [ ] Friday: Run Phase 3 tests, fix failures

**Metrics**: 50-65 total tests, 3,500+ LOC added

### Week 4+ (Phase 4)
- [ ] Monday: Add exception handling tests (5 tests)
- [ ] Tuesday-Thursday: Cross-mode validation (local/remote/replica)
- [ ] Friday: Documentation and compatibility matrix

**Metrics**: 65-75 total tests, 4,000+ LOC added

---

## Test File Template

```elixir
defmodule EctoLibSql.EctoSqlCompatibilityTest do
  use ExUnit.Case, async: true
  
  # Setup
  setup do
    {:ok, state} = EctoLibSql.connect(database: ":memory:")
    
    # Create schema as needed for tests
    
    {:ok, state: state}
  end
  
  # Describe blocks for organization
  describe "fragment handling" do
    test "fragmented types with operators", %{state: state} do
      # Test code
    end
  end
  
  describe "type conversion" do
    test "negative integers", %{state: state} do
      # Test code
    end
  end
end
```

---

## Adaptation Checklist

For each test being ported:

- [ ] Test name is clear and describes what's tested
- [ ] Setup creates all required tables
- [ ] All EctoLibSql.handle_execute calls pass state
- [ ] Parameter types match schema
- [ ] Assertions are specific
- [ ] Comments explain SQLite differences
- [ ] Tags applied (@tag :replica_mode, @tag :sqlite_only, etc.)
- [ ] No hard-coded timeouts
- [ ] Test passes in isolation: `mix test test/file.exs:LINE`
- [ ] Test passes in full suite: `mix test test/file.exs`
- [ ] Cleanup happens (if needed in teardown)

---

## Common Failure Patterns

When adapting tests, watch for:

| Error | Cause | Fix |
|-------|-------|-----|
| "Connection not found" | Missing state param | Add state to handle_execute |
| "Table doesn't exist" | Setup incomplete | Add CREATE TABLE in setup |
| "Type mismatch" | Wrong param type | Ensure params match schema |
| "Invalid connection ID" | Using wrong state | Pass correct state variable |
| "no such table" | Table name typo | Check CREATE TABLE statement |
| "PRAGMA not found" | Using Repo.query | Use EctoLibSql.Native.pragma |

---

## Resources

**Read in this order**:
1. TEST_IMPORT_SUMMARY.md (overview)
2. TEST_SUITE_CONSOLIDATION_PLAN.md (strategy)
3. TESTS_TO_PORT.md (code examples)
4. TEST_EXTRACTION_GUIDE.md (how-to)

**Reference during work**:
- test/ecto_integration_test.exs (existing patterns)
- test/error_handling_test.exs (error handling examples)
- AGENTS.md (API reference)

---

## Commit Message Format

```
test: port [description] from ecto_sql

Description: Brief description of what was ported
Source: /path/to/source/file.exs
Tests: List of test functions added
Adaptations: SQLite-specific changes made

- Brief bullet point 1
- Brief bullet point 2
```

Example:
```
test: port transaction semantics from ecto_sql

Source: ecto_sql/integration_test/sql/transaction.exs
Tests: test_nested_transactions, test_savepoint_rollback
Adaptations: Added LibSQL transaction modes (DEFERRED, IMMEDIATE, EXCLUSIVE)

- Converted nested transactions to SAVEPOINT (SQLite native)
- Added tests for PRAGMA foreign_keys requirement
- Verified isolation levels across all modes
```

---

## Success Criteria

**Phase 1 Complete** ✅
- 20-25 new tests
- All tests pass locally
- ~1,000 new lines
- Suite at 9,500+ lines

**Phase 2 Complete** ✅
- 35-50 total tests
- All transaction tests pass
- Savepoint tests comprehensive
- Prepared statement caching validated
- ~2,500 new lines
- Suite at 10,000+ lines

**Phase 3 Complete** ✅
- 50-65 total tests
- Constraint tests thorough
- Migration limitations documented
- Schema versioning tested
- ~3,500 new lines
- Suite at 11,000+ lines

**Phase 4 Complete** ✅
- 65-75 total tests
- All exception tests added
- Cross-mode validation done
- Compatibility matrix published
- ~4,000 new lines
- Suite at 12,000+ lines

---

## Go/No-Go Decisions

**Before starting Phase X, verify**:

- Previous phase tests all passing ✅
- No regressions in existing tests ✅
- Code compiles cleanly ✅
- Documentation up to date ✅

---

Last updated: December 18, 2025
