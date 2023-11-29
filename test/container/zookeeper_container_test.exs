defmodule Testcontainers.ZookeeperContainerTest do
  use ExUnit.Case, async: true
  import Testcontainers.ExUnit

  alias Testcontainers.Container
  alias Testcontainers.ZookeeperContainer

  describe "new/0" do
    test "creates a new ZookeeperContainer struct with default configurations" do
      config = ZookeeperContainer.new()

      assert config.image == "bitnami/zookeeper:3.7.2"
      assert config.port == 2181
      assert config.wait_timeout == 60_000
    end
  end

  describe "with_image/2" do
    test "overrides the default image used for the zookeeper container" do
      config = ZookeeperContainer.new()
      new_config = ZookeeperContainer.with_image(config, "zookeeper:3.9.0")

      assert new_config.image == "zookeeper:3.9.0"
    end

    test "raises if the image is not a binary" do
      config = ZookeeperContainer.new()
      assert_raise FunctionClauseError, fn -> ZookeeperContainer.with_image(config, 6.2) end
    end
  end

  describe "with_port/2" do
    test "overrides the default zookeeper port used for the zookeeper container" do
      config = ZookeeperContainer.new()
      new_config = ZookeeperContainer.with_port(config, 2182)

      assert new_config.port == 2182
    end

    test "raises if the zookeeper port is not an integer" do
      config = ZookeeperContainer.new()
      assert_raise FunctionClauseError, fn -> ZookeeperContainer.with_port(config, "9094") end
    end
  end

  describe "with_wait_timeout/2" do
    test "overrides the default wait_timeout used for the zookeeper container" do
      config = ZookeeperContainer.new()
      new_config = ZookeeperContainer.with_wait_timeout(config, 90_000)

      assert new_config.wait_timeout == 90_000
    end

    test "raises if the wait_timeout is not an integer" do
      config = ZookeeperContainer.new()

      assert_raise FunctionClauseError, fn ->
        ZookeeperContainer.with_wait_timeout(config, "9094")
      end
    end
  end

  describe "integration testing" do
    container(:zookeeper, ZookeeperContainer.new())

    test "provides a ready-to-use zookeeper container", %{zookeeper: zookeeper} do
      {:ok, pid} =
        :erlzk.connect([{~c"localhost", Container.mapped_port(zookeeper, 2181)}], 30000)

      on_exit(fn -> Process.exit(pid, :kill) end)

      assert Process.alive?(pid)
    end
  end
end
