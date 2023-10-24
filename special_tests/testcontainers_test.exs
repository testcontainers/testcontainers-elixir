defmodule TestcontainersTest do
  alias Testcontainers.Container.MySqlContainer
  alias Testcontainers.Container
  use ExUnit.Case, async: true

  @moduletag timeout: 300_000

  test "will cleanup containers" do
    {:ok, container} = Container.run(MySqlContainer.new())
    GenServer.stop(Testcontainers)
    :timer.sleep(15_000)
    {:ok, _} = Testcontainers.start_link()
    {:error, _} = Testcontainers.get_container(container.container_id)
  end
end
