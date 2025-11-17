# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2025-11-17

### Added

- **Full Ecto Adapter Support** - LibSqlEx now provides a complete Ecto adapter implementation
  - `Ecto.Adapters.LibSqlEx` - Main adapter module implementing Ecto.Adapter.Storage and Ecto.Adapter.Structure
  - `Ecto.Adapters.LibSqlEx.Connection` - SQL query generation and DDL support for SQLite/libSQL
  - Full support for Ecto schemas, changesets, and migrations
  - Phoenix integration support
  - Type loaders and dumpers for proper Ecto type conversion
  - Storage operations (create, drop, status)
  - Structure operations (dump, load) using sqlite3
  - Migration support with standard Ecto.Migration features:
    - CREATE/DROP TABLE with IF (NOT) EXISTS
    - ALTER TABLE for adding columns and renaming
    - CREATE/DROP INDEX with UNIQUE and partial index support
    - Proper constraint conversion (UNIQUE, FOREIGN KEY, CHECK)
  - Comprehensive test suite for adapter and connection modules

- **Documentation and Examples**
  - `examples/ecto_example.exs` - Complete Ecto usage examples
  - `ECTO_MIGRATION_GUIDE.md` - Comprehensive migration guide from PostgreSQL/MySQL
  - Updated README with extensive Ecto integration documentation
  - Phoenix integration guide
  - Production deployment best practices

### Changed

- Updated `mix.exs` to include `ecto` and `ecto_sql` dependencies
- Bumped version from 0.2.0 to 0.3.0 to reflect major feature addition

### Notes

This release makes LibSqlEx a full-featured Ecto adapter, bringing it on par with other database adapters in the Elixir ecosystem. Users can now:

- Use LibSqlEx in Phoenix applications
- Define Ecto schemas and run migrations
- Leverage all Ecto.Query features
- Benefit from Turso's remote replica mode with Ecto
- Migrate existing applications from PostgreSQL/MySQL to LibSqlEx

The adapter supports all three connection modes:
1. Local SQLite databases
2. Remote-only Turso connections
3. Remote replica mode (local + cloud sync)

### Breaking Changes

None - this is purely additive functionality.

### Known Limitations

SQLite/libSQL has some limitations compared to PostgreSQL:
- No ALTER COLUMN support (column type modifications require table recreation)
- No DROP COLUMN on older SQLite versions (< 3.35.0)
- No native array types (use JSON or separate tables)
- No native UUID type (stored as TEXT, works with Ecto.UUID)

These are SQLite limitations, not LibSqlEx limitations, and are well-documented in the migration guide.

## [0.2.0] - Previous Release

### Added

- DBConnection protocol implementation
- Local, Remote, and Remote Replica modes
- Transaction support with multiple isolation levels
- Prepared statements
- Batch operations
- Cursor support for large result sets
- Vector search support
- Encryption support (AES-256-CBC)
- WebSocket protocol support
- Metadata methods (last_insert_rowid, changes, etc.)

## [0.1.0] - Initial Release

### Added

- Basic LibSQL/Turso connection support
- Rust NIF implementation
- Query execution
- Basic transaction support
