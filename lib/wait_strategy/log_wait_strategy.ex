# SPDX-License-Identifier: MIT
defmodule Testcontainers.LogWaitStrategy do
  @moduledoc """
  Considers the container as ready as soon as a specific log message is detected in the container's log stream.
  """

  @retry_delay 500
  @derive Nestru.Encoder
  defstruct [:log_regex, :timeout, retry_delay: @retry_delay]

  # Public interface

  @doc """
  Creates a new LogWaitStrategy.
  This strategy waits until a specific log message, matching the provided regex, appears in the container's log.
  """
  def new(log_regex, timeout \\ 5000, retry_delay \\ @retry_delay) do
    %__MODULE__{log_regex: log_regex, timeout: timeout, retry_delay: retry_delay}
  end

  # Private functions and implementations

  defimpl Testcontainers.WaitStrategy do
    alias Testcontainers.{Docker, Logger}

    @impl true
    def wait_until_container_is_ready(wait_strategy, container, conn) do
      started_at = get_current_time_millis()
      wait_for_log_message(wait_strategy, container.container_id, conn, started_at)
    end

    # Main loop for waiting strategy
    defp wait_for_log_message(wait_strategy, container_id, conn, start_time) do
      if reached_timeout?(start_time, wait_strategy.timeout) do
        {:error, strategy_timed_out(wait_strategy.timeout, start_time), wait_strategy}
      else
        process_log(wait_strategy, container_id, conn, start_time)
      end
    end

    defp process_log(wait_strategy, container_id, conn, start_time) do
      case log_matches?(container_id, wait_strategy.log_regex, conn) do
        true ->
          :ok

        false ->
          log_retry_message(container_id, wait_strategy.log_regex, wait_strategy.retry_delay)
          :timer.sleep(wait_strategy.retry_delay)
          wait_for_log_message(wait_strategy, container_id, conn, start_time)
      end
    end

    defp log_matches?(container_id, log_regex, conn) do
      with {:ok, log_output} <- Docker.Api.stdout_logs(container_id, conn) do
        Regex.match?(log_regex, log_output)
      else
        _ -> false
      end
    end

    defp get_current_time_millis(), do: System.monotonic_time(:millisecond)

    defp reached_timeout?(start_time, timeout),
      do: get_current_time_millis() - start_time > timeout

    defp strategy_timed_out(timeout, start_time) do
      {:log_wait_strategy, :timeout, timeout,
       elapsed_time: get_current_time_millis() - start_time}
    end

    defp log_retry_message(container_id, log_regex, delay) do
      Logger.log(
        "Logs in container #{container_id} didn't match regex #{inspect(log_regex)}, retrying in #{delay}ms."
      )
    end
  end
end
