# Migrating to LibSqlEx Ecto Adapter

This guide helps you migrate your Ecto-based application from other databases (PostgreSQL, MySQL, etc.) to LibSqlEx.

## Quick Start Migration

### 1. Update Dependencies

Replace your existing database adapter with LibSqlEx:

```elixir
# mix.exs
def deps do
  [
    # Remove/comment out old adapter
    # {:postgrex, ">= 0.0.0"},
    # {:myxql, ">= 0.0.0"},

    # Add LibSqlEx
    {:libsqlex, "~> 0.2.0"},
    {:ecto_sql, "~> 3.11"}
  ]
end
```

### 2. Update Configuration

Update your repo configuration:

```elixir
# config/dev.exs
config :my_app, MyApp.Repo,
  # Old PostgreSQL config:
  # adapter: Ecto.Adapters.Postgres,
  # username: "postgres",
  # password: "postgres",
  # hostname: "localhost",
  # database: "my_app_dev",

  # New LibSqlEx config:
  adapter: Ecto.Adapters.LibSql,
  database: "my_app_dev.db"
```

### 3. Update Your Repo Module

The repo module itself doesn't need changes:

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.LibSql  # Just update this line
end
```

### 4. Recreate Your Database

```bash
mix ecto.drop          # Drop old database (if migrating from local DB)
mix ecto.create        # Create new SQLite database
mix ecto.migrate       # Run migrations
```

## Schema Compatibility

Most Ecto schemas work without changes. Here are the common differences:

### Types Mapping

| PostgreSQL/MySQL | LibSqlEx/SQLite | Notes |
|-----------------|-----------------|-------|
| `uuid` | `:binary_id` or `:string` | Stored as TEXT |
| `text` | `:text` | ✅ Works the same |
| `integer` | `:integer` | ✅ Works the same |
| `bigint` | `:integer` | SQLite uses dynamic typing |
| `varchar(N)` | `:string` | Size hints ignored in SQLite |
| `decimal` | `:decimal` | ✅ Works the same |
| `boolean` | `:boolean` | Stored as 0/1 integer |
| `timestamp` | `:naive_datetime` | ✅ Works the same |
| `timestamptz` | `:utc_datetime` | Stored as ISO8601 string |
| `array` | ❌ Not supported | Use JSON or separate tables |
| `jsonb` | `:map` or `:string` | Store as JSON text |

### Schema Example

Most schemas work as-is:

```elixir
defmodule MyApp.User do
  use Ecto.Schema

  schema "users" do
    field :email, :string              # ✅ Works
    field :name, :string               # ✅ Works
    field :age, :integer               # ✅ Works
    field :balance, :decimal           # ✅ Works
    field :active, :boolean            # ✅ Works (stored as 0/1)
    field :metadata, :map              # ✅ Works (stored as JSON)
    field :inserted_at, :naive_datetime # ✅ Works

    # If you were using UUIDs:
    # field :external_id, :uuid         # Change to:
    field :external_id, :binary_id     # ✅ Works (stored as TEXT)

    timestamps()
  end
end
```

### Arrays → JSON

If you were using PostgreSQL arrays, convert to JSON:

```elixir
# Old PostgreSQL schema:
schema "posts" do
  field :tags, {:array, :string}
end

# New LibSqlEx schema:
schema "posts" do
  field :tags, :map  # or {:array, :string} with custom type
end

# Custom type for arrays:
defmodule MyApp.StringArray do
  use Ecto.Type

  def type, do: :string

  def cast(list) when is_list(list), do: {:ok, list}
  def cast(_), do: :error

  def load(json) when is_binary(json) do
    Jason.decode(json)
  end

  def dump(list) when is_list(list) do
    Jason.encode(list)
  end
  def dump(_), do: :error
end

# Usage:
schema "posts" do
  field :tags, MyApp.StringArray
end
```

## Migration Compatibility

Most Ecto migrations work with minor adjustments.

### ✅ Fully Supported

```elixir
def change do
  create table(:users) do
    add :name, :string
    add :email, :string
    add :age, :integer
    timestamps()
  end

  create unique_index(:users, [:email])
  create index(:users, [:age])

  alter table(:users) do
    add :bio, :text
  end

  drop index(:users, [:age])
  drop table(:old_table)

  rename table(:users), :name, to: :full_name
  rename table(:old_users), to: table(:new_users)
end
```

### ⚠️ Not Supported

```elixir
# ❌ ALTER COLUMN (can't modify column types)
alter table(:users) do
  modify :age, :string  # NOT SUPPORTED
end

# Workaround: Recreate the table
# See "Advanced Migrations" section below

# ❌ DROP COLUMN (in older SQLite versions)
alter table(:users) do
  remove :old_field  # NOT SUPPORTED on SQLite < 3.35.0
end

# Workaround: Recreate the table

# ❌ Arrays
create table(:posts) do
  add :tags, {:array, :string}  # NOT SUPPORTED
end

# Use JSON instead:
create table(:posts) do
  add :tags, :text  # Store JSON
