defmodule Testcontainers.MoreContainerTest do
  use ExUnit.Case, async: true

  alias Testcontainers.Container

  describe "with_waiting_strategy/2" do
    test "adds a waiting strategy to the container" do
      wait_fn = %Testcontainers.PortWaitStrategy{}

      container =
        Container.new("my-image")
        |> Container.with_waiting_strategy(wait_fn)

      assert container.wait_strategies == [wait_fn]
    end
  end

  describe "with_waiting_strategies/2" do
    test "adds multiple waiting strategies to the container" do
      wait_fns = [
        %Testcontainers.PortWaitStrategy{},
        %Testcontainers.PortWaitStrategy{}
      ]

      container =
        Container.new("my-image")
        |> Container.with_waiting_strategies(wait_fns)

      assert container.wait_strategies == Enum.reverse(wait_fns)
    end
  end

  describe "with_environment/3" do
    test "adds an environment variable to the container" do
      container =
        Container.new("my-image")
        |> Container.with_environment("KEY", "value")

      assert container.environment == %{"KEY" => "value"}
    end
  end

  describe "with_bind_mount/4" do
    test "adds a bind mount to the container" do
      container =
        Container.new("my-image")
        |> Container.with_bind_mount("/host/src", "/container/dest", "ro")

      assert container.bind_mounts == [
               %{host_src: "/host/src", container_dest: "/container/dest", options: "ro"}
             ]
    end
  end

  describe "with_bind_volume/4" do
    test "adds a bind volume to the container" do
      container =
        Container.new("my-image")
        |> Container.with_bind_volume("volume", "/container/dest", true)

      assert container.bind_volumes == [
               %{volume: "volume", container_dest: "/container/dest", read_only: true}
             ]
    end
  end

  describe "with_label/3" do
    test "adds a label to the container" do
      container =
        Container.new("my-image")
        |> Container.with_label("key", "value")

      assert container.labels == %{"key" => "value"}
    end
  end

  describe "with_cmd/2" do
    test "sets the command for the container" do
      container =
        Container.new("my-image")
        |> Container.with_cmd(["cmd", "arg"])

      assert container.cmd == ["cmd", "arg"]
    end
  end

  describe "with_auto_remove/2" do
    test "sets the auto-remove flag for the container" do
      container =
        Container.new("my-image")
        |> Container.with_auto_remove(true)

      assert container.auto_remove == true
    end
  end
end
