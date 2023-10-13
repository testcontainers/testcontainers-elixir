defmodule CephContainerTest do
  use ExUnit.Case, async: true

  alias TestcontainersElixir.Container
  alias TestcontainersElixir.CephContainer
  alias TestcontainersElixir.Container

  @tag timeout: 300_000

  test "creates and starts ceph container" do
    {:ok, container} =
      CephContainer.new()
      |> Container.run(
        on_exit: &ExUnit.Callbacks.on_exit/2,
        waiting_strategy: &CephContainer.waiting_strategy/2
      )

    assert is_number(Container.mapped_port(container, 8080))
  end
end
