# SPDX-License-Identifier: MIT
defmodule Testcontainers.WaitStrategy.PortWaitStrategy do
  @moduledoc """
  Considers container as ready as soon as a command runs successfully inside the container.
  """
  defstruct [:ip, :port, :timeout]

  @doc """
  Creates a new CommandWaitStrategy to wait until the given command executes successfully inside the container.
  """
  def new(ip, port, timeout \\ 5000),
    do: %__MODULE__{ip: ip, port: port, timeout: timeout}
end

defimpl Testcontainers.WaitStrategy, for: Testcontainers.WaitStrategy.PortWaitStrategy do
  alias Testcontainers.Docker
  alias Testcontainers.Container

  @impl true
  def wait_until_container_is_ready(wait_strategy, id_or_name) do
    with {:ok, %Container{} = container} <- Docker.Api.get_container(id_or_name) do
      host_port = Container.mapped_port(container, wait_strategy.port)

      case wait_for_port(wait_strategy.ip, host_port, wait_strategy.timeout) do
        {:ok, :port_is_open} ->
          :ok

        _ ->
          :timer.sleep(100)
          wait_until_container_is_ready(wait_strategy, id_or_name)
      end
    end
  end

  def wait_for_port(ip, port, timeout \\ 1000)
      when is_binary(ip) and is_integer(port) and is_integer(timeout) do
    wait_for_port(ip, port, timeout, :os.system_time(:millisecond))
  end

  defp wait_for_port(ip, port, timeout, start_time)
       when is_binary(ip) and is_integer(port) and is_integer(timeout) and is_integer(start_time) do
    if timeout + start_time < :os.system_time(:millisecond) do
      {:error, :timeout}
    else
      if port_open?(ip, port) do
        {:ok, :port_is_open}
      else
        # Sleep for 500 ms, then retry
        :timer.sleep(500)
        wait_for_port(ip, port, timeout, start_time)
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
