# SPDX-License-Identifier: Apache-2.0
defmodule TestcontainersElixir.PortChecker do
  @moduledoc """
  A utility module for checking the readiness of a TCP service on a given IP and port.

  `TestcontainersElixir.PortChecker` provides functionality to wait until a TCP port
  is open on a specified IP address, up to a provided timeout.

  It is important to note that having a port open does not guarantee that
  the associated service is fully ready to accept requests, just that the service
  is reachable at the network level.
  """

  @doc """
  Waits for the specified IP and port the be open.

  ## Params:
  - ip: The IP address as a string.
  - port: The port number as an integer.
  - timeout: The maximum time to wait (in milliseconds) as an integer.
  """
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
    IO.inspect("checking port #{port}")

    case :gen_tcp.connect(~c"#{ip}", port, [:binary, active: false], timeout) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true

      {:error, _reason} ->
        false
    end
  end
end
