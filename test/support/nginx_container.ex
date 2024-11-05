defmodule Test.NginxContainer do
  defstruct []

  defimpl Testcontainers.ContainerBuilder do
    alias Testcontainers.CommandWaitStrategy
    alias Testcontainers.Docker
    import Testcontainers.Container

    @impl true
    def build(%Test.NginxContainer{}) do
      new("nginx:alpine")
      |> with_waiting_strategy(CommandWaitStrategy.new(["cat", "/tmp/foo.txt"]))
    end

    @impl true
    def after_start(_config, container, conn) do
      Docker.Api.put_file(container.container_id, conn, "/tmp", "foo.txt", "Hello foo bar")
    end
  end
end
