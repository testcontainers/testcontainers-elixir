defmodule Testcontainers.Container.MinioContainerTest do
  use ExUnit.Case, async: true

  import Testcontainers.ExUnit
  alias Testcontainers.MinioContainer

  @moduletag timeout: 300_000

  @minio_container MinioContainer.new()

  container(:minio, @minio_container)

  test "creates and starts minio container", %{minio: minio} do
    IO.inspect(minio)
  end
end
