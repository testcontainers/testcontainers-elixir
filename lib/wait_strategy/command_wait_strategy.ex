# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.WaitStrategy.CommandWaitStrategy do
  @moduledoc """
  Considers container as ready as soon as a command runs successfully inside the container.
  """
  defstruct [:command]

  @doc """
  Creates a new CommandWaitStrategy to wait until the given command executes successfully inside the container.
  """
  def new(command), do: %__MODULE__{command: command}
end

defimpl Testcontainers.WaitStrategy,
  for: Testcontainers.WaitStrategy.CommandWaitStrategy do
  alias Testcontainers.Docker.Exec

  def wait_until_container_is_ready(wait_strategy, id_or_name) do
    case exec_and_wait(id_or_name, wait_strategy.command) do
      {:ok, {0, _stdout}} ->
        :ok

      _ ->
        :timer.sleep(100)
        wait_until_container_is_ready(wait_strategy, id_or_name)
    end
  end

  def exec_and_wait(container_id, command, options \\ []) do
    timeout_ms = options[:timeout_ms]

    {:ok, exec_id} = exec(container_id, command)

    case wait_for_exec_result(exec_id, timeout_ms) do
      {:ok, exec_info} -> {:ok, {exec_info.exit_code, ""}}
      {:error, :timeout} -> {:error, :timeout}
    end
  end

  def exec(container_id, command) do
    {:ok, exec_id} = Exec.create(container_id, command)
    :ok = Exec.start(exec_id)

    {:ok, exec_id}
  end

  defp wait_for_exec_result(exec_id, timeout_ms, started_at \\ monotonic_time()) do
    case Exec.inspect(exec_id) do
      {:ok, %{running: true}} -> do_wait_unless_timed_out(exec_id, timeout_ms, started_at)
      {:ok, finished_exec_status} -> {:ok, finished_exec_status}
    end
  end

  defp do_wait_unless_timed_out(exec_id, timeout_ms, started_at) do
    if out_of_time(started_at, timeout_ms) do
      {:error, {:command_wait_strategy, :timeout}}
    else
      :timer.sleep(100)
      wait_for_exec_result(exec_id, timeout_ms, started_at)
    end
  end

  defp monotonic_time, do: System.monotonic_time(:millisecond)

  defp out_of_time(started_at, timeout_ms), do: monotonic_time() - started_at > timeout_ms
end
