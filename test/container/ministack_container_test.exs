# SPDX-License-Identifier: MIT
defmodule Testcontainers.Container.MinistackContainerTest do
  use ExUnit.Case, async: true

  import Testcontainers.ExUnit

  alias Testcontainers.ContainerBuilder
  alias Testcontainers.MinistackContainer

  @ministack_container MinistackContainer.new()

  describe "new/0 and builder options" do
    test "returns default ministack configuration" do
      config = MinistackContainer.new()

      assert config.image == "ministackorg/ministack:1.3.42"
      assert config.username == "111111111111"
      assert config.password == "anything"
      assert config.wait_timeout == 60_000
      assert config.reuse == false
    end

    test "exposes default S3 and UI ports and sets AWS credentials" do
      container =
        MinistackContainer.new()
        |> MinistackContainer.with_reuse(true)
        |> ContainerBuilder.build()

      assert {MinistackContainer.default_s3_port(), nil} in container.exposed_ports
      assert {MinistackContainer.default_ui_port(), nil} in container.exposed_ports
      assert container.environment[:AWS_ACCESS_KEY_ID] == MinistackContainer.get_username()
      assert container.environment[:AWS_SECRET_ACCESS_KEY] == MinistackContainer.get_password()
      assert container.reuse == true
    end
  end

  describe "runtime behavior" do
    container(:ministack, @ministack_container)

    test "provides connection helpers", %{
      ministack: ministack
    } do
      host = Testcontainers.get_host(ministack)
      port = MinistackContainer.port(ministack)
      conn_opts = MinistackContainer.connection_opts(ministack)

      assert is_integer(port)
      assert MinistackContainer.connection_url(ministack) == "http://#{host}:#{port}"

      assert conn_opts == [
               port: port,
               scheme: "http://",
               host: host,
               access_key_id: MinistackContainer.get_username(),
               secret_access_key: MinistackContainer.get_password()
             ]
    end

    test "responds from health-check endpoint", %{
      ministack: ministack
    } do
      health_url = "#{MinistackContainer.connection_url(ministack)}/_ministack/health"

      {:ok, %{status: 200, body: body}} = Tesla.get(health_url)
      {:ok, health} = Jason.decode(body)

      assert is_map(health)
      assert map_size(health) > 0
    end

    test "supports bucket and file object operations", %{
      ministack: ministack
    } do
      conn_opts = MinistackContainer.connection_opts(ministack)

      bucket = bucket_name("files")
      object_key = "fixtures/hello.txt"
      file_contents = "Hello from a Ministack-backed S3 object"

      {:ok, _result} =
        ExAws.S3.put_bucket(bucket, "")
        |> ExAws.request(conn_opts)

      {:ok, %{body: %{buckets: buckets}}} =
        ExAws.S3.list_buckets()
        |> ExAws.request(conn_opts)

      assert Enum.any?(buckets, &(&1.name == bucket))

      {:ok, _result} =
        ExAws.S3.put_object(bucket, object_key, file_contents)
        |> ExAws.request(conn_opts)

      {:ok, %{body: %{contents: objects}}} =
        ExAws.S3.list_objects(bucket, prefix: "fixtures/")
        |> ExAws.request(conn_opts)

      assert Enum.any?(objects, &(&1.key == object_key))

      {:ok, %{body: ^file_contents}} =
        ExAws.S3.get_object(bucket, object_key)
        |> ExAws.request(conn_opts)
    end
  end

  defp bucket_name(prefix) do
    "ministack-#{prefix}-#{System.unique_integer([:positive])}"
  end
end
