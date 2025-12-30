# LibSQL Feature Implementation Checklist

Quick reference for tracking implementation status of libSQL Rust API features.

---

## Legend

- ✅ **Implemented & Well-Tested**
- ⚠️ **Implemented but Needs Better Tests**
- ❌ **Not Implemented**
- 🔒 **Explicitly Unsupported** (documented reason)

---

## Connection Methods

| Feature | Status | NIF | Tests |
|---------|--------|-----|-------|
| `execute()` | ✅ | `query_args` | ✅ |
| `query()` | ✅ | `query_args` | ✅ |
| `prepare()` | ✅ | `prepare_statement` | ✅ |
| `transaction()` | ✅ | `begin_transaction` | ✅ |
| `transaction_with_behavior()` | ✅ | `begin_transaction_with_behavior` | ✅ |
| `execute_batch()` | ✅ | `execute_batch`, `execute_batch_native` | ✅ |
| `execute_transactional_batch()` | ✅ | `execute_transactional_batch`, `execute_transactional_batch_native` | ✅ |
| `reset()` | ⚠️ | `reset_connection` | ⚠️ Basic only |
| `interrupt()` | ⚠️ | `interrupt_connection` | ⚠️ Basic only |
| `busy_timeout()` | ✅ | `set_busy_timeout` | ✅ |
| `is_autocommit()` | ✅ | `is_autocommit` | ✅ |
| `changes()` | ✅ | `changes` | ✅ |
| `total_changes()` | ✅ | `total_changes` | ✅ |
| `last_insert_rowid()` | ✅ | `last_insert_rowid` | ✅ |
| `get_reserved_bytes()` | ❌ | - | - |
| `set_reserved_bytes()` | ❌ | - | - |
| `load_extension_enable()` | ❌ | - | - |
| `load_extension_disable()` | ❌ | - | - |
| `load_extension()` | ❌ | - | - |
| `authorizer()` | ❌ | - | - |
| `add_update_hook()` | ❌ | - | - |

---

## Transaction Methods

| Feature | Status | NIF | Tests |
|---------|--------|-----|-------|
| `commit()` | ✅ | `commit_or_rollback_transaction` | ✅ |
| `rollback()` | ✅ | `commit_or_rollback_transaction` | ✅ |
| Execute in transaction | ✅ | `execute_with_transaction` | ✅ |
| Query in transaction | ✅ | `query_with_trx_args` | ✅ |
| Savepoints | ✅ | `savepoint`, `release_savepoint`, `rollback_to_savepoint` | ✅ |

---

## Prepared Statement Methods

| Feature | Status | NIF | Tests |
|---------|--------|-----|-------|
| `execute()` | ✅ | `execute_prepared` | ✅ |
| `query()` | ✅ | `query_prepared` | ✅ |
| `run()` | ⚠️ | Implicit via execute/query | ⚠️ |
| `query_row()` | ❌ | - | - |
| `reset()` | ✅ | Automatic in execute/query | ✅ |
| `finalize()` | ✅ | `close` | ✅ |
| `interrupt()` | ❌ | - | - |
| `parameter_count()` | ⚠️ | `statement_parameter_count` | ⚠️ Basic |
| `parameter_name()` | ❌ | - | - |
| `column_count()` | ⚠️ | `statement_column_count` | ⚠️ Basic |
| `columns()` | ⚠️ | `statement_column_name` | ⚠️ Basic |

---

## Database/Replication Methods

| Feature | Status | NIF | Tests |
|---------|--------|-----|-------|
| `sync()` | ✅ | `do_sync` | ✅ |
| `sync_until()` | ⚠️ | `sync_until` | ⚠️ Placeholder |
| `sync_frames()` | ❌ | - | - |
| `flush_replicator()` | ⚠️ | `flush_replicator` | ⚠️ Placeholder |
| `replication_index()` | ⚠️ | `get_frame_number` | ⚠️ Basic |
| `max_write_replication_index()` | ⚠️ | `max_write_replication_index` | ⚠️ Basic |
| `freeze()` | 🔒 | `freeze_database` (returns `:unsupported`) | ✅ |

---

## Cursor Methods

| Feature | Status | NIF | Tests |
|---------|--------|-----|-------|
| Declare cursor | ✅ | `declare_cursor`, `declare_cursor_with_context` | ✅ |
| Fetch cursor | ✅ | `fetch_cursor` | ✅ |
| Deallocate cursor | ✅ | `close` | ✅ |

---

## Special Features

| Feature | Status | NIF | Tests |
|---------|--------|-----|-------|
| PRAGMA queries | ✅ | `pragma_query` | ✅ |
| Vector search | ✅ | `vector`, `vector_type`, `vector_distance_cos` | ✅ |
| Database encryption | ✅ | Via `connect` options | ✅ |
| Custom connection ping | ✅ | `ping` | ✅ |

