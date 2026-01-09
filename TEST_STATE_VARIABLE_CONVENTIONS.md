# Test State Variable Naming Conventions

## Overview

This document standardizes variable naming patterns for state threading in ecto_libsql tests, particularly when handling error cases that return updated state.

## Context

The ecto_libsql library uses a stateful API where operations return tuples like:
- `{:ok, query, result, new_state}` 
- `{:error, reason, new_state}`

Even when an operation fails, the returned state may be updated (e.g., transaction state after constraint violation). Tests need a clear convention for managing this state threading.

## Pattern: Error Cases with State Recovery

### When to Rebind vs. Discard

**Case 1: Error state is NOT needed for subsequent operations** → Discard with `_state`

```elixir
# savepoint_test.exs line 342 (original test)
result = EctoLibSql.handle_execute(sql, params, [], trx_state)
assert {:error, _reason, _state} = result

# Rollback uses the ORIGINAL trx_state, not the error state
:ok = Native.rollback_to_savepoint_by_name(trx_state, "sp1")
```

**Case 2: Error state IS needed for subsequent operations** → Rebind to reuse variable name

```elixir
# savepoint_replication_test.exs line 221 (replication test)
result = EctoLibSql.handle_execute(sql, params, [], trx_state)
assert {:error, _reason, trx_state} = result

# Next operation MUST use the updated trx_state
:ok = Native.rollback_to_savepoint_by_name(trx_state, "sp1")
```

### Why the Difference?

The **original savepoint_test.exs** doesn't need the error state because:
- The failed INSERT doesn't change the transaction state in a way that matters
- The rollback uses the original `trx_state` successfully

The **replication_test.exs** DOES need the error state because:
- The error state contains updated replication metadata
- Subsequent operations in the same transaction require the updated state
- Using the old state could cause sync inconsistencies

## Recommended Convention

### 1. Variable Naming

Use consistent names based on scope:

| Scope | Pattern | Example |
|-------|---------|---------|
| Connection scope | `state` | `{:ok, state} = EctoLibSql.connect(opts)` |
| Transaction scope | `trx_state` | `{:ok, trx_state} = EctoLibSql.Native.begin(state)` |
| Cursor scope | `cursor` | `{:ok, _query, cursor, state} = EctoLibSql.handle_declare(...)` |
| Prepared stmt scope | `stmt` or `stmt_id` | `{:ok, stmt} = EctoLibSql.Native.prepare(...)` |

### 2. Error Handling Pattern

**For error cases where state continues to be used:**

```elixir
# ✅ GOOD: Clear that the error state will be reused
result = EctoLibSql.handle_execute(sql, params, [], trx_state)
assert {:error, _reason, trx_state} = result  # Rebind - state is needed next

# Continue using trx_state
:ok = EctoLibSql.Native.rollback_to_savepoint_by_name(trx_state, "sp1")
```

**For error cases where state is terminal:**

```elixir
# ✅ GOOD: Clear that the error state is discarded
result = EctoLibSql.handle_execute(sql, params, [], conn)
assert {:error, %EctoLibSql.Error{}, _conn} = result  # Discard - not needed again
```

**Alternative: Use intermediate variable (more explicit but verbose)**

```elixir
# ✅ ALTERNATIVE: If clarity is critical, use different variable
result = EctoLibSql.handle_execute(sql, params, [], trx_state)
assert {:error, _reason, updated_trx_state} = result

# Now it's explicit that the state was updated
:ok = EctoLibSql.Native.rollback_to_savepoint_by_name(updated_trx_state, "sp1")
```

### 3. Comments for Clarity

When using the rebinding pattern, add a comment explaining why:

```elixir
# Try to insert duplicate (will fail)
result = EctoLibSql.handle_execute(
  "INSERT INTO #{table} (id, name) VALUES (?, ?)",
  [100, "Duplicate"],
  [],
  trx_state
)

# Rebind trx_state - error state is needed for subsequent savepoint operations
assert {:error, _reason, trx_state} = result

# Use updated state for recovery
:ok = EctoLibSql.Native.rollback_to_savepoint_by_name(trx_state, "sp1")
```

## Current Issues Found

### savepoint_replication_test.exs (Line 221)

**Current:**
```elixir
assert {:error, _reason, trx_state} = result
```

**Status:** ✅ CORRECT - State is reused on lines 224, 227, 236
**Enhancement:** Add comment explaining why state is rebound:

```elixir
# Rebind trx_state - error state maintains transaction context for recovery
assert {:error, _reason, trx_state} = result
```

### savepoint_test.exs (Line 342)

**Current:**
```elixir
assert {:error, _reason, _state} = result
```

**Status:** ✅ CORRECT - Original trx_state is used on line 345
**Rationale:** The error state isn't needed since rollback uses original trx_state

## Implementation Checklist

When fixing tests:
- [ ] Verify if the error state is actually needed for subsequent operations
- [ ] Use `_state` if it's not needed (clear intent of discarding)
- [ ] Rebind to same variable name if it IS needed (minimal diff)
- [ ] Add comment if rebinding to explain why
- [ ] Use `updated_state` pattern ONLY if clarity is critical for complex logic

## Pattern Summary

```
Error Operation
    ↓
├─ Is state used next?
│  ├─ YES → Rebind variable (with comment explaining why)
│  └─ NO → Use _state to discard
```

## Examples from Codebase

### ✅ Correct Pattern: Discard Unused

```elixir
# pool_load_test.exs line 222
assert {:error, _reason, ^state} = error_result
# Uses original state, error state not needed
```

### ✅ Correct Pattern: Rebind and Use

```elixir
# savepoint_replication_test.exs line 221-224
assert {:error, _reason, trx_state} = result
:ok = EctoLibSql.Native.rollback_to_savepoint_by_name(trx_state, "sp1")
```

### ✅ Correct Pattern: Discarded in Terminal Operations

```elixir
# smoke_test.exs line 73
assert {:error, %EctoLibSql.Error{}, _conn} = EctoLibSql.handle_execute(...)
# Error is terminal, state not used again
```

## References

- **NIF State Semantics:** Error tuples always return updated state, even on failure
- **State Threading:** Elixir convention is to thread updated state through all operations
- **Variable Shadowing:** Rebinding same variable name is idiomatic Elixir for state threading
