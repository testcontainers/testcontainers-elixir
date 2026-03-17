defmodule Testcontainers.DockerCompose do
  @moduledoc """
  A struct with builder functions for creating a Docker Compose configuration.
  """

  defstruct [
    :filepath,
    compose_files: [],
    project_name: nil,
    env: %{},
    wait_strategies: %{},
    wait_timeout: 120_000,
    pull: :missing,
    services: [],
    build: false,
    profiles: [],
    remove_volumes: true
  ]

  @doc """
  Creates a new DockerCompose configuration.

  The `filepath` can be a path to a directory containing a docker-compose.yml file,
  or a path to a specific compose file.
  """
  def new(filepath) when is_binary(filepath) do
    %__MODULE__{
      filepath: filepath,
      project_name: generate_project_name()
    }
  end

  @doc """
  Sets an environment variable for the compose environment.
  """
  def with_env(%__MODULE__{} = config, key, value)
      when (is_binary(key) or is_atom(key)) and is_binary(value) do
    %__MODULE__{config | env: Map.put(config.env, to_string(key), value)}
  end

  @doc """
  Sets a wait strategy for a specific service.
  """
  def with_wait_strategy(%__MODULE__{} = config, service_name, wait_strategy)
      when is_binary(service_name) and is_struct(wait_strategy) do
    strategies = Map.get(config.wait_strategies, service_name, [])

    %__MODULE__{
      config
      | wait_strategies:
          Map.put(config.wait_strategies, service_name, [wait_strategy | strategies])
    }
  end

  @doc """
  Sets the specific services to start. If empty, all services are started.
  """
  def with_services(%__MODULE__{} = config, services) when is_list(services) do
    %__MODULE__{config | services: services}
  end

  @doc """
  Sets whether to build images before starting containers.
  """
  def with_build(%__MODULE__{} = config, build) when is_boolean(build) do
    %__MODULE__{config | build: build}
  end

  @doc """
  Adds a profile to enable when starting compose.
  """
  def with_profile(%__MODULE__{} = config, profile) when is_binary(profile) do
    %__MODULE__{config | profiles: [profile | config.profiles]}
  end

  @doc """
  Sets the pull policy for compose services.
  """
  def with_pull(%__MODULE__{} = config, pull) when pull in [:always, :missing, :never] do
    %__MODULE__{config | pull: pull}
  end

  @doc """
  Sets whether to remove volumes when stopping compose.
  """
  def with_remove_volumes(%__MODULE__{} = config, remove_volumes)
      when is_boolean(remove_volumes) do
    %__MODULE__{config | remove_volumes: remove_volumes}
  end

  @doc """
  Sets the wait timeout in milliseconds.
  """
  def with_wait_timeout(%__MODULE__{} = config, timeout)
      when is_integer(timeout) and timeout > 0 do
    %__MODULE__{config | wait_timeout: timeout}
  end

  @doc """
  Sets the project name for the compose environment.
  """
  def with_project_name(%__MODULE__{} = config, project_name) when is_binary(project_name) do
    %__MODULE__{config | project_name: project_name}
  end

  @doc """
  Adds additional compose files to use with the -f flag.
  """
  def with_compose_file(%__MODULE__{} = config, file) when is_binary(file) do
    %__MODULE__{config | compose_files: config.compose_files ++ [file]}
  end

  defp generate_project_name do
    hex =
      :crypto.strong_rand_bytes(8)
      |> Base.encode16(case: :lower)
      |> binary_part(0, 12)

    "tc-#{hex}"
  end
end
