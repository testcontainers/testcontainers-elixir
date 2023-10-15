defmodule Testcontainers.Docker.Exec do
  @moduledoc false

  alias Testcontainers.Docker.Connection

  def inspect(exec_id, options \\ []) do
    conn = Connection.get_connection(options)

    case DockerEngineAPI.Api.Exec.exec_inspect(conn, exec_id) do
      {:ok, %DockerEngineAPI.Model.ExecInspectResponse{} = body} ->
        {:ok, parse_inspect_result(body)}

      {:ok, %Tesla.Env{status: status}} ->
        {:error, {:http_error, status}}

      {:error, message} ->
        {:error, message}
    end
  end

  def create(container_id, command, options \\ []) do
    data = %{"Cmd" => command}
    conn = Connection.get_connection(options)

    case DockerEngineAPI.Api.Exec.container_exec(conn, container_id, data) do
      {:ok, %DockerEngineAPI.Model.IdResponse{Id: id}} -> {:ok, id}
      {:ok, %Tesla.Env{status: status}} -> {:error, {:http_error, status}}
      {:error, message} -> {:error, message}
    end
  end

  def start(exec_id, options \\ []) do
    conn = Connection.get_connection(options)

    case DockerEngineAPI.Api.Exec.exec_start(conn, exec_id, body: %{}) do
      {:ok, %Tesla.Env{status: 200}} -> :ok
      {:ok, %Tesla.Env{status: status}} -> {:error, {:http_error, status}}
      {:error, message} -> {:error, message}
    end
  end

  def stdout_logs(container_id, options \\ []) do
    conn = Connection.get_connection(options)

    case DockerEngineAPI.Api.Container.container_logs(conn, container_id, stdout: true) do
      {:ok, %Tesla.Env{body: body}} -> {:ok, body}
      {:error, message} -> {:error, message}
    end
  end

  defp parse_inspect_result(%DockerEngineAPI.Model.ExecInspectResponse{} = json) do
    %{running: json."Running", exit_code: json."ExitCode"}
  end
end
