defmodule EctoLibSql.PoolLoadTest do
  @moduledoc """
  Tests for concurrent connection behaviour under load.

  Critical scenarios:
  1. Multiple concurrent independent connections
  2. Long-running queries don't cause timeout issues
  3. Connection recovery after errors
  4. Resource cleanup under concurrent load
  5. Transaction isolation under concurrent load

  Note: Tests create separate connections (not pooled) to simulate
  concurrent access patterns and verify robustness.
  """
  use ExUnit.Case

  alias EctoLibSql

  setup do
    test_db = "z_ecto_libsql_test-pool_#{:erlang.unique_integer([:positive])}.db"

    # Create test table
    {:ok, state} = EctoLibSql.connect(database: test_db)

    {:ok, _query, _result, _state} =
      EctoLibSql.handle_execute(
        "CREATE TABLE test_data (id INTEGER PRIMARY KEY AUTOINCREMENT, value TEXT, duration INTEGER)",
        [],
        [],
        state
      )

    on_exit(fn ->
      EctoLibSql.disconnect([], state)
      EctoLibSql.TestHelpers.cleanup_db_files(test_db)
    end)

    {:ok, test_db: test_db}
  end

  describe "concurrent independent connections" do
    @tag :slow
    @tag :flaky
    test "multiple concurrent connections execute successfully", %{test_db: test_db} do
      # Spawn 5 concurrent connections
      tasks =
        Enum.map(1..5, fn i ->
          Task.async(fn ->
            {:ok, state} = EctoLibSql.connect(database: test_db, busy_timeout: 30_000)

            try do
              EctoLibSql.handle_execute(
                "INSERT INTO test_data (value) VALUES (?)",
                ["task_#{i}"],
                [],
                state
              )
            after
              EctoLibSql.disconnect([], state)
            end
          end)
        end)

      # Wait for all to complete with extended timeout
      results = Task.await_many(tasks, 30_000)

      # All should succeed
      Enum.each(results, fn result ->
        assert {:ok, _query, _result, _state} = result
      end)

      # Verify all inserts succeeded
      {:ok, state} = EctoLibSql.connect(database: test_db, busy_timeout: 30_000)

      {:ok, _query, result, _state} =
        EctoLibSql.handle_execute("SELECT COUNT(*) FROM test_data", [], [], state)

      EctoLibSql.disconnect([], state)

      assert [[5]] = result.rows
    end

    @tag :slow
    @tag :flaky
    test "rapid burst of concurrent connections succeeds", %{test_db: test_db} do
      # Fire 10 connections rapidly
      tasks =
        Enum.map(1..10, fn i ->
          Task.async(fn ->
            {:ok, state} = EctoLibSql.connect(database: test_db, busy_timeout: 30_000)

            try do
              EctoLibSql.handle_execute(
                "INSERT INTO test_data (value) VALUES (?)",
                ["burst_#{i}"],
                [],
                state
              )
            after
              EctoLibSql.disconnect([], state)
            end
          end)
        end)

      results = Task.await_many(tasks, 30_000)

      # All should succeed
      success_count = Enum.count(results, fn r -> match?({:ok, _, _, _}, r) end)
      assert success_count == 10
    end
  end

  describe "long-running operations" do
    @tag :slow
    @tag :flaky
    test "long transaction doesn't cause timeout issues", %{test_db: test_db} do
      {:ok, state} = EctoLibSql.connect(database: test_db, busy_timeout: 5000)

      try do
        # Start longer transaction
        {:ok, trx_state} = EctoLibSql.Native.begin(state)

        {:ok, _query, _result, trx_state} =
          EctoLibSql.handle_execute(
            "INSERT INTO test_data (value, duration) VALUES (?, ?)",
            ["long", 100],
            [],
            trx_state
          )

        # Simulate some work
        Process.sleep(100)

        {:ok, _committed_state} = EctoLibSql.Native.commit(trx_state)
      after
        EctoLibSql.disconnect([], state)
      end
    end

    @tag :slow
    @tag :flaky
    test "multiple concurrent transactions complete despite duration", %{test_db: test_db} do
      tasks =
        Enum.map(1..3, fn i ->
          Task.async(fn ->
            {:ok, state} = EctoLibSql.connect(database: test_db, busy_timeout: 30_000)

            try do
              {:ok, trx_state} = EctoLibSql.Native.begin(state)

              {:ok, _query, _result, trx_state} =
                EctoLibSql.handle_execute(
                  "INSERT INTO test_data (value) VALUES (?)",
                  ["trx_#{i}"],
                  [],
                  trx_state
                )

              # Hold transaction
              Process.sleep(50)

              EctoLibSql.Native.commit(trx_state)
            after
              EctoLibSql.disconnect([], state)
            end
          end)
        end)

      results = Task.await_many(tasks, 30_000)

      # All should succeed
      Enum.each(results, fn result ->
        assert {:ok, _state} = result
      end)

      # Verify all inserts
      {:ok, state} = EctoLibSql.connect(database: test_db, busy_timeout: 30_000)

      {:ok, _query, result, _state} =
        EctoLibSql.handle_execute("SELECT COUNT(*) FROM test_data", [], [], state)

      EctoLibSql.disconnect([], state)

      assert [[3]] = result.rows
    end
  end

  describe "connection recovery" do
    @tag :slow
    @tag :flaky
    test "connection recovers after query error", %{test_db: test_db} do
      {:ok, state} = EctoLibSql.connect(database: test_db, busy_timeout: 30_000)

      try do
        # Successful insert
        {:ok, _query, _result, state} =
          EctoLibSql.handle_execute(
            "INSERT INTO test_data (value) VALUES (?)",
            ["before"],
            [],
            state
          )

        # Force error (syntax)
        error_result = EctoLibSql.handle_execute("INVALID SQL", [], [], state)
        assert {:error, _reason, ^state} = error_result

        # Connection should still work
        # (state variable intentionally rebound with new connection state)
        {:ok, _query, _result, state} =
          EctoLibSql.handle_execute(
            "INSERT INTO test_data (value) VALUES (?)",
            ["after"],
            [],
            state
          )
      after
        EctoLibSql.disconnect([], state)
      end

      # Verify both successful inserts
      {:ok, state} = EctoLibSql.connect(database: test_db, busy_timeout: 30_000)

      try do
        {:ok, _query, result, _state} =
          EctoLibSql.handle_execute("SELECT COUNT(*) FROM test_data", [], [], state)

        assert [[2]] = result.rows
      after
        EctoLibSql.disconnect([], state)
      end
    end

    @tag :slow
    @tag :flaky
    test "multiple connections recover independently from errors", %{test_db: test_db} do
      tasks =
        Enum.map(1..3, fn i ->
          Task.async(fn ->
            {:ok, state} = EctoLibSql.connect(database: test_db, busy_timeout: 30_000)

            try do
              # Insert before error
              {:ok, _query, _result, state} =
                EctoLibSql.handle_execute(
                  "INSERT INTO test_data (value) VALUES (?)",
                  ["before_#{i}"],
                  [],
                  state
                )

              # Cause error
              EctoLibSql.handle_execute("BAD SQL", [], [], state)

              # Recovery insert
              EctoLibSql.handle_execute(
                "INSERT INTO test_data (value) VALUES (?)",
                ["after_#{i}"],
                [],
                state
              )
            after
              EctoLibSql.disconnect([], state)
            end
          end)
        end)

      results = Task.await_many(tasks, 30_000)

      # All recovery queries should succeed
      Enum.each(results, fn result ->
        assert {:ok, _query, _result, _state} = result
      end)

      # Verify all inserts
      {:ok, state} = EctoLibSql.connect(database: test_db, busy_timeout: 30_000)

      {:ok, _query, result, _state} =
        EctoLibSql.handle_execute("SELECT COUNT(*) FROM test_data", [], [], state)

      EctoLibSql.disconnect([], state)

      # Should have 6 rows (3 before + 3 after)
      assert [[6]] = result.rows
    end
  end

  describe "resource cleanup under load" do
    @tag :slow
    @tag :flaky
    test "prepared statements cleaned up under concurrent load", %{test_db: test_db} do
      tasks =
        Enum.map(1..5, fn i ->
          Task.async(fn ->
            {:ok, state} = EctoLibSql.connect(database: test_db, busy_timeout: 30_000)

            try do
              {:ok, stmt} =
                EctoLibSql.Native.prepare(
                  state,
                  "INSERT INTO test_data (value) VALUES (?)"
                )

              {:ok, _} =
                EctoLibSql.Native.execute_stmt(
                  state,
                  stmt,
                  "INSERT INTO test_data (value) VALUES (?)",
                  ["prep_#{i}"]
                )

              :ok = EctoLibSql.Native.close_stmt(stmt)
            after
              EctoLibSql.disconnect([], state)
            end
          end)
        end)

      Task.await_many(tasks, 30_000)

      # Verify all inserts succeeded
      {:ok, state} = EctoLibSql.connect(database: test_db, busy_timeout: 30_000)

      {:ok, _query, result, _state} =
        EctoLibSql.handle_execute("SELECT COUNT(*) FROM test_data", [], [], state)

      EctoLibSql.disconnect([], state)

      assert [[5]] = result.rows
    end
  end

  describe "transaction isolation" do
    @tag :slow
    @tag :flaky
    test "concurrent transactions don't interfere with each other", %{test_db: test_db} do
      tasks =
        Enum.map(1..4, fn i ->
          Task.async(fn ->
            {:ok, state} = EctoLibSql.connect(database: test_db, busy_timeout: 30_000)

            try do
              {:ok, trx_state} = EctoLibSql.Native.begin(state)

              {:ok, _query, _result, trx_state} =
                EctoLibSql.handle_execute(
                  "INSERT INTO test_data (value) VALUES (?)",
                  ["iso_#{i}"],
                  [],
                  trx_state
                )

              # Slight delay to increase overlap
              Process.sleep(10)

              EctoLibSql.Native.commit(trx_state)
            after
              EctoLibSql.disconnect([], state)
            end
          end)
        end)

      results = Task.await_many(tasks, 30_000)

      # All should succeed
      Enum.each(results, fn result ->
        assert {:ok, _state} = result
      end)

      # All inserts should be visible
      {:ok, state} = EctoLibSql.connect(database: test_db, busy_timeout: 30_000)

      {:ok, _query, result, _state} =
        EctoLibSql.handle_execute("SELECT COUNT(*) FROM test_data", [], [], state)

      EctoLibSql.disconnect([], state)

      assert [[4]] = result.rows
    end
  end
end
