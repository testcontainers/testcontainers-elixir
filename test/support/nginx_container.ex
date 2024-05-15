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
    @spec after_start(%Test.NginxContainer{}, %Testcontainers.Container{}, %Tesla.Env{}) :: :ok
    def after_start(_config, container, conn) do
      with {:ok, _} <-
             Docker.Api.put_file(container.container_id, conn, "/tmp", "foo.txt", "Hello foo bar") do
        :ok
      end
    end
  end
end
