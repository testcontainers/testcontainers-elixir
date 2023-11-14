defmodule Testcontainers.Container.MinioContainerTest do
  use ExUnit.Case, async: true

  import Testcontainers.ExUnit
  alias Testcontainers.MinioContainer

  @moduletag timeout: 300_000

  @minio_container MinioContainer.new()

  container(:minio, @minio_container)

  test "creates and starts minio container", %{minio: minio} do
    conn_opts = MinioContainer.connection_opts(minio)

    {:ok, _result} =
      ExAws.S3.put_bucket("my-bucket", "")
      |> ExAws.request(conn_opts)

    {:ok, %{body: %{buckets: [first_bucket | _rest]}}} =
      ExAws.S3.list_buckets()
      |> ExAws.request(conn_opts)

    assert first_bucket.name == "my-bucket"
  end
end
