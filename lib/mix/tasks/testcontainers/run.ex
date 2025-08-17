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

    # Always stop the container when the VM exits (covers both long-running and short-lived tasks)
    System.at_exit(fn _ ->
      try do
        Testcontainers.stop_container(container.container_id)
      catch
        _, _ -> :ok
      end
    end)

    with_env(env, fn ->
      maybe_bootstrap_tools()
      # Running the sub-task in-process blocks for long-running tasks and returns for short-lived ones.
      run_mix_task_in_process(sub_task, sub_task_args)
    end)
  end

  defp setup_container(database, db_volume) do
    case database do
      "postgres" ->
        container_def =
          PostgresContainer.new()
          |> PostgresContainer.with_user("test")
          |> PostgresContainer.with_password("test")
          |> PostgresContainer.with_reuse(true)
          |> (fn config ->
                if db_volume do
                  PostgresContainer.with_persistent_volume(config, db_volume)
                else
                  config
                end
              end).()

        {:ok, container} = Testcontainers.start_container(container_def)
        port = PostgresContainer.port(container)
        {container, create_env(port)}

      "mysql" ->
        container_def =
          MySqlContainer.new()
          |> MySqlContainer.with_user("test")
          |> MySqlContainer.with_password("test")
          |> MySqlContainer.with_reuse(true)
          |> (fn config ->
                if db_volume do
                  MySqlContainer.with_persistent_volume(config, db_volume)
                else
                  config
                end
              end).()

        {:ok, container} = Testcontainers.start_container(container_def)
        port = MySqlContainer.port(container)
        {container, create_env(port)}

      _ ->
        raise("Unsupported database: #{database}")
    end
  end

  defp create_env(port) do
    [
      {"DATABASE_URL", "ecto://test:test@#{Testcontainers.get_host()}:#{port}/test"}
    ]
  end

  defp with_env(env_kv, fun) when is_function(fun, 0) do
    Enum.each(env_kv, fn {k, v} -> System.put_env(k, v) end)
    fun.()
  end

  defp run_mix_task_in_process(sub_task, sub_task_args) do
    Mix.Task.clear()
    Mix.Task.reenable("local.hex")
    Mix.Task.reenable("local.rebar")
    Mix.Task.reenable(sub_task)
    Mix.Task.run(sub_task, sub_task_args)
  end

  defp maybe_bootstrap_tools do
    IO.puts("Bootstrapping Mix tasks...")
    safe_run_task("local.hex", ["--force"])
    safe_run_task("local.rebar", ["--force"])
  end

  defp safe_run_task(task, args) do
    try do
      Mix.Task.run(task, args)
    rescue
      _ -> :ok
    catch
      _, _ -> :ok
    end
  end

end
