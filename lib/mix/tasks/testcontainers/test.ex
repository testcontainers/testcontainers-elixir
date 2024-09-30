defmodule Mix.Tasks.Testcontainers.Test do
  use Mix.Task
  alias Testcontainers.PostgresContainer
  alias Testcontainers.MySqlContainer

  @shortdoc "Runs tests with a Postgres container"
  def run(args) do
    Enum.each([:tesla, :hackney, :fs, :logger], fn app ->
      {:ok, _} = Application.ensure_all_started(app)
    end)

    {:ok, _} = Testcontainers.start_link()

    {opts, _, _} = OptionParser.parse(args,
      switches: [
        database: :string,
        watch: [:string, :keep]
      ]
    )

    database = opts[:database] || "postgres"
    folder_to_watch = Keyword.get_values(opts, :watch)

    if Enum.empty?(folder_to_watch) do
      IO.puts("No folders specified. Only running tests.")
      run_tests_and_exit(database)
    else
      check_folders_exist(folder_to_watch)
      run_tests_and_watch(database, folder_to_watch)
    end
  end

  defp check_folders_exist(folders) do
    Enum.each(folders, fn folder ->
      unless File.dir?(folder) do
        Mix.raise("Folder does not exist: #{folder}")
      end
    end)
  end

  defp run_tests_and_exit(database) do
    {container, env} = setup_container(database)
    run_tests(env)
    Testcontainers.stop_container(container)
  end

  defp run_tests_and_watch(database, folders) do
    {container, env} = setup_container(database)

    Enum.each(folders, fn folder ->
      :fs.start_link(String.to_atom("watcher_" <> folder), Path.absname(folder))
      :fs.subscribe(String.to_atom("watcher_" <> folder))
    end)

    Process.flag(:trap_exit, true)

    run_tests(env)
    loop(env, container)
  end

  defp setup_container(database) do
    case database do
      "postgres" ->
        {:ok, container} = Testcontainers.start_container(
          PostgresContainer.new()
          |> PostgresContainer.with_user("test")
          |> PostgresContainer.with_password("test")
          |> PostgresContainer.with_reuse(true)
        )
        port = PostgresContainer.port(container)
        {container, create_env(port)}
      "mysql" ->
        {:ok, container} = Testcontainers.start_container(
          MySqlContainer.new()
          |> MySqlContainer.with_user("test")
          |> MySqlContainer.with_password("test")
          |> MySqlContainer.with_reuse(true)
        )
        port = MySqlContainer.port(container)
        {container, create_env(port)}
      _ -> Mix.raise("Unsupported database: #{database}")
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

  defp run_tests(env) do
    test_pid = spawn(fn ->
      System.cmd("mix", ["test"], env: env, into: IO.stream(:stdio, :line))
    end)

    Process.monitor(test_pid)

    receive do
      {:DOWN, _ref, :process, ^test_pid, _reason} ->
        IO.puts("Test process completed.")
    end
  end

  defp loop(env, container) do
    receive do
      {_watcher_process, {:fs, :file_event}, {changed_file, _type}} ->
        IO.puts("#{changed_file} was updated, waiting for more changes...")
        wait_for_changes(env, container)

      after 5000 ->
        loop(env, container)
    end
  end

  defp wait_for_changes(env, container) do
    receive do
      {_watcher_process, {:fs, :file_event}, {changed_file, _type}} ->
        IO.puts("#{changed_file} was updated, waiting for more changes...")
        wait_for_changes(env, container)

    after 1000 ->
      IO.ANSI.clear()
      run_tests(env)
      loop(env, container)
    end
  end
end
