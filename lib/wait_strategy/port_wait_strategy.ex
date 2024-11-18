# SPDX-License-Identifier: MIT
defmodule Testcontainers.PortWaitStrategy do
  @moduledoc """
  Considers the container as ready when it successfully accepts connections on the specified port.
  """

  require Logger

  @retry_delay 200
  defstruct [:ip, :port, :timeout, retry_delay: @retry_delay]

  # Public interface

  @doc """
  Creates a new PortWaitStrategy to wait until a specified port is open and accepting connections.
  """
  def new(ip, port, timeout \\ 5000, retry_delay \\ @retry_delay) do
    %__MODULE__{ip: ip, port: port, timeout: timeout, retry_delay: retry_delay}
  end

  # Private functions and implementations

  defimpl Testcontainers.WaitStrategy do
    alias Testcontainers.Container

    @impl true
    def wait_until_container_is_ready(wait_strategy, container, _conn) do
      with host_port when not is_nil(host_port) <-
             Container.mapped_port(container, wait_strategy.port),
           do: perform_port_check(wait_strategy, host_port)
    end

    defp perform_port_check(wait_strategy, host_port) do
      started_at = current_time_millis()

      case wait_for_open_port(wait_strategy, host_port, started_at) do
        :port_is_open ->
          :ok

        {:error, reason} ->
          {:error, reason, wait_strategy}
      end
    end

    defp wait_for_open_port(wait_strategy, host_port, start_time) do
      if reached_timeout?(wait_strategy.timeout, start_time) do
        {:error, strategy_timed_out(wait_strategy.timeout, start_time)}
      else
        check_port_status(wait_strategy, host_port, start_time)
      end
    end

    defp check_port_status(wait_strategy, host_port, start_time) do
      if port_open?(wait_strategy.ip, host_port) do
        :port_is_open
      else
        log_retry_message(wait_strategy, host_port)
        :timer.sleep(wait_strategy.retry_delay)
        wait_for_open_port(wait_strategy, host_port, start_time)
      end
    end

    defp port_open?(ip, port, timeout \\ 1000) do
      case :gen_tcp.connect(to_charlist(ip), port, [:binary, active: false], timeout) do
        {:ok, socket} ->
          :gen_tcp.close(socket)
          true

        {:error, _} ->
          false
      end
    end

    defp current_time_millis(), do: System.monotonic_time(:millisecond)

    defp reached_timeout?(timeout, start_time), do: current_time_millis() - start_time > timeout

    defp strategy_timed_out(timeout, start_time) do
      {:port_wait_strategy, :timeout, timeout, elapsed_time: current_time_millis() - start_time}
    end

    defp log_retry_message(wait_strategy, host_port) do
      Logger.debug(
        "Port #{wait_strategy.port} (host port #{host_port}) not open on IP #{wait_strategy.ip}, retrying in #{wait_strategy.retry_delay}ms."
      )
    end
  end
end
