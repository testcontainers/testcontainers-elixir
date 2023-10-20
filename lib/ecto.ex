defmodule Testcontainers.Ecto do
  @moduledoc """
  Facilitates the creation of a Postgres container for testing with Ecto.

  This module simplifies the process of launching a real Postgres database instance within a Docker container for testing purposes. It leverages the `Testcontainers` library to instantiate a Postgres container with the desired configuration, providing an isolated database environment for each test session.
  """

  @doc """
  Initiates a new Postgres instance, executes migrations, and prepares a suitable database environment, specifically tailored for testing scenarios.

  ## Parameters

  - `options`: Configurations for the Postgres container, provided as a keyword list. The only required option is `:app`. Other options include:
    - `:app` - The current application's atom, necessary for building paths and other application-specific logic. This is a required parameter.
    - `:repo` (optional) - The Ecto repository module for database interaction. If not provided, it is inferred from the `:app` option using the default naming convention (e.g., `MyApp.Repo`).
    - `:image` (optional) - Specifies the Docker image for the Postgres container. This must be a legitimate Postgres image, with the image name beginning with "postgres". If omitted, the default is "postgres:15".
    - `:port` (optional) - Designates the host port for the Postgres service (defaults to 5432).
    - `:user` (optional) - Sets the username for the Postgres instance (defaults to "postgres").
    - `:password` (optional) - Determines the password for the Postgres user (defaults to "postgres").
    - `:database` (optional) - Specifies the name of the database to be created within the Postgres instance. If not provided, the default behavior is to create a database with the name derived from the application's atom, appended with "_test".
    - `:migrations_path` (optional) - Indicates the path to the migrations folder (defaults to "priv/repo/migrations").

  ## Database Lifecycle in Testing

  It's important to note that the Postgres database initiated by this macro will remain operational for the duration of the test process and is not explicitly shut down by the macro. The database and its corresponding data are ephemeral, lasting only for the scope of the test session.

  After the tests conclude, Testcontainers will clean up by removing the database container, ensuring no residual data persists. This approach helps maintain a clean testing environment and prevents any unintended side effects on subsequent tests due to data leftovers.

  Users should not rely on any manual teardown or cleanup for the database, as Testcontainers handles this aspect automatically, providing isolated, repeatable test runs.

  ## Examples

      # In your application.ex file in your Phoenix project:

      import Testcontainers.Ecto

      @impl true
      def start(_type, _args) do
        postgres_container(app: :my_app),

        # .. other setup code
      end

      # In mix.exs, modify the aliases to remove default Ecto setup tasks from the test alias,
      # as they might interfere with the container-based database setup:

      def aliases do
        [
          # ... other aliases

          # Ensure the following line is NOT present, as it would conflict with the container setup:
          # test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
        ]
      end

      # in your config/test.exs, if you want to keep appending the MIX_TEST_PARTITION env variable to the database name,
      # you must set the database option in postgres_container macro to the same value

      config :my_app, MyApp.Repo,
        username: "postgres",
        password: "postgres",
        hostname: "localhost",
        database: "my_app_test\#{System.get_env("MIX_TEST_PARTITION")}", # set this also in postgres_container macro database option, or remove the appending
        pool: Ecto.Adapters.SQL.Sandbox,
        pool_size: 10

      # for example, to set the database name to the one above, in application.ex:

      @impl true
      def start(_type, _args) do
        postgres_container(app: :my_app, database: "my_app_test\#{System.get_env("MIX_TEST_PARTITION")}"),

        # .. other setup code
      ]

  ## Returns

  - `:ok` if the container is initiated successfully.
  - `{:error, reason}` if there is a failure in initiating the container, with `reason` explaining the cause of the failure.

  ## Errors

  - Raises `ArgumentError` if the application is missing, not an atom, or not loaded.
  - Raises `ArgumentError` if the repo is defined and not an atom
  - Raises `ArgumentError` if the specified Docker image is not a valid Postgres image.

  ## Note

  This utility is intended for testing environments requiring a genuine database instance. It is not suitable for production use. It mandates a valid Postgres Docker image to maintain consistent and reliable testing conditions.
  """
  defmacro postgres_container(options \\ []) do
    alias Testcontainers.Container.PostgresContainer
    alias Testcontainers.Container
    import Testcontainers.ExUnit

    app = Keyword.get(options, :app)

    if app == nil or not is_atom(app) or
         Application.ensure_loaded(app) != :ok do
      raise ArgumentError,
            "Missing or ot an application: #{inspect(app)}"
    end

    repo = Keyword.get(options, :repo)

    if repo != nil and not is_atom(repo) do
      raise ArgumentError,
            "Not an atom: #{inspect(repo)}"
    end

    repo =
      if is_nil(repo) do
        repo_name = (app |> Atom.to_string() |> camelize()) <> ".Repo"
        Module.concat(Elixir, String.to_atom(repo_name))
      else
        repo
      end

    image = Keyword.get(options, :image, "postgres:15")

    if !String.starts_with?(image, "postgres") do
      raise ArgumentError,
            "The provided Docker image '#{image}' is not a recognized Postgres image."
    end

    host_port = Keyword.get(options, :port, 5432)
    user = Keyword.get(options, :user, "postgres")
    password = Keyword.get(options, :password, "postgres")
    database = Keyword.get(options, :database, "#{Atom.to_string(app)}_test")
    migrations_path = Keyword.get(options, :migrations_path, "priv/repo/migrations")

    quote do
      container =
        PostgresContainer.new(unquote(image))
        |> Container.with_fixed_port(unquote(host_port))
        |> PostgresContainer.with_user(unquote(user))
        |> PostgresContainer.with_password(unquote(password))
        |> PostgresContainer.with_database(unquote(database))

      case run_container(container, on_exit: nil) do
        {:ok, _} ->
          {:ok, pid} = unquote(repo).start_link()

          absolute_migrations_path =
            Application.app_dir(unquote(app), unquote(migrations_path))

          Ecto.Migrator.run(unquote(repo), absolute_migrations_path, :up, all: true)
          GenServer.stop(pid)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp camelize(string) do
    string
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join()
  end
end
