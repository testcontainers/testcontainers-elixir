defmodule Testcontainers.Container.MinioContainerTest do
  use ExUnit.Case, async: true

  import Testcontainers.ExUnit
  alias Testcontainers.MinioContainer

  @moduletag timeout: 300_000

  @minio_container MinioContainer.new()

  container(:minio, @minio_container)

  test "creates and starts minio container", %{minio: minio} do
    assert MinioContainer.connection_url(minio) |> valid_url?()
  end

  defp valid_url?(url) do
    uri = URI.parse(url)
    uri.scheme in ["http", "https"] and not is_nil(uri.host)
  end
end
