# Test Suite Consolidation Plan
## Integrating Tests from Related Projects

**Date**: December 18, 2025  
**Goal**: Bring in relevant tests from sibling projects (libsql, ecto, ecto_sql) to ensure comprehensive coverage of libSQL API implementation.

---

## Current State Analysis

### ecto_libsql Test Suite
- **Location**: `/Users/drew/code/ecto_libsql/test/`
- **Total Lines**: ~8,765
- **Files**: 20 test modules
- **Coverage Areas**:
  - Ecto adapter integration (ecto_connection_test.exs, ecto_adapter_test.exs)
  - Migrations (ecto_migration_test.exs)
  - Advanced features (vector search, geospatial)
  - Transactions & savepoints
  - Prepared statements & caching
  - Error handling
  - Security
  - Turso remote operations

### Related Projects

#### ecto_sql/integration_test
- **Location**: `/Users/drew/code/ecto_sql/integration_test/`
- **Total Lines**: ~3,000+ (sql/ subfolder)
- **Database Adapters**: pg/, myxql/, tds/, sql/
- **Key Test Files**:
  - `sql/sql.exs` - Core SQL functionality (fragments, types, edge cases)
  - `sql/transaction.exs` - Transaction semantics and nesting
  - `sql/migration.exs` - Migration execution
  - `sql/stream.exs` - Streaming operations
  - `pg/transaction_test.exs` - PostgreSQL-specific transaction tests
  - `pg/constraints_test.exs` - Constraint handling
  - `pg/prepare_test.exs` - Prepared statement features

#### ecto
- **Location**: `/Users/drew/code/ecto/`
- **Scope**: Core Ecto library (schemas, changesets, queries)
- **Already Referenced**: These tests are more about Ecto itself, less about adapter-specific behavior

#### libsql
- **Location**: `/Users/drew/code/libsql/`
- **Type**: C/Rust tests for libSQL core
- **Scope**: Lower-level SQLite/libSQL functionality
- **Less Relevant**: These are pre-compiled and SQL-focused, not Elixir integration tests

---

## Test Categories to Import

### ⭐ HIGH PRIORITY - Core Functionality

#### 1. **SQL Fragment & Type Tests** (from ecto_sql/integration_test/sql/sql.exs)
**Why**: Tests edge cases in type conversion, fragment handling, and SQL generation that SQLite may handle differently than PG/MySQL

**Key Tests to Port**:
- Fragment types with different operators
- Type casting for integers, strings, binaries
- Array/collection handling (JSON alternatives for SQLite)
- Dynamic parameter binding edge cases
- Schema-less queries

**Effort**: 🟢 Low - Tests are DB-agnostic at the query level

**Location to Add**: `test/ecto_sql_compatibility_test.exs`

---

#### 2. **Transaction Semantics** (from ecto_sql/integration_test/sql/transaction.exs)
**Why**: Transaction behavior (nesting, rollback, savepoints) differs between databases; LibSQL has specific transaction modes

**Key Tests to Port**:
- Nested transaction handling (`transaction` within `transaction`)
- Rollback behavior and state cleanup
- Error handling during transactions
- In-transaction? checks
- Multi-step transaction sequences
- Savepoint semantics (SQLite native feature)

**Effort**: 🟡 Medium - Some LibSQL-specific behavior (DEFERRED, IMMEDIATE, EXCLUSIVE modes)

**Location to Add**: `test/ecto_sql_transaction_compat_test.exs`

**Adaptation Notes**:
- SQLite transactions use BEGIN [DEFERRED|IMMEDIATE|EXCLUSIVE]
- Savepoints are SAVE POINT instead of nested transactions
- Connection mode (replica sync) affects transaction behavior

---

#### 3. **Migration Execution** (from ecto_sql/integration_test/sql/migration.exs)
**Why**: Migrations must work reliably; SQLite has different ALTER TABLE capabilities

**Key Tests to Port**:
- Table creation with various column types
- Index creation and usage
- Column addition
- Constraint handling
- Migration rollback/forward sequences
- Schema versioning (PRAGMA user_version)

**Effort**: 🟡 Medium - SQLite ALTER TABLE limitations

**Location to Add**: `test/ecto_migration_compat_test.exs`

**Adaptation Notes**:
- SQLite can't ALTER TABLE MODIFY or DROP COLUMN (< 3.35)
- Workarounds in AGENTS.md should be tested
- Replica sync may affect migration safety

---

#### 4. **Streaming & Cursor Operations** (from ecto_sql/integration_test/sql/stream.exs)
**Why**: Large result set handling critical for memory efficiency

**Key Tests to Port**:
- DBConnection.stream/3 usage
- Chunk boundary handling
- Cursor lifecycle (open, fetch, close)
- Memory efficiency with large datasets
- Stream termination and cleanup

**Effort**: 🟢 Low - Mostly portable, DBConnection-level

**Location to Add**: `test/ecto_stream_compat_test.exs`

---

### 🟡 MEDIUM PRIORITY - Adapter-Specific

#### 5. **Prepared Statement Features** (from ecto_sql/integration_test/pg/prepare_test.exs)
**Why**: LibSQL has unique caching behavior (automatic after v0.7.0)

**Key Tests to Port**:
- Statement parameter count introspection
- Column count and name introspection
- Statement reuse performance
- Parameter binding edge cases
- Prepared statement lifecycle

**Effort**: 🟡 Medium - Our caching is unique