end
```

## Advanced Migrations

### Recreating Tables for Schema Changes

When you need to modify column types or remove columns, use this pattern:

```elixir
defmodule MyApp.Repo.Migrations.ChangeUserAgeToString do
  use Ecto.Migration

  def up do
    # Create new table with desired schema
    create table(:users_new) do
      add :id, :integer, primary_key: true
      add :name, :string
      add :email, :string
      add :age, :string  # Changed from :integer
      timestamps()
    end

    # Copy data
    execute """
    INSERT INTO users_new (id, name, email, age, inserted_at, updated_at)
    SELECT id, name, email, CAST(age AS TEXT), inserted_at, updated_at
    FROM users
    """

    # Swap tables
    drop table(:users)
    rename table(:users_new), to: table(:users)

    # Recreate indexes
    create unique_index(:users, [:email])
  end

  def down do
    # Reverse process if needed
  end
end
```

## Production Deployment

### Turso Remote Replica (Recommended)

For production, use Turso's remote replica mode for best performance:

```elixir
# config/prod.exs
config :my_app, MyApp.Repo,
  adapter: Ecto.Adapters.LibSql,
  database: "prod_replica.db",
  uri: System.get_env("TURSO_URL"),
  auth_token: System.get_env("TURSO_AUTH_TOKEN"),
  sync: true,
  pool_size: 10
```

**Benefits:**
- 🚀 Microsecond read latency (local SQLite file)
- ☁️ Automatic sync to Turso cloud
- 🌍 Deploy globally with Turso edge
- 💪 Offline-first capability

### Setting up Turso

1. Install Turso CLI:
```bash
curl -sSfL https://get.tur.so/install.sh | bash
```

2. Create a database:
```bash
turso db create my-app-prod
```

3. Get connection info:
```bash
turso db show my-app-prod --url
turso db tokens create my-app-prod
```

4. Set environment variables:
```bash
export TURSO_URL="libsql://my-app-prod-....turso.io"
export TURSO_AUTH_TOKEN="eyJ..."
```

## Query Differences

Most Ecto queries work identically. Here are the differences:

### ✅ Works the Same

```elixir
# All these work identically:
Repo.all(User)
Repo.get(User, id)
Repo.insert(user)
Repo.update(changeset)
Repo.delete(user)

User |> where([u], u.age > 18) |> Repo.all()
User |> order_by([u], desc: u.inserted_at) |> Repo.all()
User |> join(:inner, [u], p in Post, on: p.user_id == u.id) |> Repo.all()
```

### ⚠️ Differences

```elixir
# PostgreSQL-specific functions won't work:
# ❌ fragment("? @> ?", p.tags, ^["elixir"])  # JSONB operators
# ❌ fragment("? && ?", p.range, ^range)      # Range operators

# Use SQLite-compatible functions instead:
# ✅ fragment("json_extract(?, '$.key') = ?", p.data, ^value)
```

## Testing

Update your test configuration:

```elixir
# config/test.exs
config :my_app, MyApp.Repo,
  adapter: Ecto.Adapters.LibSql,
  database: "my_app_test.db",
  pool: Ecto.Adapters.SQL.Sandbox
```

Your tests should work without changes:

```elixir
defmodule MyApp.UserTest do
  use MyApp.DataCase

  test "creates a user" do
    {:ok, user} = MyApp.create_user(%{name: "Alice", email: "alice@example.com"})
    assert user.name == "Alice"
  end
end
```

## Common Issues and Solutions

### Issue: UUID primary keys

**Problem:** You're using UUIDs as primary keys

**Solution:** Change to `:binary_id` type

```elixir
# Old:
@primary_key {:id, :uuid, autogenerate: true}

# New:
@primary_key {:id, :binary_id, autogenerate: true}
```

### Issue: Arrays in schemas

**Problem:** Using PostgreSQL array types

**Solution:** Use JSON encoding or separate tables

```elixir
# Option 1: JSON encoding (simple)
field :tags, :map

# Option 2: Separate table (normalized)
has_many :tags, MyApp.Tag
```

### Issue: Concurrent writes

**Problem:** Getting "database is locked" errors

**Solution:** Use transactions and appropriate isolation levels

```elixir
Repo.transaction(fn ->
  # Your writes here
end, timeout: 15_000)
```

### Issue: Case sensitivity

**Problem:** SQLite is case-insensitive for LIKE by default

**Solution:** Use GLOB for case-sensitive matching

```elixir
# Case-insensitive (default):
where([u], like(u.name, ^"%alice%"))

# Case-sensitive:
where([u], fragment("? GLOB ?", u.name, ^"*Alice*"))
```

## Performance Tips

1. **Use indexes** - SQLite benefits greatly from proper indexing
```elixir
create index(:users, [:email])
create index(:posts, [:user_id, :published])
```

2. **Use remote replica mode** - Get local read performance with cloud backup
```elixir
sync: true  # Auto-sync writes to Turso
```

3. **Use transactions** - Group multiple writes for better performance
```elixir
Repo.transaction(fn ->
  Enum.each(users, &Repo.insert/1)
end)
```

4. **Use prepared statements** - Ecto does this automatically, but you can also use raw queries
```elixir
Repo.query("SELECT * FROM users WHERE age > $1", [18])
```

## Next Steps

1. ✅ Update dependencies and configuration
2. ✅ Test migrations in development
3. ✅ Update any PostgreSQL-specific code
4. ✅ Run your test suite
5. ✅ Set up Turso for production
6. ✅ Deploy and monitor

## Getting Help

- **Documentation**: https://hexdocs.pm/libsqlex
- **GitHub Issues**: https://github.com/danawanb/libsqlex/issues
- **Turso Docs**: https://docs.turso.tech
- **SQLite Docs**: https://www.sqlite.org/docs.html
