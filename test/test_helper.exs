# Exclude :ci_only, :slow, and :flaky tests when running locally
# - :ci_only tests (like path traversal) are only run on CI by default
# - :slow tests (like stress/load tests) are excluded by default to keep test runs fast
# - :flaky tests (like concurrency tests) are excluded by default to avoid CI brittleness
ci? =
  case System.get_env("CI") do
    nil -> false
    v -> (v |> String.trim() |> String.downcase()) in ["1", "true", "yes", "y", "on"]
  end

exclude =
  if ci? do
    # Running on CI (GitHub Actions, etc.) - skip flaky tests to keep CI stable
    [flaky: true]
  else
    # Running locally - skip :ci_only, :slow, and :flaky tests
    [ci_only: true, slow: true, flaky: true]
  end

ExUnit.start(exclude: exclude)

# Set logger level to :info to reduce debug output during tests
Logger.configure(level: :info)
