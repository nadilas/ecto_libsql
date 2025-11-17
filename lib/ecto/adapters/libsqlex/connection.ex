defmodule Ecto.Adapters.LibSqlEx.Connection do
  @moduledoc false

  @behaviour Ecto.Adapters.SQL.Connection

  ## Query Generation

  @impl true
  def child_spec(opts) do
    DBConnection.child_spec(LibSqlEx, opts)
  end

  @impl true
  def prepare_execute(conn, name, sql, params, opts) do
    query = %LibSqlEx.Query{name: name, statement: sql}

    case DBConnection.prepare_execute(conn, query, params, opts) do
      {:ok, _query, result} -> {:ok, query, result}
      {:error, _} = error -> error
    end
  end

  @impl true
  def execute(conn, sql, params, opts) when is_binary(sql) do
    query = %LibSqlEx.Query{statement: sql}

    case DBConnection.execute(conn, query, params, opts) do
      {:ok, _query, result} -> {:ok, result}
      {:error, _} = error -> error
    end
  end

  def execute(conn, %{} = query, params, opts) do
    case DBConnection.execute(conn, query, params, opts) do
      {:ok, _query, result} -> {:ok, result}
      {:error, _} = error -> error
    end
  end

  @impl true
  def stream(conn, sql, params, opts) do
    DBConnection.stream(conn, %LibSqlEx.Query{statement: sql}, params, opts)
  end

  @impl true
  def to_constraints(%{message: message}, _opts) do
    case message do
      "UNIQUE constraint failed: " <> _ ->
        [unique: extract_constraint_name(message)]

      "FOREIGN KEY constraint failed" ->
        [foreign_key: :unknown]

      "CHECK constraint failed: " <> _ ->
        [check: extract_constraint_name(message)]

      _ ->
        []
    end
  end

  defp extract_constraint_name(message) do
    # Extract constraint name from SQLite error messages
    case Regex.run(~r/constraint failed: (\w+)/, message) do
      [_, name] -> String.to_atom(name)
      _ -> :unknown
    end
  end

  ## DDL Generation

  @impl true
  def ddl_logs(_), do: []

  @impl true
  def execute_ddl({command, %Ecto.Migration.Table{} = table, columns})
      when command in [:create, :create_if_not_exists] do
    table_name = quote_table(table.prefix, table.name)
    if_not_exists = if command == :create_if_not_exists, do: " IF NOT EXISTS", else: ""

    column_definitions = Enum.map_join(columns, ", ", &column_definition/1)
    table_options = table_options(table, columns)

    [
      "CREATE TABLE#{if_not_exists} #{table_name} (#{column_definitions}#{table_options})"
    ]
  end

  def execute_ddl({:drop, %Ecto.Migration.Table{} = table, _}) do
    table_name = quote_table(table.prefix, table.name)
    ["DROP TABLE #{table_name}"]
  end

  def execute_ddl({:drop_if_exists, %Ecto.Migration.Table{} = table, _}) do
    table_name = quote_table(table.prefix, table.name)
    ["DROP TABLE IF EXISTS #{table_name}"]
  end

  def execute_ddl({:alter, %Ecto.Migration.Table{} = table, changes}) do
    table_name = quote_table(table.prefix, table.name)

    Enum.flat_map(changes, fn
      {:add, name, type, opts} ->
        column_def = column_definition({:add, name, type, opts})
        ["ALTER TABLE #{table_name} ADD COLUMN #{column_def}"]

      {:modify, _name, _type, _opts} ->
        raise ArgumentError,
              "ALTER COLUMN is not supported by SQLite. " <>
                "You need to recreate the table instead."

      {:remove, name, _type, _opts} ->
        # SQLite doesn't support DROP COLUMN directly (before 3.35.0)
        # For now, raise an error suggesting table recreation
        raise ArgumentError,
              "DROP COLUMN for #{name} is not supported by older SQLite versions. " <>
                "You need to recreate the table instead."
    end)
  end

  def execute_ddl({:create, %Ecto.Migration.Index{} = index}) do
    fields = Enum.map_join(index.columns, ", ", &quote_name/1)
    table_name = quote_table(index.prefix, index.table)
    index_name = quote_name(index.name)
    unique = if index.unique, do: "UNIQUE ", else: ""
    where = if index.where, do: " WHERE #{index.where}", else: ""

    ["CREATE #{unique}INDEX #{index_name} ON #{table_name} (#{fields})#{where}"]
  end

  def execute_ddl({:create_if_not_exists, %Ecto.Migration.Index{} = index}) do
    fields = Enum.map_join(index.columns, ", ", &quote_name/1)
    table_name = quote_table(index.prefix, index.table)
    index_name = quote_name(index.name)
    unique = if index.unique, do: "UNIQUE ", else: ""
    where = if index.where, do: " WHERE #{index.where}", else: ""

    ["CREATE #{unique}INDEX IF NOT EXISTS #{index_name} ON #{table_name} (#{fields})#{where}"]
  end

  def execute_ddl({:drop, %Ecto.Migration.Index{} = index, _}) do
    index_name = quote_name(index.name)
    ["DROP INDEX #{index_name}"]
  end

  def execute_ddl({:drop_if_exists, %Ecto.Migration.Index{} = index, _}) do
    index_name = quote_name(index.name)
    ["DROP INDEX IF EXISTS #{index_name}"]
  end

  def execute_ddl({:rename, %Ecto.Migration.Table{} = table, old_name, new_name}) do
    table_name = quote_table(table.prefix, table.name)
    ["ALTER TABLE #{table_name} RENAME COLUMN #{quote_name(old_name)} TO #{quote_name(new_name)}"]
  end

  def execute_ddl(
        {:rename, %Ecto.Migration.Table{} = old_table, %Ecto.Migration.Table{} = new_table}
      ) do
    old_name = quote_table(old_table.prefix, old_table.name)
    new_name = quote_table(new_table.prefix, new_table.name)
    ["ALTER TABLE #{old_name} RENAME TO #{new_name}"]
  end

  def execute_ddl(string) when is_binary(string), do: [string]

  def execute_ddl(keyword) when is_list(keyword) do
    raise ArgumentError, "SQLite adapter does not support keyword lists in execute"
  end

  ## DDL Helpers

  defp column_definition({:add, name, type, opts}) do
    "#{quote_name(name)} #{column_type(type, opts)}#{column_options(opts)}"
  end

  defp column_type(:id, _opts), do: "INTEGER"
  defp column_type(:binary_id, _opts), do: "TEXT"
  defp column_type(:uuid, _opts), do: "TEXT"
  defp column_type(:string, opts), do: "TEXT#{size_constraint(opts)}"
  defp column_type(:binary, opts), do: "BLOB#{size_constraint(opts)}"
  defp column_type(:map, _opts), do: "TEXT"
  defp column_type({:map, _}, _opts), do: "TEXT"
  defp column_type(:decimal, _opts), do: "DECIMAL"
  defp column_type(:float, _opts), do: "REAL"
  defp column_type(:integer, _opts), do: "INTEGER"
  defp column_type(:boolean, _opts), do: "INTEGER"
  defp column_type(:text, _opts), do: "TEXT"
  defp column_type(:date, _opts), do: "DATE"
  defp column_type(:time, _opts), do: "TIME"
  defp column_type(:time_usec, _opts), do: "TIME"
  defp column_type(:naive_datetime, _opts), do: "DATETIME"
  defp column_type(:naive_datetime_usec, _opts), do: "DATETIME"
  defp column_type(:utc_datetime, _opts), do: "DATETIME"
  defp column_type(:utc_datetime_usec, _opts), do: "DATETIME"

  defp column_type({:array, _}, _opts) do
    raise ArgumentError,
          "SQLite does not support array types. Use JSON or separate tables instead."
  end

  defp column_type(type, _opts) when is_atom(type), do: Atom.to_string(type) |> String.upcase()
  defp column_type(type, _opts), do: type

  defp size_constraint(opts) do
    case Keyword.get(opts, :size) do
      nil -> ""
      size -> "(#{size})"
    end
  end

  defp column_options(opts) do
    default = column_default(Keyword.get(opts, :default))
    null = if Keyword.get(opts, :null) == false, do: " NOT NULL", else: ""
    pk = if Keyword.get(opts, :primary_key), do: " PRIMARY KEY", else: ""

    "#{pk}#{null}#{default}"
  end

  defp column_default(nil), do: ""
  defp column_default(true), do: " DEFAULT 1"
  defp column_default(false), do: " DEFAULT 0"
  defp column_default(value) when is_binary(value), do: " DEFAULT '#{escape_string(value)}'"
  defp column_default(value) when is_number(value), do: " DEFAULT #{value}"
  defp column_default({:fragment, expr}), do: " DEFAULT #{expr}"

  defp table_options(table, columns) do
    pk =
      Enum.filter(columns, fn {:add, _name, _type, opts} ->
        Keyword.get(opts, :primary_key, false)
      end)

    cond do
      length(pk) > 1 ->
        pk_names = Enum.map_join(pk, ", ", fn {:add, name, _type, _opts} -> quote_name(name) end)
        ", PRIMARY KEY (#{pk_names})"

      table.options ->
        # Handle custom table options
        ""

      true ->
        ""
    end
  end

  ## Query Helpers

  defp quote_table(nil, name), do: quote_name(name)
  defp quote_table(prefix, name), do: quote_name(prefix) <> "." <> quote_name(name)

  defp quote_name(name) when is_atom(name), do: quote_name(Atom.to_string(name))

  defp quote_name(name) do
    if String.contains?(name, "\"") do
      raise ArgumentError, "bad table/column name #{inspect(name)}"
    end

    ~s("#{name}")
  end

  defp escape_string(value) do
    String.replace(value, "'", "''")
  end

  ## Table and column existence checks

  @impl true
  def table_exists_query(table) do
    {"SELECT 1 FROM sqlite_master WHERE type='table' AND name=?1 LIMIT 1", [table]}
  end
end
