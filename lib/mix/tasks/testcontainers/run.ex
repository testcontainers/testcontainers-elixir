defmodule Mix.Tasks.Testcontainers.Run do
  use Mix.Task
  alias Testcontainers.PostgresContainer
  alias Testcontainers.MySqlContainer

  @shortdoc "Runs a Mix sub-task (test, phx.server, etc) with a database container"
  @moduledoc """
  Usage:
    mix testcontainers.run [sub_task] [--database DB] [--db-volume VOLUME] [sub_task_args...]

  Examples:
    mix testcontainers.run test --database postgres
    mix testcontainers.run phx.server --database mysql
    mix testcontainers.run test --database postgres --db-volume my_postgres_data
    mix testcontainers.run phx.server --db-volume my_postgres_data
    mix testcontainers.run some.custom.server
  """

  def run(args) do
    Enum.each([:tesla, :hackney, :fs, :logger], fn app ->
      {:ok, _} = Application.ensure_all_started(app)
    end)

    {:ok, _} = Testcontainers.start_link()

    {opts, rest_args, _} =
      OptionParser.parse(args,
        switches: [
          database: :string,
          db_volume: :string
        ]
      )

    database = opts[:database] || "postgres"
    db_volume = opts[:db_volume]

    # Determine sub_task and its args
    {sub_task, sub_task_args} =
      case rest_args do
        [task | tail] -> {task, tail}
        [] -> {"test", []}
      end

    run_sub_task_and_exit(database, sub_task, sub_task_args, db_volume)
  end

  @spec run_sub_task_and_exit(String.t(), String.t(), list(String.t()), String.t() | nil) :: no_return()
  defp run_sub_task_and_exit(database, sub_task, sub_task_args, db_volume) do
    {container, env} = setup_container(database, db_volume)

    IO.puts("Starting in-process mix task: #{sub_task} #{Enum.join(sub_task_args, " ")}")

    System.at_exit(fn _ ->
      try do
        Testcontainers.stop_container(container.container_id)
      catch
        _, _ -> :ok
      end
    end)

    Enum.each(env, fn {k, v} -> System.put_env(k, v) end)
    Mix.Task.run(sub_task, sub_task_args)
  end

  defp setup_container(database, db_volume) do
    case database do
      "postgres" ->
        container_def =
          PostgresContainer.new()
          |> PostgresContainer.with_user("test")
          |> PostgresContainer.with_password("test")
          |> PostgresContainer.with_reuse(true)
          |> maybe_with_persistent_volume(db_volume, PostgresContainer)

        {:ok, container} = Testcontainers.start_container(container_def)
        port = PostgresContainer.port(container)
        {container, create_env(port)}

      "mysql" ->
        container_def =
          MySqlContainer.new()
          |> MySqlContainer.with_user("test")
          |> MySqlContainer.with_password("test")
          |> MySqlContainer.with_reuse(true)
          |> maybe_with_persistent_volume(db_volume, MySqlContainer)

        {:ok, container} = Testcontainers.start_container(container_def)
        port = MySqlContainer.port(container)
        {container, create_env(port)}

      _ ->
        raise("Unsupported database: #{database}")
    end
  end

  defp maybe_with_persistent_volume(config, db_volume, module) do
    if db_volume do
      module.with_persistent_volume(config, db_volume)
    else
      config
    end
  end

  defp create_env(port) do
    [
      {"DATABASE_URL", "ecto://test:test@#{Testcontainers.get_host()}:#{port}/test"}
    ]
  end
end
