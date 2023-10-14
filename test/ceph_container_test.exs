defmodule CephContainerTest do
  use ExUnit.Case, async: true

  import TestcontainersElixir.ExUnit
  alias TestcontainersElixir.Container
  alias TestcontainersElixir.CephContainer
  alias TestcontainersElixir.Container

  @tag timeout: 300_000

  container(:ceph, CephContainer.new())

  test "creates and starts ceph container", %{ceph: ceph} do
    assert is_number(Container.mapped_port(ceph, 8080))
  end
end
