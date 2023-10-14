# SPDX-License-Identifier: MIT
defmodule TestcontainersElixir.WaitStrategy.HttpWaitStrategy do
  @moduledoc """
  Considers container as ready as soon as a command runs successfully inside the container.
  """
  defstruct [:ip, :port, :path, :timeout]

  @doc """
  Creates a new CommandWaitStrategy to wait until the given command executes successfully inside the container.
  """
  def new(ip, port, path \\ "/", timeout \\ 5000),
    do: %__MODULE__{ip: ip, port: port, path: path, timeout: timeout}
end

defimpl TestcontainersElixir.WaitStrategy, for: TestcontainersElixir.WaitStrategy.HttpWaitStrategy do
  alias TestcontainersElixir.Container
  alias TestcontainersElixir.Docker

  @impl true
  def wait_until_container_is_ready(wait_strategy, id_or_name) do
    with {:ok, %Container{} = container} <- Docker.Api.get_container(id_or_name) do
      host_port = Container.mapped_port(container, wait_strategy.port)

      case wait_for_http(wait_strategy.ip, host_port, wait_strategy.path, wait_strategy.timeout) do
        {:ok, :http_is_ready} ->
          :ok

        _ ->
          :timer.sleep(100)
          wait_until_container_is_ready(wait_strategy, id_or_name)
      end
    end
  end

  defp wait_for_http(ip, port, path, timeout)
       when is_binary(ip) and is_integer(port) and is_binary(path) and is_integer(timeout) do
    wait_for_http(ip, port, path, timeout, :os.system_time(:millisecond))
  end

  defp wait_for_http(ip, port, path, timeout, start_time)
       when is_binary(ip) and is_integer(port) and is_binary(path) and is_integer(timeout) and
              is_integer(start_time) do
    if timeout + start_time < :os.system_time(:millisecond) do
      {:error, :timeout}
    else
      case http_request(ip, port, path) do
        {:ok, _response} ->
          {:ok, :http_is_ready}

        {:error, _reason} ->
          # Sleep for 500 ms, then retry
          :timer.sleep(500)
          wait_for_http(ip, port, path, timeout, start_time)
      end
    end
  end

  defp http_request(ip, port, path) do
    url = "http://" <> ip <> ":" <> Integer.to_string(port) <> path

    case :httpc.request(:get, {to_charlist(url), []}, [], []) do
      {:ok, {{~c"HTTP/1.1", 200, _reason_phrase}, _headers, _body}} ->
        {:ok, :http_ok}

      {:ok, {{~c"HTTP/1.1", status_code, _reason_phrase}, _headers, _body}}
      when status_code != 200 ->
        {:error, {:unexpected_status_code, status_code}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
