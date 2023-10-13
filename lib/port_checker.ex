# SPDX-License-Identifier: Apache-2.0
defmodule TestcontainersElixir.PortChecker do
  def wait_for_port(ip, port, timeout \\ 1000) do
    wait_for_port(ip, port, timeout, :os.system_time(:millisecond))
  end

  defp wait_for_port(ip, port, timeout, start_time) do
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

  defp port_open?(ip, port, timeout \\ 1000) do
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
