# NOTE: This file is auto generated by OpenAPI Generator 7.0.1 (https://openapi-generator.tech).
# Do not edit this file manually.

defmodule DockerEngineAPI.Api.Volume do
  @moduledoc """
  API calls for all endpoints tagged `Volume`.
  """

  alias DockerEngineAPI.Connection
  import DockerEngineAPI.RequestBuilder

  @doc """
  Create a volume

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `volume_config` (VolumeCreateOptions): Volume configuration
  - `opts` (keyword): Optional parameters

  ### Returns

  - `{:ok, DockerEngineAPI.Model.Volume.t}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec volume_create(Tesla.Env.client, DockerEngineAPI.Model.VolumeCreateOptions.t, keyword()) :: {:ok, DockerEngineAPI.Model.Volume.t} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def volume_create(connection, volume_config, _opts \\ []) do
    request =
      %{}
      |> method(:post)
      |> url("/volumes/create")
      |> add_param(:body, :body, volume_config)
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {201, DockerEngineAPI.Model.Volume},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Remove a volume
  Instruct the driver to remove the volume.

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `name` (String.t): Volume name or ID
  - `opts` (keyword): Optional parameters
    - `:force` (boolean()): Force the removal of the volume

  ### Returns

  - `{:ok, nil}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec volume_delete(Tesla.Env.client, String.t, keyword()) :: {:ok, nil} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def volume_delete(connection, name, opts \\ []) do
    optional_params = %{
      :force => :query
    }

    request =
      %{}
      |> method(:delete)
      |> url("/volumes/#{name}")
      |> add_optional_params(optional_params, opts)
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {204, false},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {409, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Inspect a volume

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `name` (String.t): Volume name or ID
  - `opts` (keyword): Optional parameters

  ### Returns

  - `{:ok, DockerEngineAPI.Model.Volume.t}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec volume_inspect(Tesla.Env.client, String.t, keyword()) :: {:ok, DockerEngineAPI.Model.Volume.t} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def volume_inspect(connection, name, _opts \\ []) do
    request =
      %{}
      |> method(:get)
      |> url("/volumes/#{name}")
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {200, DockerEngineAPI.Model.Volume},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  List volumes

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `opts` (keyword): Optional parameters
    - `:filters` (String.t): JSON encoded value of the filters (a `map[string][]string`) to process on the volumes list. Available filters:  - `dangling=<boolean>` When set to `true` (or `1`), returns all    volumes that are not in use by a container. When set to `false`    (or `0`), only volumes that are in use by one or more    containers are returned. - `driver=<volume-driver-name>` Matches volumes based on their driver. - `label=<key>` or `label=<key>:<value>` Matches volumes based on    the presence of a `label` alone or a `label` and a value. - `name=<volume-name>` Matches all or part of a volume name. 

  ### Returns

  - `{:ok, DockerEngineAPI.Model.VolumeListResponse.t}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec volume_list(Tesla.Env.client, keyword()) :: {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:ok, DockerEngineAPI.Model.VolumeListResponse.t} | {:error, Tesla.Env.t}
  def volume_list(connection, opts \\ []) do
    optional_params = %{
      :filters => :query
    }

    request =
      %{}
      |> method(:get)
      |> url("/volumes")
      |> add_optional_params(optional_params, opts)
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {200, DockerEngineAPI.Model.VolumeListResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Delete unused volumes

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `opts` (keyword): Optional parameters
    - `:filters` (String.t): Filters to process on the prune list, encoded as JSON (a `map[string][]string`).  Available filters: - `label` (`label=<key>`, `label=<key>=<value>`, `label!=<key>`, or `label!=<key>=<value>`) Prune volumes with (or without, in case `label!=...` is used) the specified labels. - `all` (`all=true`) - Consider all (local) volumes for pruning and not just anonymous volumes. 

  ### Returns

  - `{:ok, DockerEngineAPI.Model.VolumePruneResponse.t}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec volume_prune(Tesla.Env.client, keyword()) :: {:ok, DockerEngineAPI.Model.VolumePruneResponse.t} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def volume_prune(connection, opts \\ []) do
    optional_params = %{
      :filters => :query
    }

    request =
      %{}
      |> method(:post)
      |> url("/volumes/prune")
      |> add_optional_params(optional_params, opts)
      |> ensure_body()
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {200, DockerEngineAPI.Model.VolumePruneResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  \"Update a volume. Valid only for Swarm cluster volumes\" 

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `name` (String.t): The name or ID of the volume
  - `version` (integer()): The version number of the volume being updated. This is required to avoid conflicting writes. Found in the volume's `ClusterVolume` field. 
  - `opts` (keyword): Optional parameters
    - `:body` (VolumeUpdateRequest): The spec of the volume to update. Currently, only Availability may change. All other fields must remain unchanged. 

  ### Returns

  - `{:ok, nil}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec volume_update(Tesla.Env.client, String.t, integer(), keyword()) :: {:ok, nil} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def volume_update(connection, name, version, opts \\ []) do
    optional_params = %{
      :body => :body
    }

    request =
      %{}
      |> method(:put)
      |> url("/volumes/#{name}")
      |> add_param(:query, :version, version)
      |> add_optional_params(optional_params, opts)
      |> ensure_body()
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {200, false},
      {400, DockerEngineAPI.Model.ErrorResponse},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse},
      {503, DockerEngineAPI.Model.ErrorResponse}
    ])
  end
end
