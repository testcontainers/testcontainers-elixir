defmodule Testcontainers.Container.CephContainerTest do
  use ExUnit.Case, async: true

  import Testcontainers.ExUnit
  alias Testcontainers.Container
  alias Testcontainers.Container.CephContainer

  @moduletag timeout: 300_000

  container(:ceph, CephContainer.new())

  test "creates and starts ceph container", %{ceph: ceph} do
    host_port = Container.mapped_port(ceph, 8080)

    {:ok, 404, _headers, _body_ref} =
      :hackney.request(:get, "http://127.0.0.1:#{host_port}/bucket_that_does_not_exist")

    {:ok, 403, _headers, _body_ref} = :hackney.request(:get, "http://127.0.0.1:#{host_port}/demo")

    {:ok, 200, _headers, body_ref} = :hackney.request(:get, "http://127.0.0.1:#{host_port}")
    {:ok, body} = :hackney.body(body_ref)
    body_str = IO.iodata_to_binary(body)

    assert String.contains?(body_str, "anonymous")
  end
end
