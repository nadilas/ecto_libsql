defmodule EctoLibSql.EctoSqlite3ReturningDebugTest do
  @moduledoc """
  Debug test to isolate RETURNING clause issues
  """

  use ExUnit.Case, async: false

  alias EctoLibSql.Integration.TestRepo
  alias EctoLibSql.Schemas.User

  @test_db "z_ecto_libsql_test-debug.db"

  setup_all do
    # Configure the repo
    Application.put_env(:ecto_libsql, EctoLibSql.Integration.TestRepo,
      adapter: Ecto.Adapters.LibSql,
      database: @test_db
    )

    {:ok, _} = EctoLibSql.Integration.TestRepo.start_link()

    # Run migrations
    :ok =
      Ecto.Migrator.up(
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

  test "insert returns user with ID" do
    IO.puts("\n=== Testing Repo.insert RETURNING ===")

    result = TestRepo.insert(%User{name: "Alice"})
    IO.inspect(result, label: "Insert result")

    case result do
      {:ok, user} ->
        IO.inspect(user, label: "User struct")
        assert user.id != nil, "User ID should not be nil"
        assert user.name == "Alice"
        assert user.inserted_at != nil, "inserted_at should not be nil"
        assert user.updated_at != nil, "updated_at should not be nil"

      {:error, reason} ->
        flunk("Insert failed: #{inspect(reason)}")
    end
  end

  test "insert multiple users with different IDs" do
    result1 = TestRepo.insert(%User{name: "Bob"})
    result2 = TestRepo.insert(%User{name: "Charlie"})

    case {result1, result2} do
      {{:ok, bob}, {:ok, charlie}} ->
        assert bob.id != nil
        assert charlie.id != nil
        assert bob.id != charlie.id
        IO.inspect({bob.id, charlie.id}, label: "IDs")

      _ ->
        flunk("One or more inserts failed")
    end
  end
end
