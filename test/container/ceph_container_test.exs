defmodule Testcontainers.Container.CephContainerTest do
  use ExUnit.Case, async: true

  import Testcontainers.ExUnit
  alias Testcontainers.CephContainer

  @moduletag timeout: 300_000

  @ceph_container CephContainer.new()

  container(:ceph, @ceph_container)

  test "creates and starts ceph container", %{ceph: ceph} do
    url = CephContainer.connection_url(ceph)

    {:ok, 404, _headers, _body_ref} =
      :hackney.request(:get, url <> "/bucket_that_does_not_exist")

    {:ok, 403, _headers, _body_ref} = :hackney.request(:get, url <> "/" <> @ceph_container.bucket)

    {:ok, 200, _headers, body_ref} = :hackney.request(:get, url)
    {:ok, body} = :hackney.body(body_ref)
    body_str = IO.iodata_to_binary(body)

    assert String.contains?(body_str, "anonymous")
  end
end
