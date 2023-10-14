# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule TestcontainersElixir.Reaper do
  alias TestcontainersElixir.Docker
  alias TestcontainersElixir.Container

  @ryuk_image "testcontainers/ryuk:0.5.1"
  @ryuk_port 8080

  def register({filter_key, filter_value}) do
    with {:ok, socket} <- get_ryuk_socket() do
      :gen_tcp.send(
        socket,
        "#{:uri_string.quote(filter_key)}=#{:uri_string.quote(filter_value)}" <> "\n"
      )

      case :gen_tcp.recv(socket, 0, 5_000) do
        {:ok, "ACK\n"} ->
          :ok

        {:error, reason} ->
          IO.puts("Error receiving data: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp get_ryuk_socket() do
    with {:ok, container} <- create_ryuk_container(),
         {:ok, socket} <- create_ryuk_socket(container) do
      {:ok, socket}
    end
  end

  defp create_ryuk_container do
    %Container{image: @ryuk_image}
    |> Container.with_exposed_port(@ryuk_port)
    |> Container.with_environment("RYUK_PORT", "#{@ryuk_port}")
    |> Container.with_environment("RYUK_CONNECTION_TIMEOUT", "120s")
    |> Container.with_bind_mount("/var/run/docker.sock", "/var/run/docker.sock", "rw")
    |> Docker.Api.run(reap: false)
  end

  defp create_ryuk_socket(%Container{} = container) do
    host_port = Container.mapped_port(container, @ryuk_port)

    :gen_tcp.connect(~c"localhost", host_port, [
      :binary,
      active: false,
      packet: :line
    ])
  end
end
