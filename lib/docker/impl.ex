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
end
