# SPDX-License-Identifier: MIT
defmodule Testcontainers.WaitStrategy.LogWaitStrategy do
  @moduledoc """
  Considers the container as ready as soon as a specific log message is detected in the container's log stream.
  """

  @retry_delay 500

  defstruct [:log_regex, :timeout, retry_delay: @retry_delay]

  @doc """
  Creates a new LogWaitStrategy to wait until a specific log message, matching the provided regex, appears in the container's log.
  """
  def new(log_regex, timeout \\ 5000, retry_delay \\ @retry_delay),
    do: %__MODULE__{log_regex: log_regex, timeout: timeout, retry_delay: retry_delay}
end

defimpl Testcontainers.WaitStrategy, for: Testcontainers.WaitStrategy.LogWaitStrategy do
  alias Testcontainers.Docker

  require Logger

  def wait_until_container_is_ready(wait_strategy, id_or_name) do
    case wait_for_log(
           id_or_name,
           wait_strategy,
           :os.system_time(:millisecond)
         ) do
      {:ok, :log_is_ready} ->
        :ok

      {:error, reason} ->
        {:error, reason, wait_strategy}
    end
  end

  defp wait_for_log(container_id, wait_strategy, start_time)
       when is_binary(container_id) and is_integer(wait_strategy.timeout) and
              is_integer(start_time) do
    if wait_strategy.timeout + start_time < :os.system_time(:millisecond) do
      {:error, {:log_wait_strategy, :timeout, wait_strategy.timeout}}
    else
      if log_comparison(container_id, wait_strategy.log_regex) do
        {:ok, :log_is_ready}
      else
        delay = max(0, wait_strategy.retry_delay)

        Logger.debug(
          "Logs in container #{container_id} didnt match regex #{inspect(wait_strategy.log_regex)}, retrying in #{delay}ms."
        )

        :timer.sleep(delay)
        wait_for_log(container_id, wait_strategy, start_time)
      end
    end
  end

  defp log_comparison(container_id, log_regex) do
    case Docker.Exec.stdout_logs(container_id) do
      {:ok, stdout_log} when is_binary(stdout_log) ->
        Regex.match?(log_regex, stdout_log)

      _ ->
        false
    end
  end
end
