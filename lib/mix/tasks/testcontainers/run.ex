defmodule Mix.Tasks.Testcontainers.Run do
  use Mix.Task
  alias Testcontainers.PostgresContainer
  alias Testcontainers.MySqlContainer

  @shortdoc "Runs a Mix sub-task (test, phx.server, etc) with a database container"
  @moduledoc """
  Usage:
    mix testcontainers.run [sub_task] [--database DB] [--watch folder] [sub_task_args...]

  Examples:
    mix testcontainers.run test --database postgres
    mix testcontainers.run phx.server --database mysql
    mix testcontainers.run test --watch lib --watch test
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
          watch: [:string, :keep]
        ]
      )

    database = opts[:database] || "postgres"
    folder_to_watch = Keyword.get_values(opts, :watch)

    # Determine sub_task and its args
    {sub_task, sub_task_args} =
      case rest_args do
        [task | tail] -> {task, tail}
        [] -> {"test", []}
      end

    if Enum.empty?(folder_to_watch) do
      IO.puts("No folders specified. Only running subtask '#{sub_task}'.")
      run_sub_task_and_exit(database, sub_task, sub_task_args)
    else
      check_folders_exist(folder_to_watch)
      run_sub_task_and_watch(database, sub_task, sub_task_args, folder_to_watch)
    end
  end

  defp check_folders_exist(folders) do
    Enum.each(folders, fn folder ->
      unless File.dir?(folder) do
        raise("Folder does not exist: #{folder}")
      end
    end)
  end

  @spec run_sub_task_and_exit(String.t(), String.t(), list(String.t())) :: no_return()
  defp run_sub_task_and_exit(database, sub_task, sub_task_args) do
    {container, env} = setup_container(database)
    exit_code = run_mix_task(env, sub_task, sub_task_args)
    Testcontainers.stop_container(container.container_id)
    System.halt(exit_code)
  end

  defp run_sub_task_and_watch(database, sub_task, sub_task_args, folders) do
    {container, env} = setup_container(database)

    Enum.each(folders, fn folder ->
      :fs.start_link(String.to_atom("watcher_" <> folder), Path.absname(folder))
      :fs.subscribe(String.to_atom("watcher_" <> folder))
    end)

    run_mix_task(env, sub_task, sub_task_args)
    loop(env, sub_task, sub_task_args, container)
  end

  defp setup_container(database) do
    case database do
      "postgres" ->
        {:ok, container} =
          Testcontainers.start_container(
            PostgresContainer.new()
            |> PostgresContainer.with_user("test")
            |> PostgresContainer.with_password("test")
            |> PostgresContainer.with_reuse(true)
          )

        port = PostgresContainer.port(container)
        {container, create_env(port)}

      "mysql" ->
        {:ok, container} =
          Testcontainers.start_container(
            MySqlContainer.new()
            |> MySqlContainer.with_user("test")
            |> MySqlContainer.with_password("test")
            |> MySqlContainer.with_reuse(true)
          )

        port = MySqlContainer.port(container)
        {container, create_env(port)}

      _ ->
        raise("Unsupported database: #{database}")
    end
  end

  defp create_env(port) do
    [
      {"DB_USER", "test"},
      {"DB_PASSWORD", "test"},
      {"DB_HOST", Testcontainers.get_host()},
      {"DB_PORT", Integer.to_string(port)}
    ]
  end

  defp run_mix_task(env, sub_task, sub_task_args) do
    case System.cmd("mix", [sub_task] ++ sub_task_args,
           env: env,
           into: IO.stream(),
           stderr_to_stdout: false
         ) do
      {_, exit_code} ->
        if exit_code == 0 do
          IO.puts("Task '#{sub_task}' completed successfully")
        else
          IO.puts(:stderr, "Mix task '#{sub_task}' failed with exit code: #{exit_code}")
        end
        exit_code
    end
  end

  defp loop(env, sub_task, sub_task_args, container) do
    receive do
      {_watcher_process, {:fs, :file_event}, {changed_file, _type}} ->
        IO.puts("#{changed_file} was updated, waiting for more changes...")
        wait_for_changes(env, sub_task, sub_task_args, container)
    after
      5000 ->
        loop(env, sub_task, sub_task_args, container)
    end
  end

  defp wait_for_changes(env, sub_task, sub_task_args, container) do
    receive do
      {_watcher_process, {:fs, :file_event}, {changed_file, _type}} ->
        IO.puts("#{changed_file} was updated, waiting for more changes...")
        wait_for_changes(env, sub_task, sub_task_args, container)
    after
      1000 ->
        IO.ANSI.clear()
        run_mix_task(env, sub_task, sub_task_args)
        loop(env, sub_task, sub_task_args, container)
    end
  end
end
