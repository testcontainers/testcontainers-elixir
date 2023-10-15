# SPDX-License-Identifier: MIT
defmodule Testcontainers.WaitStrategy.LogWaitStrategy do
  @moduledoc """
  Considers container as ready as soon as a command runs successfully inside the container.
  """
  defstruct [:log_regex, :timeout]

  @doc """
  Creates a new CommandWaitStrategy to wait until the given command executes successfully inside the container.
  """
  def new(log_regex, timeout \\ 5000),
    do: %__MODULE__{log_regex: log_regex, timeout: timeout}
end

defimpl Testcontainers.WaitStrategy, for: Testcontainers.WaitStrategy.LogWaitStrategy do
  alias Testcontainers.Docker

  @impl true
  def wait_until_container_is_ready(wait_strategy, id_or_name) do
    case wait_for_log(id_or_name, wait_strategy.log_regex, wait_strategy.timeout) do
      {:ok, :log_is_ready} ->
        :ok

      _ ->
        :timer.sleep(100)
        wait_until_container_is_ready(wait_strategy, id_or_name)
    end
  end

  def wait_for_log(container_id, log_regex, timeout)
      when is_binary(container_id) and is_integer(timeout) do
    wait_for_log(
      container_id,
      log_regex,
      timeout,
      :os.system_time(:millisecond)
    )
  end

  defp wait_for_log(container_id, log_regex, timeout, start_time)
       when is_binary(container_id) and is_integer(timeout) and is_integer(start_time) do
    if timeout + start_time < :os.system_time(:millisecond) do
      {:error, :timeout}
    else
      if log_comparison(container_id, log_regex) do
        {:ok, :log_is_ready}
      else
        # Sleep for 500 ms, then retry
        :timer.sleep(500)
        wait_for_log(container_id, log_regex, timeout, start_time)
      end
    end
  end

  defp log_comparison(container_id, log_regex) do
    with {:ok, stdout_log} when is_binary(stdout_log) <-
           Docker.Exec.stdout_logs(container_id) do
      Regex.match?(log_regex, stdout_log)
    else
      _ ->
        false
    end
  end
end
