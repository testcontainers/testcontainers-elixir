# SPDX-License-Identifier: MIT
defmodule Testcontainers.Container.CephContainerTest do
  use ExUnit.Case, async: true

  import Testcontainers.ExUnit
  alias Testcontainers.CephContainer

  @moduletag timeout: 300_000

  @ceph_container CephContainer.new()

  container(:ceph, @ceph_container)

  test "creates and starts ceph container", %{ceph: ceph} do
    conn_opts = CephContainer.connection_opts(ceph)

    {:ok, _result} =
      ExAws.S3.put_bucket("my-bucket", "")
      |> ExAws.request(conn_opts)

    {:ok, %{body: %{buckets: [first_bucket | _rest]}}} =
      ExAws.S3.list_buckets()
      |> ExAws.request(conn_opts)

    assert first_bucket.name == "my-bucket"
  end
end
