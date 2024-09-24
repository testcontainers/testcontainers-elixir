# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.CommandWaitStrategy do
  @moduledoc """
  Considers a container ready as soon as a command runs successfully inside it.
  """

  @retry_delay 200
  @derive Nestru.Encoder
  defstruct [:command, :timeout, retry_delay: @retry_delay]

  # Public interface

  @doc """
  Creates a new CommandWaitStrategy.
  This strategy waits until the given command executes successfully inside the container.
  """
  def new(command, timeout \\ 5000, retry_delay \\ @retry_delay) do
    %__MODULE__{command: command, timeout: timeout, retry_delay: retry_delay}
  end

  # Private functions and implementations

  defimpl Testcontainers.WaitStrategy do
    alias Testcontainers.{Docker, Logger}

    @impl true
    def wait_until_container_is_ready(wait_strategy, container, conn) do
      started_at = get_current_time_millis()
      perform_recursive_wait(wait_strategy, container.container_id, conn, started_at)
    end

    # Main loop for waiting strategy
    defp perform_recursive_wait(wait_strategy, container_id, conn, started_at) do
      with {:ok, 0} <- execute_command_and_wait(wait_strategy, container_id, conn) do
        :ok
      else
        {:ok, exit_code} ->
          handle_non_zero_exit(wait_strategy, container_id, exit_code, conn, started_at)

        error ->
          handle_execution_error(error, wait_strategy)
      end
    end

    defp execute_command_and_wait(
           %{command: command, timeout: timeout, retry_delay: retry_delay},
           container_id,
           conn
         ) do
      with {:ok, exec_id} <- Docker.Api.start_exec(container_id, command, conn) do
        started_at = get_current_time_millis()
        wait_for_command_completion(exec_id, timeout, started_at, retry_delay, conn)
      end
    end

    defp handle_non_zero_exit(wait_strategy, container_id, exit_code, conn, started_at) do
      if timed_out?(started_at, wait_strategy.timeout) do
        {:error, strategy_timed_out(wait_strategy.timeout, started_at), wait_strategy}
      else
        log_retry_message(container_id, exit_code, wait_strategy.retry_delay)
        :timer.sleep(wait_strategy.retry_delay)
        perform_recursive_wait(wait_strategy, container_id, conn, started_at)
      end
    end

    defp handle_execution_error({:error, reason}, wait_strategy),
      do: {:error, reason, wait_strategy}

    defp wait_for_command_completion(exec_id, timeout, started_at, retry_delay, conn) do
      case Docker.Api.inspect_exec(exec_id, conn) do
        {:ok, %{running: true}} ->
          wait_unless_timeout(exec_id, timeout, started_at, retry_delay, conn)

        {:ok, exec_status} ->
          {:ok, exec_status.exit_code}
      end
    end

    defp wait_unless_timeout(exec_id, timeout, started_at, retry_delay, conn) do
      if timed_out?(started_at, timeout) do
        {:error, strategy_timed_out(timeout, started_at)}
      else
        :timer.sleep(retry_delay)
        wait_for_command_completion(exec_id, timeout, started_at, retry_delay, conn)
      end
    end

    defp get_current_time_millis(), do: System.monotonic_time(:millisecond)

    defp timed_out?(started_at, timeout), do: get_current_time_millis() - started_at > timeout

    defp strategy_timed_out(timeout, started_at) do
      {:command_wait_strategy, :timeout, timeout,
       elapsed_time: get_current_time_millis() - started_at}
    end

    defp log_retry_message(container_id, exit_code, delay) do
      Logger.log(
        "Command execution in container #{container_id} failed with exit_code #{exit_code}, retrying in #{delay}ms."
      )
    end
  end
end
