# SPDX-License-Identifier: MIT
defmodule TestcontainersElixir.LogChecker do
  @moduledoc """
  A module for interacting and verifying logs of a Docker container.

  The main functionality is to wait until a specific log message,
  matching a provided regular expression, is emitted by a Docker container.
  """

  alias TestcontainersElixir.Docker

  @doc """
  Waits for a specific log message from a Docker container,
  identified by its `container_id`, within a specified `timeout` period.

  The function waits until a log message matching `log_regex`
  is found or until the `timeout` has expired, whichever comes first.

  ## Parameters

    - `container_id`: The ID (binary) of the Docker container to inspect the logs.
    - `log_regex`: A regular expression (binary) that is expected to be found in the logs.
    - `timeout`: (Optional) Time (integer, milliseconds) to wait for the log message. Default is 5000ms.

  ## Examples

      iex> TestcontainersElixir.LogChecker.wait_for_log(conn, "container_id", ~r/some pattern/)
      {:ok, :log_is_ready}

      iex> TestcontainersElixir.LogChecker.wait_for_log(conn, "container_id", ~r/some pattern/, 10000)
      {:error, :timeout}

  """
  def wait_for_log(container_id, log_regex, timeout \\ 5000)
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
    with {:ok, %{body: stdout_log}} <- Docker.Api.stdout_logs(container_id) do
      Regex.match?(log_regex, stdout_log)
    else
      _ ->
        false
    end
  end
end
