defmodule Test.NginxContainer do
  defstruct []

  defimpl Testcontainers.ContainerBuilder do
    alias Testcontainers.Docker
    import Testcontainers.Container

    @impl true
    def build(%Test.NginxContainer{}) do
      new("nginx:alpine")
    end

    @impl true
    @spec is_starting(%Test.NginxContainer{}, %Testcontainers.Container{}, %Tesla.Env{}) :: any()
    def is_starting(_config, container, conn) do
      {:ok, _} = Docker.Api.put_file(container.container_id, conn, "/tmp", "Hello foo bar")

      nil
    end
  end
end
