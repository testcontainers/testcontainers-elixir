defmodule Testcontainers.DockerComposeTest do
  use ExUnit.Case, async: true

  alias Testcontainers.DockerCompose

  describe "new/1" do
    test "creates a new DockerCompose with filepath" do
      compose = DockerCompose.new("/tmp/my-project")

      assert compose.filepath == "/tmp/my-project"
      assert is_binary(compose.project_name)
      assert String.starts_with?(compose.project_name, "tc-")
      assert compose.env == %{}
      assert compose.wait_strategies == %{}
      assert compose.wait_timeout == 120_000
      assert compose.pull == :missing
      assert compose.services == []
      assert compose.build == false
      assert compose.profiles == []
      assert compose.remove_volumes == true
      assert compose.compose_files == []
    end

    test "generates unique project names" do
      compose1 = DockerCompose.new("/tmp/test")
      compose2 = DockerCompose.new("/tmp/test")

      assert compose1.project_name != compose2.project_name
    end
  end

  describe "with_env/3" do
    test "sets an environment variable" do
      compose =
        DockerCompose.new("/tmp/test")
        |> DockerCompose.with_env("MY_VAR", "my_value")

      assert compose.env == %{"MY_VAR" => "my_value"}
    end

    test "accepts atom keys" do
      compose =
        DockerCompose.new("/tmp/test")
        |> DockerCompose.with_env(:MY_VAR, "my_value")

      assert compose.env == %{"MY_VAR" => "my_value"}
    end

    test "overwrites existing environment variable" do
      compose =
        DockerCompose.new("/tmp/test")
        |> DockerCompose.with_env("MY_VAR", "first")
        |> DockerCompose.with_env("MY_VAR", "second")

      assert compose.env == %{"MY_VAR" => "second"}
    end
  end

  describe "with_wait_strategy/3" do
    test "adds a wait strategy for a service" do
      strategy = %Testcontainers.CommandWaitStrategy{command: ["echo", "ok"]}

      compose =
        DockerCompose.new("/tmp/test")
        |> DockerCompose.with_wait_strategy("redis", strategy)

      assert Map.has_key?(compose.wait_strategies, "redis")
      assert length(compose.wait_strategies["redis"]) == 1
    end

    test "accumulates wait strategies for the same service" do
      strategy1 = %Testcontainers.CommandWaitStrategy{command: ["echo", "1"]}
      strategy2 = %Testcontainers.CommandWaitStrategy{command: ["echo", "2"]}

      compose =
        DockerCompose.new("/tmp/test")
        |> DockerCompose.with_wait_strategy("redis", strategy1)
        |> DockerCompose.with_wait_strategy("redis", strategy2)

      assert length(compose.wait_strategies["redis"]) == 2
    end
  end

  describe "with_services/2" do
    test "sets specific services to start" do
      compose =
        DockerCompose.new("/tmp/test")
        |> DockerCompose.with_services(["redis", "postgres"])

      assert compose.services == ["redis", "postgres"]
    end
  end

  describe "with_build/2" do
    test "enables build" do
      compose =
        DockerCompose.new("/tmp/test")
        |> DockerCompose.with_build(true)

      assert compose.build == true
    end
  end

  describe "with_profile/2" do
    test "adds a profile" do
      compose =
        DockerCompose.new("/tmp/test")
        |> DockerCompose.with_profile("debug")

      assert compose.profiles == ["debug"]
    end

    test "accumulates profiles" do
      compose =
        DockerCompose.new("/tmp/test")
        |> DockerCompose.with_profile("debug")
        |> DockerCompose.with_profile("test")

      assert "debug" in compose.profiles
      assert "test" in compose.profiles
    end
  end

  describe "with_pull/2" do
    test "sets pull to :always" do
      compose = DockerCompose.new("/tmp/test") |> DockerCompose.with_pull(:always)
      assert compose.pull == :always
    end

    test "sets pull to :never" do
      compose = DockerCompose.new("/tmp/test") |> DockerCompose.with_pull(:never)
      assert compose.pull == :never
    end

    test "sets pull to :missing" do
      compose = DockerCompose.new("/tmp/test") |> DockerCompose.with_pull(:missing)
      assert compose.pull == :missing
    end
  end

  describe "with_remove_volumes/2" do
    test "sets remove_volumes to false" do
      compose =
        DockerCompose.new("/tmp/test")
        |> DockerCompose.with_remove_volumes(false)

      assert compose.remove_volumes == false
    end
  end

  describe "with_wait_timeout/2" do
    test "sets the wait timeout" do
      compose =
        DockerCompose.new("/tmp/test")
        |> DockerCompose.with_wait_timeout(60_000)

      assert compose.wait_timeout == 60_000
    end
  end

  describe "with_project_name/2" do
    test "sets the project name" do
      compose =
        DockerCompose.new("/tmp/test")
        |> DockerCompose.with_project_name("my-project")

      assert compose.project_name == "my-project"
    end
  end

  describe "with_compose_file/2" do
    test "adds a compose file" do
      compose =
        DockerCompose.new("/tmp/test")
        |> DockerCompose.with_compose_file("docker-compose.yml")

      assert compose.compose_files == ["docker-compose.yml"]
    end

    test "accumulates compose files in order" do
      compose =
        DockerCompose.new("/tmp/test")
        |> DockerCompose.with_compose_file("docker-compose.yml")
        |> DockerCompose.with_compose_file("docker-compose.override.yml")

      assert compose.compose_files == ["docker-compose.yml", "docker-compose.override.yml"]
    end
  end
end
