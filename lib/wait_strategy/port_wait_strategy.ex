# SPDX-License-Identifier: MIT
defmodule Testcontainers.WaitStrategy.PortWaitStrategy do
  @moduledoc """
  Considers the container as ready when it successfully accepts connections on the specified port.
  """

  @retry_delay 200

  defstruct [:ip, :port, :timeout, retry_delay: @retry_delay]

  @doc """
  Creates a new PortWaitStrategy to wait until a specified port is open and accepting connections.
  """
  def new(ip, port, timeout \\ 5000, retry_delay \\ @retry_delay),
    do: %__MODULE__{ip: ip, port: port, timeout: timeout, retry_delay: retry_delay}
end

defimpl Testcontainers.WaitStrategy, for: Testcontainers.WaitStrategy.PortWaitStrategy do
  alias Testcontainers.Docker
  alias Testcontainers.Container

  require Logger

  def wait_until_container_is_ready(wait_strategy, id_or_name) do
    with {:ok, %Container{} = container} <- Docker.Api.get_container(id_or_name) do
      host_port = Container.mapped_port(container, wait_strategy.port)

      if host_port == nil do
        {:error, {:no_host_port, wait_strategy.port}}
      else
        start_time = :os.system_time(:millisecond)

        case wait_for_port(wait_strategy, host_port, start_time) do
          {:ok, :port_is_open} ->
            :ok

          {:error, reason} ->
            {:error, reason, wait_strategy}
        end
      end
    end
  end

  defp wait_for_port(wait_strategy, host_port, start_time)
       when is_integer(host_port) and is_integer(start_time) do
    if wait_strategy.timeout + start_time < :os.system_time(:millisecond) do
      {:error,
       {:port_wait_strategy, :timeout, wait_strategy.timeout,
        elapsed_time: :os.system_time(:millisecond) - start_time}}
    else
      if port_open?(wait_strategy.ip, host_port) do
        {:ok, :port_is_open}
      else
        delay = max(0, wait_strategy.retry_delay)

        Logger.debug(
          "Port #{wait_strategy.port} not open on IP #{wait_strategy.ip}, retrying in #{delay}ms."
        )

        :timer.sleep(delay)
        wait_for_port(wait_strategy, host_port, start_time)
      end
    end
  end

  defp port_open?(ip, port, timeout \\ 1000)
       when is_binary(ip) and is_integer(port) and is_integer(timeout) do
    case :gen_tcp.connect(~c"#{ip}", port, [:binary, active: false], timeout) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true

      {:error, _reason} ->
        false
    end
  end
end
