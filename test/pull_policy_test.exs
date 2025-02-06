defmodule Testcontainers.PullPolicyTest do
  use ExUnit.Case, async: true

  test "always_pull/0 fetches image from remote repository" do
    config = %Testcontainers.Container{
      image: "alpine:latest",
      pull_policy: Testcontainers.PullPolicy.always_pull()
    }

    assert {:ok, container} = Testcontainers.start_container(config)
    assert :ok = Testcontainers.stop_container(container.container_id)
  end

  test "never_pull/0 does not fetch image from remote repository" do
    {conn, _url, _host} = Testcontainers.Connection.get_connection()
    {:ok, _nil} = Testcontainers.Docker.Api.pull_image("alpine:latest", conn)
    {:ok, _name} = Testcontainers.Docker.Api.tag_image("alpine", "local_alpine", "latest", conn)

    config = %Testcontainers.Container{
      image: "local_alpine:latest",
      pull_policy: Testcontainers.PullPolicy.never_pull()
    }

    assert {:ok, container} = Testcontainers.start_container(config)
    assert :ok = Testcontainers.stop_container(container.container_id)
  end

  test "pull_condition/1 fetches image if expression evaluates to true" do
    config = %Testcontainers.Container{
      image: "alpine:latest",
      pull_policy:
        Testcontainers.PullPolicy.pull_condition(fn _config, _conn ->
          true
        end)
    }

    assert {:ok, container} = Testcontainers.start_container(config)
    assert :ok = Testcontainers.stop_container(container.container_id)
  end

  test "pull_condition/1 does not fetch image if expression evaluates to a falsey value" do
    {conn, _url, _host} = Testcontainers.Connection.get_connection()
    {:ok, _nil} = Testcontainers.Docker.Api.pull_image("alpine:latest", conn)
    {:ok, _name} = Testcontainers.Docker.Api.tag_image("alpine", "local_alpine2", "latest", conn)

    config = %Testcontainers.Container{
      image: "local_alpine2:latest",
      pull_policy:
        Testcontainers.PullPolicy.pull_condition(fn _config, _conn ->
          false
        end)
    }

    assert {:ok, container} = Testcontainers.start_container(config)
    assert :ok = Testcontainers.stop_container(container.container_id)
  end
end
