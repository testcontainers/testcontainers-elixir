# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.WaitStrategy.CommandWaitStrategy do
  @moduledoc """
  Considers container as ready as soon as a command runs successfully inside the container.
  """

  @retry_delay 200

  defstruct [:command, :timeout, retry_delay: @retry_delay]

  @doc """
  Creates a new CommandWaitStrategy to wait until the given command executes successfully inside the container.
  """
  def new(command, timeout \\ 5000, retry_delay \\ @retry_delay),
    do: %__MODULE__{command: command, timeout: timeout, retry_delay: retry_delay}
end

defimpl Testcontainers.WaitStrategy,
  for: Testcontainers.WaitStrategy.CommandWaitStrategy do
  alias Testcontainers.Docker.Exec

  require Logger

  def wait_until_container_is_ready(wait_strategy, id_or_name) do
    # Capture the start time of the process
    started_at = current_time_millis()

    # Call the recursive function
    recursive_wait(wait_strategy, id_or_name, started_at)
  end

  # Recursive function with breaking conditions
  defp recursive_wait(wait_strategy, id_or_name, started_at) do
    case exec_and_wait(
           id_or_name,
           wait_strategy.command,
           wait_strategy.timeout,
           wait_strategy.retry_delay
         ) do
      {:ok, 0} ->
        :ok

      {:ok, other_exit_code} ->
        if out_of_time(started_at, wait_strategy.timeout) do
          {:error,
           {:command_wait_strategy, :timeout, wait_strategy.timeout,
            elapsed_time: current_time_millis() - started_at}, wait_strategy}
        else
          delay = max(0, wait_strategy.retry_delay)

          Logger.debug(
            "Command execution in container #{id_or_name} failed with exit_code #{other_exit_code}, retrying in #{delay}ms."
          )

          :timer.sleep(delay)
          recursive_wait(wait_strategy, id_or_name, started_at)
        end

      {:error, reason} ->
        {:error, reason, wait_strategy}
    end
  end

  def exec_and_wait(container_id, command, timeout, retry_delay) do
    {:ok, exec_id} = exec(container_id, command)

    started_at = current_time_millis()

    case wait_for_exec_result(exec_id, timeout, started_at, retry_delay) do
      {:ok, exec_info} -> {:ok, exec_info.exit_code}
      {:error, error} -> {:error, error}
    end
  end

  def exec(container_id, command) do
    with {:ok, exec_id} <- Exec.create(container_id, command),
         :ok <- Exec.start(exec_id) do
      {:ok, exec_id}
    end
  end

  defp wait_for_exec_result(
         exec_id,
         timeout_ms,
         started_at,
         retry_delay
       ) do
    case Exec.inspect(exec_id) do
      {:ok, %{running: true}} ->
        do_wait_unless_timed_out(exec_id, timeout_ms, started_at, retry_delay)

      {:ok, finished_exec_status} ->
        {:ok, finished_exec_status}
    end
  end

  defp do_wait_unless_timed_out(exec_id, timeout, started_at, retry_delay) do
    if out_of_time(started_at, timeout) do
      {:error, {:command_wait_strategy, :timeout, timeout, elapsed_time: current_time_millis() - started_at}}
    else
      delay = max(0, retry_delay)
      :timer.sleep(delay)
      wait_for_exec_result(exec_id, timeout, started_at, retry_delay)
    end
  end

  defp current_time_millis, do: System.monotonic_time(:millisecond)

  defp out_of_time(started_at, timeout_ms), do: current_time_millis() - started_at > timeout_ms
end
