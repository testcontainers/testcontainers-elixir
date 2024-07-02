defmodule Testcontainers.ContainerTest do
  use ExUnit.Case, async: true

  alias Testcontainers.Container

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

  describe "with_auth/3" do
    test "sets the authentication token for the container" do
      container = Container.new("my-image")
      assert container.auth == nil

      updated_container = Container.with_auth(container, "username", "password")

      assert updated_container.auth ==
               "eyJwYXNzd29yZCI6InBhc3N3b3JkIiwidXNlcm5hbWUiOiJ1c2VybmFtZSJ9"
    end
  end

  describe "valid_image/1" do
    test "return config when check is disabled" do
      container =
        Container.new("invalid-image")
        |> Container.with_default_image("valid-image")
        |> Container.with_check_image(false)

      assert {:ok, container} == Container.valid_image(container)
    end

    test "return config when default image isn't set" do
      container =
        Container.new("invalid-image")
        |> Container.with_check_image(true)

      assert {:ok, container} == Container.valid_image(container)
    end

    test "return config when image matches default one" do
      container =
        Container.new("valid-image")
        |> Container.with_default_image("valid")
        |> Container.with_check_image(true)

      assert {:ok, container} == Container.valid_image(container)
    end

    test "return error when image doesn't match default one" do
      container =
        Container.new("invalid-image")
        |> Container.with_default_image("valid")
        |> Container.with_check_image(true)

      assert {:error, "Image invalid-image is not compatible with valid"} ==
               Container.valid_image(container)
    end
  end

  describe "valid_image!/1" do
    test "raises error when image isn't valid" do
      container =
        Container.new("invalid-image")
        |> Container.with_default_image("valid")
        |> Container.with_check_image(true)

      assert_raise ArgumentError, "Image invalid-image is not compatible with valid", fn ->
        Container.valid_image!(container)
      end
    end
  end
end