---

## Connection Types

| Type | Status | Config | Tests |
|------|--------|--------|-------|
| Local database | ✅ | `database: "file.db"` | ✅ |
| In-memory database | ✅ | `database: ":memory:"` | ✅ |
| Remote (Turso) | ✅ | `uri` + `auth_token` | ✅ |
| Embedded replica | ✅ | `database` + `uri` + `auth_token` + `sync: true` | ✅ |

---

## Security Features (ecto_libsql specific)

| Feature | Status | Implementation | Tests |
|---------|--------|----------------|-------|
| Transaction ownership | ✅ | `TransactionEntry.conn_id` | ✅ |
| Statement ownership | ✅ | Ownership validation | ✅ |
| Cursor ownership | ✅ | `CursorData.conn_id` | ✅ |
| Savepoint ownership | ✅ | Validation in savepoint NIFs | ✅ |

---

## Implementation Priorities

### High Priority (Should Implement)

1. ❌ **Named parameters** (`parameter_name()`)
   - LibSQL supports `:name`, `@name`, `$name` syntax
   - Would improve developer experience
   - Tests already exist (marked `:skip`)

2. ⚠️ **Replication test coverage**
   - Features implemented but minimally tested
   - Critical for Turso use cases

3. ⚠️ **Statement introspection edge cases**
   - Features implemented but only happy path tested
   - Important for tooling/debugging

### Medium Priority (Nice to Have)

4. ❌ **Extension loading**
   - `load_extension_enable()`, `load_extension_disable()`, `load_extension()`
   - Useful for FTS5, JSON1, etc.
   - Security concerns require careful implementation

5. ❌ **Authoriser hooks**
   - Row-level security
   - Advanced multi-tenant use cases

6. ❌ **Update hooks**
   - Change data capture
   - Auditing and event sourcing

### Low Priority (Can Defer)

7. ❌ **Reserved bytes**
   - Local-only feature
   - Not critical for Turso

8. ❌ **Statement-level interrupt**
   - Connection-level interrupt covers most cases

9. ❌ **`query_row()` convenience**
   - Users can call `query()` and take first row

---

## Test Coverage Priorities

### Critical (Add Immediately)

1. ⚠️ **Replication integration tests** (`test/replication_integration_test.exs`)
   - `sync_until()` - frame-specific sync
   - `flush_replicator()` - force pending writes
   - `max_write_replication_index()` - write tracking
   - `replication_index()` - current frame tracking

### High (Add Soon)

2. ⚠️ **Statement introspection edge cases** (`test/statement_features_test.exs`)
   - Parameter count with 0, many, duplicate parameters
   - Column count for SELECT *, JOINs, aggregates
   - Column names with aliases, expressions, computed columns

3. ⚠️ **Connection reset/interrupt functional tests** (`test/connection_features_test.exs`)
   - Reset maintains prepared statements
   - Reset doesn't close transactions
   - Interrupt cancels long queries
   - Interrupt doesn't affect other connections

### Medium (Nice to Have)

4. ⚠️ **Cursor concurrent access** (`test/ecto_integration_test.exs`)
   - Multiple processes can't share cursor
   - Cursor cleanup on connection close

5. ⚠️ **Transaction ownership edge cases** (`test/security_test.exs`)
   - Cross-process transaction security
   - Cleanup on abnormal termination

### Low (Optional)

6. ⚠️ **Performance benchmarks** (`test/performance_test.exs`)
   - Cursor streaming at scale
   - Statement cache performance
   - Concurrent connection stress tests

---

## Quick Stats

**Total libSQL Features**: 62
- ✅ Fully Implemented: 38 (61%)
- ⚠️ Partial/Needs Tests: 6 (10%)
- ❌ Not Implemented: 18 (29%)

**Test Coverage**:
- ✅ Excellent: ~70% of implemented features
- ⚠️ Good/Basic: ~20% of implemented features
- ⚠️ Limited/None: ~10% of implemented features

**Files Modified for Gaps**:
- NEW: `test/replication_integration_test.exs`
- EXPAND: `test/statement_features_test.exs`
- EXPAND: `test/connection_features_test.exs`
- EXPAND: `test/ecto_integration_test.exs`
- EXPAND: `test/security_test.exs`
- EXPAND: `test/error_handling_test.exs`
- NEW (optional): `test/performance_test.exs`

---

## Next Steps

1. ✅ Review feature comparison matrix
2. ✅ Prioritise test coverage gaps
3. ⚠️ Implement replication integration tests (highest priority)
4. ⚠️ Add statement introspection edge cases
5. ⚠️ Expand connection reset/interrupt tests
6. ❌ Consider implementing named parameters
7. ❌ Consider extension loading support
