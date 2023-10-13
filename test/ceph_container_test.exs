defmodule CephContainerTest do
  use ExUnit.Case, async: true

  import TestcontainersElixir.ExUnit
  alias DockerEngineAPI.Api.Container
  alias TestcontainersElixir.Container

  @tag timeout: 300_000

  test "creates and starts ceph container" do
    {:ok, container} =
      ceph_container(image: "quay.io/ceph/demo:latest")

    assert is_number(Container.mapped_port(container, 8080))
  end
end
