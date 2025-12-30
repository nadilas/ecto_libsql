further-enhancements-put-into-beads

Excellent! I've completed a thorough exploration of both the libSQL and Ecto codebases. Here are additional features not currently in ENHANCEMENTS.md that would be valuable additions to ecto_libsql:

  🎯 NEW FEATURES TO CONSIDER

  1. CTE (Common Table Expression) Support ⭐ HIGH PRIORITY

  Status: Ecto query builder generates CTEs, but ecto_libsql's connection module doesn't emit WITH clauses

  Why Important:
  - Critical for complex queries and recursive data structures
  - Standard SQL feature widely used in other Ecto adapters
  - SQLite has supported CTEs since version 3.8.3 (2014)

  Implementation: Update lib/ecto/adapters/libsql/connection.ex:441 in the all/1 function to emit WITH clauses

  Effort: 3-4 days

  ---
  2. UPSERT Support (INSERT ... ON CONFLICT) ⭐ HIGH PRIORITY

  Status: ❌ Not implemented
  SQLite Version: 3.24+ (2018)

  Why Important:
  - Common pattern for idempotent inserts
  - Better performance than SELECT + INSERT/UPDATE
  - Standard in other Ecto adapters (Postgres has this)

  Desired API:
  # Ecto-style upsert
  Repo.insert(changeset,
    on_conflict: :replace_all,
    conflict_target: [:email]
  )

  # Or with specific fields
  Repo.insert(changeset,
    on_conflict: {:replace, [:name, :updated_at]},
    conflict_target: [:email]
  )

  Effort: 4-5 days

  ---
  3. Generated/Computed Columns ⭐ MEDIUM PRIORITY

  Status: ❌ Not supported in migrations
  SQLite Version: 3.31+ (2020)

  Why Important:
  - Automatic computed values (no triggers needed)
  - Better data consistency
  - Performance optimisation for derived values

  Desired API:
  create table(:users) do
    add :first_name, :string
    add :last_name, :string
    add :full_name, :string,
      generated: "first_name || ' ' || last_name",
      stored: true  # or virtual
  end

  Effort: 3-4 days

  ---
  4. STRICT Tables (Type Enforcement) ⭐ MEDIUM PRIORITY

  Status: ❌ Not supported
  SQLite Version: 3.37+ (2021)

  Why Important:
  - Enforces type constraints (SQLite normally allows any type in any column!)
  - Catches bugs earlier
  - Better data integrity

  Desired API:
  create table(:users, strict: true) do
    add :id, :integer, primary_key: true
    add :name, :string  # Now MUST be text, not integer!
  end

  Effort: 2-3 days

  ---
  5. Full-Text Search (FTS5) Schema Integration ⭐ MEDIUM PRIORITY

  Status: ⚠️ Partial - Extension loading works, but no schema helpers

  Why Important:
  - FTS5 is powerful but awkward to use with raw SQL
  - Schema DSL would make it first-class
  - Common requirement for content-heavy apps

  Desired API:
  create table(:posts, fts5: true) do
    add :title, :text, fts_weight: 10
    add :body, :text
    add :author, :string, fts_indexed: false
  end

  # Query
  from p in Post,
    where: fragment("posts MATCH ?", "search terms"),
    order_by: [desc: fragment("rank")]

  Effort: 5-7 days

  ---
  6. JSON Schema Helpers ⭐ MEDIUM PRIORITY

  Status: ⚠️ Works via fragments, but no dedicated support

  Why Important:
  - JSON1 extension is powerful but verbose
  - Better integration with Ecto types
  - Common pattern in modern apps

  Desired API:
  # In schema
  schema "users" do
    field :metadata, :map  # Already works
    field :settings, EctoLibSql.Types.JSON  # New: with JSON operators
  end

  # In query with helpers
  from u in User,
    where: json_extract(u.settings, "$.theme") == "dark",
    select: {u.id, json_object(u.metadata)}

  Effort: 4-5 days

  ---
  7. R*Tree Spatial Indexing Support ⭐ LOW-MEDIUM PRIORITY

  Status: ❌ Not implemented

  Why Important:
  - Complement to vector search for geospatial queries
  - Multi-dimensional range queries
  - Better than vector search for pure location data

  Use Cases:
  - Geographic bounds queries
  - Collision detection
  - Time-range queries (2D: time + value)

  Desired API:
  create table(:locations, rtree: true) do
    add :min_lat, :float
    add :max_lat, :float
    add :min_lng, :float
    add :max_lng, :float
  end

  # Query locations within bounds
  from l in Location,
    where: rtree_intersects(l, ^bounds)

  Effort: 5-6 days

  ---
  8. EXPLAIN Query Support ⭐ MEDIUM PRIORITY

  Status: ❌ Not implemented

  Why Important:
  - Performance debugging
  - Query optimisation
  - Index usage validation

  Desired API:
  # Explain a query
  query = from u in User, where: u.age > 18
  {:ok, plan} = Repo.explain(query)

  # Or with Ecto.Adapters.SQL
  Ecto.Adapters.SQL.explain(Repo, :all, query)

  Effort: 2-3 days

  ---
  9. ANALYZE Statistics Collection ⭐ LOW PRIORITY

  Status: ❌ Not exposed

  Why Important:
  - Better query planning
  - Automatic index selection
  - Performance optimisation

  Desired API:
  # Manual ANALYZE
  EctoLibSql.Native.analyze(state)
  EctoLibSql.Native.analyze_table(state, "users")

  # Auto-analyze on migration
  config :my_app, MyApp.Repo,
    auto_analyze: true  # Run ANALYZE after migrations

  Effort: 2 days

  ---
  10. Partial Index Support in Migrations ⭐ MEDIUM PRIORITY

  Status: ⚠️ SQLite supports, but Ecto DSL doesn't

  Why Important:
  - Index only subset of rows
  - Smaller, faster indexes
  - Better for conditional uniqueness

  Desired API:
  create index(:users, [:email],
    unique: true,
    where: "deleted_at IS NULL"
  )

  Effort: 2-3 days

  ---
  11. Expression Indexes ⭐ LOW-MEDIUM PRIORITY

  Status: ⚠️ SQLite supports, but awkward in Ecto

  Why Important:
  - Index computed values
  - Case-insensitive searches
  - JSON field indexing

  Desired API:
  create index(:users, [],
    expression: "LOWER(email)",
    unique: true
  )

  # Or via fragment
  create index(:users, [fragment("json_extract(metadata, '$.status')")])

  Effort: 3 days

  ---
  12. Better CHECK Constraint Support ⭐ LOW PRIORITY

  Status: ⚠️ Basic support only

  Why Important:
  - Data validation at database level
  - Enforces invariants
  - Complements Ecto changesets

  Desired API:
  create table(:users) do
    add :age, :integer, check: "age >= 0 AND age <= 150"
    add :status, :string, check: "status IN ('active', 'inactive', 'banned')"
  end

  # Or named constraints
  create constraint(:users, :valid_age, check: "age >= 0")

  Effort: 2-3 days

  ---
  13. Better Collation Support ⭐ LOW PRIORITY

  Status: ⚠️ Works via fragments

  Why Important:
  - Locale-specific sorting
  - Case-insensitive comparisons
  - Unicode handling

  Desired API:
  # In schema
  field :name, :string, collation: :nocase

  # In query
  from u in User, order_by: [asc: fragment("name COLLATE NOCASE")]

  # In migration
  add :name, :string, collation: "BINARY"

  Effort: 2 days

  ---
  14. Table-Valued Functions (via Extensions) ⭐ LOW PRIORITY

  Status: ❌ Not implemented

  Why Important:
  - Generate rows from functions
  - Series generation
  - CSV parsing

  Example:
  # Generate series
  from s in fragment("generate_series(1, 10)"),
    select: s.value

  # CSV parsing
  from c in fragment("csv_table(?, ?)", path, schema),
    select: c

  Effort: 4-5 days (if building custom extension)

  ---
  15. RETURNING Enhancement for Batch Operations ⭐ MEDIUM PRIORITY

  Status: ⚠️ Works for single operations, not batches

  Why Important:
  - Get IDs from bulk inserts
  - Audit changes from bulk updates
  - Better integration with Ecto.Multi

  Desired API:
  {count, rows} = Repo.insert_all(User, users, returning: [:id, :inserted_at])
  # Returns all inserted rows with IDs

  Effort: 3-4 days

  ---
  📊 PRIORITY SUMMARY

  | Priority | Features                                                                              | Total Effort |
  |----------|---------------------------------------------------------------------------------------|--------------|
  | HIGH     | CTE support, UPSERT, RETURNING for batches                                            | 10-13 days   |
  | MEDIUM   | Generated columns, STRICT tables, FTS5 schema, JSON helpers, Partial indexes, EXPLAIN | 18-25 days   |
  | LOW      | R*Tree, ANALYZE, Expression indexes, CHECK constraints, Collations, Table functions   | 15-22 days   |

  Total Estimated Effort: ~43-60 days

  ---
  🎯 RECOMMENDED IMPLEMENTATION ORDER

  1. CTE Support (3-4 days) - Fills major gap, high user demand
  2. UPSERT (4-5 days) - Common pattern, high value
  3. EXPLAIN Support (2-3 days) - Quick win for debugging
  4. Generated Columns (3-4 days) - Modern SQLite feature
  5. STRICT Tables (2-3 days) - Better type safety
  6. JSON Helpers (4-5 days) - Common requirement
  7. FTS5 Schema Integration (5-7 days) - Major feature
  8. Partial Indexes (2-3 days) - Performance optimisation
  9. RETURNING for Batches (3-4 days) - Better batch operations
  10. Everything else as needed

  ---
  📝 NOTES

  - Most features require Elixir-side changes (migration DSL, query builder) rather than Rust NIF changes
  - Many features are already supported by SQLite but need Ecto integration
  - Some features (like CTEs) are parsed by Ecto but not emitted by ecto_libsql's SQL generator
  - These features would bring ecto_libsql closer to Postgres/MySQL adapter feature parity while respecting SQLite's limitations

  Would you like me to create detailed implementation plans for any of these features, or add them to the ENHANCEMENTS.md file?