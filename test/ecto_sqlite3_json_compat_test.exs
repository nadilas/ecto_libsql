defmodule EctoLibSql.EctoSqlite3JsonCompatTest do
  @moduledoc """
  Compatibility tests based on ecto_sqlite3 JSON test suite.
  
  These tests ensure that JSON/MAP field serialization and deserialization
  works identically to ecto_sqlite3.
  """

  use EctoLibSql.Integration.Case, async: false

  alias Ecto.Adapters.SQL
  alias EctoLibSql.Integration.TestRepo
  alias EctoLibSql.Schemas.Setting

  @test_db "z_ecto_libsql_test-sqlite3_json_compat.db"

  setup_all do
    # Configure the repo
    Application.put_env(:ecto_libsql, EctoLibSql.Integration.TestRepo,
      adapter: Ecto.Adapters.LibSql,
      database: @test_db
    )

    {:ok, _} = EctoLibSql.Integration.TestRepo.start_link()

    # Run migrations
    :ok = Ecto.Migrator.up(
      EctoLibSql.Integration.TestRepo,
      0,
      EctoLibSql.Integration.Migration,
      log: false
    )

    on_exit(fn ->
      EctoLibSql.TestHelpers.cleanup_db_files(@test_db)
    end)

    :ok
  end

  test "serializes json correctly" do
    # Insert a record purposefully with atoms as the map key. We are going to
    # verify later they were coerced into strings.
    setting =
      %Setting{}
      |> Setting.changeset(%{properties: %{foo: "bar", qux: "baz"}})
      |> TestRepo.insert!()

    # Read the record back using ecto and confirm it
    assert %Setting{properties: %{"foo" => "bar", "qux" => "baz"}} =
             TestRepo.get(Setting, setting.id)

    assert %{num_rows: 1, rows: [["bar"]]} =
             SQL.query!(
               TestRepo,
               "select json_extract(properties, '$.foo') from settings where id = ?",
               [setting.id]
             )
  end

  test "json field round-trip with various types" do
    json_data = %{
      "string" => "value",
      "number" => 42,
      "float" => 3.14,
      "bool" => true,
      "null" => nil,
      "array" => [1, 2, 3],
      "nested" => %{"inner" => "data"}
    }

    setting =
      %Setting{}
      |> Setting.changeset(%{properties: json_data})
      |> TestRepo.insert!()

    # Query back
    fetched = TestRepo.get(Setting, setting.id)
    assert fetched.properties == json_data
  end

  test "json field with atoms in keys" do
    # Maps with atom keys should be converted to string keys
    setting =
      %Setting{}
      |> Setting.changeset(%{properties: %{atom_key: "value", another: "data"}})
      |> TestRepo.insert!()

    fetched = TestRepo.get(Setting, setting.id)
    # Keys should be strings after round-trip
    assert fetched.properties == %{"atom_key" => "value", "another" => "data"}
  end

  test "json field with nil" do
    setting =
      %Setting{}
      |> Setting.changeset(%{properties: nil})
      |> TestRepo.insert!()

    fetched = TestRepo.get(Setting, setting.id)
    assert fetched.properties == nil
  end

  test "json field with empty map" do
    setting =
      %Setting{}
      |> Setting.changeset(%{properties: %{}})
      |> TestRepo.insert!()

    fetched = TestRepo.get(Setting, setting.id)
    assert fetched.properties == %{}
  end

  test "update json field" do
    setting =
      %Setting{}
      |> Setting.changeset(%{properties: %{"initial" => "value"}})
      |> TestRepo.insert!()

    # Update the JSON field
    {:ok, updated} =
      setting
      |> Setting.changeset(%{properties: %{"updated" => "data", "count" => 5}})
      |> TestRepo.update()

    fetched = TestRepo.get(Setting, updated.id)
    assert fetched.properties == %{"updated" => "data", "count" => 5}
  end
end
