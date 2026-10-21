# SPDX-License-Identifier: MIT
defmodule Testcontainers.Container.FlociContainerTest do
  use ExUnit.Case, async: true

  import Testcontainers.ExUnit

  alias Testcontainers.ContainerBuilder
  alias Testcontainers.FlociContainer
  alias Testcontainers.LogWaitStrategy

  @floci_container FlociContainer.new()

  describe "new/0" do
    test "returns the default Floci configuration" do
      config = FlociContainer.new()

      assert config.image == "floci/floci:1.7.0"
      assert config.region == "us-east-1"
      assert config.availability_zone == "us-east-1a"
      assert config.account_id == "000000000000"
      assert config.access_key == "test"
      assert config.secret_key == "test"
      assert config.wait_timeout == 60_000
      assert config.base_url == nil
      assert config.check_image == "floci/floci"
      assert config.reuse == false
    end
  end

  describe "with_image/2" do
    test "overrides the default image" do
      config = FlociContainer.new()

      new_config = FlociContainer.with_image(config, "floci/floci:latest")

      assert new_config.image == "floci/floci:latest"
    end

    test "raises if the image is not a binary" do
      config = FlociContainer.new()

      assert_raise FunctionClauseError, fn -> FlociContainer.with_image(config, 123) end
    end
  end

  describe "with_region/2" do
    test "overrides the default region" do
      config = FlociContainer.new()

      new_config = FlociContainer.with_region(config, "eu-west-1")

      assert new_config.region == "eu-west-1"
    end
  end

  describe "with_availability_zone/2" do
    test "overrides the default availability zone" do
      config = FlociContainer.new()

      new_config = FlociContainer.with_availability_zone(config, "eu-west-1b")

      assert new_config.availability_zone == "eu-west-1b"
    end
  end

  describe "with_account_id/2" do
    test "overrides the default account ID" do
      config = FlociContainer.new()

      new_config = FlociContainer.with_account_id(config, "111111111111")

      assert new_config.account_id == "111111111111"
    end
  end

  describe "with_access_key/2" do
    test "overrides the default access key" do
      config = FlociContainer.new()

      new_config = FlociContainer.with_access_key(config, "access-key")

      assert new_config.access_key == "access-key"
    end
  end

  describe "with_base_url/2" do
    test "sets the URL Floci embeds in responses" do
      config = FlociContainer.new()

      new_config = FlociContainer.with_base_url(config, "http://floci:4566")

      assert new_config.base_url == "http://floci:4566"
    end
  end

  describe "with_secret_key/2" do
    test "overrides the default secret key" do
      config = FlociContainer.new()

      new_config = FlociContainer.with_secret_key(config, "secret-key")

      assert new_config.secret_key == "secret-key"
    end
  end

  describe "with_wait_timeout/2" do
    test "overrides the default wait timeout" do
      config = FlociContainer.new()

      new_config = FlociContainer.with_wait_timeout(config, 30_000)

      assert new_config.wait_timeout == 30_000
    end

    test "raises if the wait timeout is not an integer" do
      config = FlociContainer.new()

      assert_raise FunctionClauseError, fn ->
        FlociContainer.with_wait_timeout(config, "30000")
      end
    end
  end

  describe "with_check_image/2" do
    test "overrides the image validation pattern" do
      config = FlociContainer.new()

      new_config = FlociContainer.with_check_image(config, ~r/^custom-floci\/floci/)

      assert Regex.source(new_config.check_image) == "^custom-floci/floci"
    end
  end

  describe "with_reuse/2" do
    test "sets the reuse flag" do
      config = FlociContainer.new()

      new_config = FlociContainer.with_reuse(config, true)

      assert new_config.reuse == true
    end

    test "raises if reuse is not a boolean" do
      config = FlociContainer.new()

      assert_raise FunctionClauseError, fn ->
        FlociContainer.with_reuse(config, "true")
      end
    end
  end

  describe "ContainerBuilder.build/1" do
    test "builds a container using the configured image" do
      container =
        FlociContainer.new()
        |> FlociContainer.with_image("floci/floci:latest")
        |> ContainerBuilder.build()

      assert container.image == "floci/floci:latest"
    end

    test "exposes the Floci edge port" do
      container =
        FlociContainer.new()
        |> ContainerBuilder.build()

      assert {FlociContainer.default_port(), nil} in container.exposed_ports
    end

    test "sets the configured Floci environment" do
      container =
        FlociContainer.new()
        |> FlociContainer.with_region("eu-west-1")
        |> FlociContainer.with_availability_zone("eu-west-1b")
        |> FlociContainer.with_account_id("111111111111")
        |> FlociContainer.with_base_url("http://floci:4566")
        |> FlociContainer.with_access_key("access-key")
        |> FlociContainer.with_secret_key("secret-key")
        |> ContainerBuilder.build()

      assert container.environment[:FLOCI_DEFAULT_REGION] == "eu-west-1"
      assert container.environment[:FLOCI_DEFAULT_AVAILABILITY_ZONE] == "eu-west-1b"
      assert container.environment[:FLOCI_DEFAULT_ACCOUNT_ID] == "111111111111"
      assert container.environment[:FLOCI_BASE_URL] == "http://floci:4566"
      assert container.environment[:AWS_ACCESS_KEY_ID] == "access-key"
      assert container.environment[:AWS_SECRET_ACCESS_KEY] == "secret-key"
    end

    test "keeps the configured reuse flag" do
      container =
        FlociContainer.new()
        |> FlociContainer.with_reuse(true)
        |> ContainerBuilder.build()

      assert container.reuse == true
    end

    test "waits until Floci reports completed initialization" do
      container =
        FlociContainer.new()
        |> FlociContainer.with_wait_timeout(30_000)
        |> ContainerBuilder.build()

      assert [
               %LogWaitStrategy{
                 log_regex: log_regex,
                 timeout: 30_000
               }
             ] = container.wait_strategies

      assert Regex.match?(log_regex, "Ready.")
    end
  end

  describe "runtime behavior" do
    container(:floci, @floci_container)

    test "provides connection helpers", %{floci: floci} do
      host = Testcontainers.get_host(floci)
      port = FlociContainer.port(floci)

      assert is_integer(port)
      assert FlociContainer.connection_url(floci) == "http://#{host}:#{port}"

      assert FlociContainer.connection_opts(floci) == [
               port: port,
               scheme: "http://",
               host: host,
               region: "us-east-1",
               access_key_id: "test",
               secret_access_key: "test"
             ]
    end

    test "reports completed initialization", %{floci: floci} do
      init_url = "#{FlociContainer.connection_url(floci)}/_floci/init"

      {:ok, %{status: 200, body: body}} = Tesla.get(init_url)
      {:ok, %{"completed" => %{"ready" => true}}} = Jason.decode(body)
    end

    test "supports bucket and object operations", %{floci: floci} do
      conn_opts = FlociContainer.connection_opts(floci)
      bucket = "floci-#{System.unique_integer([:positive])}"
      object_key = "fixtures/hello.txt"
      contents = "Hello from a Floci-backed S3 object"

      {:ok, _result} =
        ExAws.S3.put_bucket(bucket, "")
        |> ExAws.request(conn_opts)

      {:ok, %{body: %{buckets: buckets}}} =
        ExAws.S3.list_buckets()
        |> ExAws.request(conn_opts)

      assert Enum.any?(buckets, &(&1.name == bucket))

      {:ok, _result} =
        ExAws.S3.put_object(bucket, object_key, contents)
        |> ExAws.request(conn_opts)

      {:ok, %{body: ^contents}} =
        ExAws.S3.get_object(bucket, object_key)
        |> ExAws.request(conn_opts)
    end
  end
end
