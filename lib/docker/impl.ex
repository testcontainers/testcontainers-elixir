defmodule Testcontainers.Docker.Impl do
  alias Testcontainers.Docker.Connection
  import Testcontainers.Docker.RequestBuilder

  def network_inspect(connection, id, opts \\ []) do
    optional_params = %{
      :verbose => :query,
      :scope => :query
    }

    request =
      %{}
      |> method(:get)
      |> url("/networks/#{id}")
      |> add_optional_params(optional_params, opts)
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {200, DockerEngineAPI.Model.Network},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end

  @doc """
  Inspect a container
  Return low-level information about a container.

  ### Parameters

  - `connection` (DockerEngineAPI.Connection): Connection to server
  - `id` (String.t): ID or name of the container
  - `opts` (keyword): Optional parameters
    - `:size` (boolean()): Return the size of container as fields `SizeRw` and `SizeRootFs`

  ### Returns

  - `{:ok, DockerEngineAPI.Model.ContainerInspectResponse.t}` on success
  - `{:error, Tesla.Env.t}` on failure
  """
  @spec container_inspect(Tesla.Env.client, String.t, keyword()) :: {:ok, DockerEngineAPI.Model.ContainerInspectResponse.t} | {:ok, DockerEngineAPI.Model.ErrorResponse.t} | {:error, Tesla.Env.t}
  def container_inspect(connection, id, opts \\ []) do
    optional_params = %{
      :size => :query
    }

    request =
      %{}
      |> method(:get)
      |> url("/containers/#{id}/json")
      |> add_optional_params(optional_params, opts)
      |> Enum.into([])

    connection
    |> Connection.request(request)
    |> evaluate_response([
      {200, DockerEngineAPI.Model.ContainerInspectResponse},
      {404, DockerEngineAPI.Model.ErrorResponse},
      {500, DockerEngineAPI.Model.ErrorResponse}
    ])
  end
end