**Location to Add**: `test/ecto_prepared_stmt_advanced_test.exs`

**Adaptation Notes**:
- Auto-reset of bindings in v0.7.0 is our feature
- Need to test introspection functions (stmt_parameter_count, etc.)

---

#### 6. **Constraint Handling** (from ecto_sql/integration_test/pg/constraints_test.exs)
**Why**: SQLite constraint behavior differs (less strict by default)

**Key Tests to Port**:
- Foreign key constraint enforcement
- Unique constraint violations
- Check constraint handling
- On conflict/replace strategies
- Constraint error messages

**Effort**: 🟡 Medium - SQLite constraint semantics differ

**Location to Add**: `test/ecto_constraint_compat_test.exs`

**Adaptation Notes**:
- Foreign keys require `PRAGMA foreign_keys = ON`
- UPSERT syntax differs
- Conflict resolution strategies available in LibSQL

---

### 🔵 LOWER PRIORITY - Ecto Core Concepts

#### 7. **Schemaless Queries** (from ecto/test/ecto/repo_test.exs)
**Why**: Test schemaless `Repo.all(from p in "table_name", ...)` patterns

**Effort**: 🟢 Low - Database-agnostic

---

#### 8. **Exception Handling** (from ecto_sql/integration_test/pg/exceptions_test.exs)
**Why**: Verify error messages and recovery

**Effort**: 🟡 Medium - SQLite exception formats differ

---

## Implementation Roadmap

### Phase 1: Core Compatibility Tests (Week 1)
- [ ] Create `ecto_sql_compatibility_test.exs` with fragment/type tests
- [ ] Create `ecto_sql_transaction_compat_test.exs` with transaction semantics
- [ ] Create `ecto_stream_compat_test.exs` with streaming tests
- [ ] Run and fix failures

### Phase 2: Adapter-Specific Features (Week 2)
- [ ] Create `ecto_prepared_stmt_advanced_test.exs` with introspection tests
- [ ] Create `ecto_constraint_compat_test.exs` with constraint tests
- [ ] Create `ecto_migration_compat_test.exs` with migration edge cases

### Phase 3: Integration & Edge Cases (Week 3)
- [ ] Verify all tests pass in local, remote, and replica modes
- [ ] Test with actual Turso connections
- [ ] Document any SQLite limitations in failing tests

### Phase 4: Documentation (Week 4)
- [ ] Create compatibility matrix: ecto_sql vs ecto_libsql
- [ ] Document expected differences and workarounds
- [ ] Add to AGENTS.md

---

## Files to Import and Adapt

| Source | Files | Adapts to | Effort |
|--------|-------|----------|--------|
| ecto_sql/integration_test/sql/ | `sql.exs` | `test/ecto_sql_compatibility_test.exs` | 🟢 Low |
| ecto_sql/integration_test/sql/ | `transaction.exs` | `test/ecto_sql_transaction_compat_test.exs` | 🟡 Med |
| ecto_sql/integration_test/sql/ | `stream.exs` | `test/ecto_stream_compat_test.exs` | 🟢 Low |
| ecto_sql/integration_test/sql/ | `migration.exs` | `test/ecto_migration_compat_test.exs` | 🟡 Med |
| ecto_sql/integration_test/pg/ | `prepare_test.exs` | `test/ecto_prepared_stmt_advanced_test.exs` | 🟡 Med |
| ecto_sql/integration_test/pg/ | `constraints_test.exs` | `test/ecto_constraint_compat_test.exs` | 🟡 Med |
| ecto_sql/integration_test/pg/ | `exceptions_test.exs` | Update `test/error_handling_test.exs` | 🟡 Med |

---

## Key Adaptations Required

### For All Tests
1. **Database Module Import**
   - Replace `Ecto.Integration.TestRepo` with test repo setup
   - Handle local vs remote connections

2. **Schema Definitions**
   - May need to adjust for SQLite type limitations
   - Test generic Post/User schemas (already in our fixtures)

3. **Tags/Async**
   - Some tests marked with `@tag` for database-specific features
   - Add SQLite-specific tags (`:sqlite_only`, `:replica_mode`, etc.)

### For Transaction Tests
- Add LibSQL transaction behavior modes (DEFERRED, IMMEDIATE, EXCLUSIVE)
- Test replica sync behavior during transactions

### For Migration Tests
- Skip ALTER TABLE MODIFY/DROP tests with explanatory notes
- Test PRAGMA user_version for schema versioning

### For Streaming Tests
- Test with large record sets (100K+)
- Verify memory usage stays constant

### For Prepared Statement Tests
- Test our auto-reset behavior
- Test statement introspection (new in v0.7.0)
- Benchmark cached vs uncached execution

---

## Benefits

1. **Comprehensive Coverage**: Cover edge cases that other adapters found
2. **Compatibility Assurance**: Prove ecto_libsql behaves like other Ecto adapters
3. **Regression Prevention**: Catch inadvertent breaking changes
4. **Documentation**: Tests serve as executable specifications
5. **Performance Baselines**: Benchmark against other adapters

---

## Success Criteria

- ✅ All ported tests pass in local mode
- ✅ All ported tests pass in remote mode (with Turso)
- ✅ All ported tests pass in replica mode
- ✅ Documentation clearly marks expected differences
- ✅ Test suite > 10,000 lines total
- ✅ 95%+ code path coverage for adapter
