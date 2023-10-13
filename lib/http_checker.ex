# SPDX-License-Identifier: Apache-2.0
defmodule TestcontainersElixir.HttpChecker do
  @doc """
  Waits for HTTP to be ready at the specified IP and port.

  ## Params:
  - ip: The IP address as a string.
  - port: The port number as an integer.
  - path: The HTTP path as a string.
  - timeout: The maximum time to wait (in milliseconds) as an integer.
  """
  def wait_for_http(ip, port, path \\ "/", timeout \\ 5000)
      when is_binary(ip) and is_integer(port) and is_binary(path) and is_integer(timeout) do
    wait_for_http(ip, port, path, timeout, :os.system_time(:millisecond))
  end

  defp wait_for_http(ip, port, path, timeout, start_time)
       when is_binary(ip) and is_integer(port) and is_binary(path) and is_integer(timeout) and
              is_integer(start_time) do
    if timeout + start_time < :os.system_time(:millisecond) do
      {:error, :timeout}
    else
      case http_request(ip, port, path) do
        {:ok, _response} ->
          {:ok, :http_is_ready}

        {:error, _reason} ->
          # Sleep for 500 ms, then retry
          :timer.sleep(500)
          wait_for_http(ip, port, path, timeout, start_time)
      end
    end
  end

  defp http_request(ip, port, path) do
    url = "http://" <> ip <> ":" <> Integer.to_string(port) <> path

    case :httpc.request(:get, {to_charlist(url), []}, [], []) do
      {:ok, {{~c"HTTP/1.1", 200, _reason_phrase}, _headers, _body}} ->
        {:ok, :http_ok}

      {:ok, {{~c"HTTP/1.1", status_code, _reason_phrase}, _headers, _body}}
      when status_code != 200 ->
        {:error, {:unexpected_status_code, status_code}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
