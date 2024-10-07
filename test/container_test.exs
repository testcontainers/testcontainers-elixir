defmodule Testcontainers.ContainerTest do
  use ExUnit.Case, async: true

  alias Testcontainers.ContainerBuilder
  alias Testcontainers.Container

  describe "with reuse" do
    test "sets reuse to true" do
      container = Container.new("my-image")
      assert container.reuse == false

      updated_container = Container.with_reuse(container, true)

      assert updated_container.reuse == true
    end
  end

  describe "hash" do
    test "returns the same hash for the same container" do
      container1 = ContainerBuilder.build(Testcontainers.PostgresContainer.new())
      container2 = ContainerBuilder.build(Testcontainers.PostgresContainer.new())

      assert Testcontainers.Util.Hash.struct_to_hash(container1) ==
               "005c9be32d1a1d2f74f5cdaaf534be3e039a016473906bad8d91186c47346f41"

      assert Testcontainers.Util.Hash.struct_to_hash(container2) ==
               "005c9be32d1a1d2f74f5cdaaf534be3e039a016473906bad8d91186c47346f41"
    end
  end

  describe "with_exposed_port/2" do
    test "adds an exposed port to the container" do
      container =
        Container.new("my-image")
        |> Container.with_exposed_port(80)

      assert container.exposed_ports == [80]
    end

    test "removes duplicate exposed ports" do
      container =
        Container.new("my-image")
        |> Container.with_exposed_port(80)
        |> Container.with_exposed_port(80)

      assert container.exposed_ports == [80]
    end
  end

  describe "with_exposed_ports/2" do
    test "adds multiple exposed ports to the container" do
      container =
        Container.new("my-image")
        |> Container.with_exposed_ports([80, 443])

      assert container.exposed_ports == [80, 443]
    end

    test "removes duplicate exposed ports" do
      container =
        Container.new("my-image")
        |> Container.with_exposed_ports([80, 443])
        |> Container.with_exposed_ports([80])

      assert container.exposed_ports == [80, 443]
    end
  end

  describe "with_fixed_port/3" do
    test "adds a fixed exposed port to the container" do
      container =
        Container.new("my-image")
        |> Container.with_fixed_port(80, 8080)

      assert container.exposed_ports == [{80, 8080}]
    end

    test "removes and overwrites duplicate fixed ports" do
      container =
        Container.new("my-image")
        |> Container.with_fixed_port(80)
        |> Container.with_fixed_port(80, 8080)
        |> Container.with_fixed_port(80, 8081)

      assert container.exposed_ports == [{80, 8081}]
    end
  end

  describe "mapped_port/2" do
    test "returns the mapped host port for the given exposed port" do
      container = Container.new("my-image") |> Container.with_fixed_port(80, 8080)
      assert Container.mapped_port(container, 80) == 8080
    end

    test "returns nil if the exposed port is not found" do
      container = Container.new("my-image")
      assert Container.mapped_port(container, 80) == nil
    end
  end

  describe "with_network_mode/2" do
    test "returns the network host type" do
      container = Container.new("my-image") |> Container.with_network_mode("host")
      assert container.network_mode == "host"
    end

    test "returns nil if the network mode is not set" do
      container = Container.new("my-image")
      assert container.network_mode == nil
    end
  end

  describe "with_auth/3" do
    test "sets the authentication token for the container" do
      container = Container.new("my-image")
      assert container.auth == nil

      updated_container = Container.with_auth(container, "username", "password")

      assert updated_container.auth ==
               "eyJwYXNzd29yZCI6InBhc3N3b3JkIiwidXNlcm5hbWUiOiJ1c2VybmFtZSJ9"
    end
  end

  describe "with_check_image/2" do
    test "compiles a string into a valid regex" do
      container =
        "registry.io/my-user/my-image:latest"
        |> Container.new()
        |> Container.with_check_image("my-image")

      assert container.check_image == ~r/my-image/
    end

    test "raises Regex.CompileError when string can't be compiled to a valid regex" do
      assert_raise Regex.CompileError, fn ->
        "registry.io/my-user/my-image:latest"
        |> Container.new()
        |> Container.with_check_image("*my-image")
      end
    end

    test "accepts a regex" do
      container =
        "registry.io/my-user/my-image:latest"
        |> Container.new()
        |> Container.with_check_image(~r/.*my-image.*/)

      assert container.check_image == ~r/.*my-image.*/
    end
  end

  describe "valid_image/1" do
    test "return config when check image isn't set" do
      container = Container.new("invalid-image")

      assert {:ok, container} == Container.valid_image(container)
    end

    test "return config when image matches default string" do
      container =
        Container.new("valid-image")
        |> Container.with_check_image("valid")

      assert {:ok, container} == Container.valid_image(container)
    end

    test "return config when image contains the prefix" do
      container =
        Container.new("custom-hub.io/for-user/valid-image:tagged")
        |> Container.with_check_image("valid")

      assert {:ok, container} == Container.valid_image(container)
    end

    test "return config when image matches a custom regular expression" do
      container =
        Container.new("valid-image")
        |> Container.with_check_image(~r/.*valid-image.*/)

      assert {:ok, container} == Container.valid_image(container)
    end

    test "return error when image doesn't match default one" do
      container =
        Container.new("invalid-image")
        |> Container.with_check_image("validated")

      assert {:error,
              "Unexpected image invalid-image. If this is a valid image, provide a broader `check_image` regex to the container configuration."} ==
               Container.valid_image(container)
    end
  end

  describe "valid_image!/1" do
    test "raises error when image isn't valid" do
      container =
        Container.new("invalid-image")
        |> Container.with_check_image("validated")

      assert_raise ArgumentError,
                   "Unexpected image invalid-image. If this is a valid image, provide a broader `check_image` regex to the container configuration.",
                   fn ->
                     Container.valid_image!(container)
                   end
    end
  end
end
