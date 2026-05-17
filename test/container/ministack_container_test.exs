# SPDX-License-Identifier: MIT
defmodule Testcontainers.Container.MinistackContainerTest do
  use ExUnit.Case, async: true

  import Testcontainers.ExUnit
  alias Testcontainers.ContainerBuilder
  alias Testcontainers.LogWaitStrategy
  alias Testcontainers.MinistackContainer

  @ministack_container MinistackContainer.new()

  container(:ministack, @ministack_container)

  test "creates and starts ministack container", %{ministack: ministack} do
    conn_opts = MinistackContainer.connection_opts(ministack)

    {:ok, _result} =
      ExAws.S3.put_bucket("my-bucket", "")
      |> ExAws.request(conn_opts)

    {:ok, %{body: %{buckets: [first_bucket | _rest]}}} =
      ExAws.S3.list_buckets()
      |> ExAws.request(conn_opts)

    assert first_bucket.name == "my-bucket"
  end
end
