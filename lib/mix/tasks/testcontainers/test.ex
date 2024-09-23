# lib/mix/tasks/custom_test.ex
defmodule Mix.Tasks.Testcontainers.Test do
  use Mix.Task
  alias Testcontainers.PostgresContainer
  alias Testcontainers.MySqlContainer

  @shortdoc "Runs tests with a Postgres container"
  def run(args) do
    Application.ensure_all_started(:tesla)
    Application.ensure_all_started(:hackney)
    {:ok, _} = Testcontainers.start_link()

    {opts, _, _} = OptionParser.parse(args, switches: [
      database: :string
    ])

    database = opts[:database] || "postgres"

    {container, port} = case database do
      "postgres" ->
        {:ok, container} = Testcontainers.start_container(PostgresContainer.new() |> PostgresContainer.with_user("test") |> PostgresContainer.with_password("test"))
        port = PostgresContainer.port(container)
        {container, port}
      "mysql" ->
        {:ok, container} = Testcontainers.start_container(MySqlContainer.new() |> MySqlContainer.with_user("test") |> MySqlContainer.with_password("test"))
        port = MySqlContainer.port(container)
        {container, port}
      _ -> Mix.raise("Unsupported database: #{database}")
    end

    env = [
      {"DB_USER", "test"},
      {"DB_PASSWORD", "test"},
      {"DB_HOST", Testcontainers.get_host()},
      {"DB_PORT", port |> Integer.to_string()}
    ]

    try do
      {output, exit_code} = System.cmd("mix", ["test"], env: env)
      if exit_code != 0 do
        IO.puts(output)
        raise "\u274c Tests failed"
      end
      IO.puts("\u2705 Tests passed")
    after
      Testcontainers.stop_container(container.container_id)
    end
  end
end
