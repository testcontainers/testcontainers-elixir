defmodule Testcontainers.Compose.CliTest do
  use ExUnit.Case, async: true

  alias Testcontainers.Compose.Cli
  alias Testcontainers.DockerCompose

  describe "build_up_args/1" do
    test "builds basic up args" do
      compose = DockerCompose.new("/tmp/test") |> Map.put(:project_name, "tc-test123")
      args = Cli.build_up_args(compose)

      assert args == ["compose", "-p", "tc-test123", "up", "-d", "--wait"]
    end

    test "includes --build when build is true" do
      compose =
        DockerCompose.new("/tmp/test")
        |> Map.put(:project_name, "tc-test123")
        |> DockerCompose.with_build(true)

      args = Cli.build_up_args(compose)

      assert args == ["compose", "-p", "tc-test123", "up", "-d", "--wait", "--build"]
    end

    test "includes --pull always when pull is :always" do
      compose =
        DockerCompose.new("/tmp/test")
        |> Map.put(:project_name, "tc-test123")
        |> DockerCompose.with_pull(:always)

      args = Cli.build_up_args(compose)

      assert args == ["compose", "-p", "tc-test123", "up", "-d", "--wait", "--pull", "always"]
    end

    test "includes --pull never when pull is :never" do
      compose =
        DockerCompose.new("/tmp/test")
        |> Map.put(:project_name, "tc-test123")
        |> DockerCompose.with_pull(:never)

      args = Cli.build_up_args(compose)

      assert args == ["compose", "-p", "tc-test123", "up", "-d", "--wait", "--pull", "never"]
    end

    test "includes services when specified" do
      compose =
        DockerCompose.new("/tmp/test")
        |> Map.put(:project_name, "tc-test123")
        |> DockerCompose.with_services(["redis", "postgres"])

      args = Cli.build_up_args(compose)

      assert args == ["compose", "-p", "tc-test123", "up", "-d", "--wait", "redis", "postgres"]
    end

    test "includes compose files with -f flags" do
      compose =
        DockerCompose.new("/tmp/test")
        |> Map.put(:project_name, "tc-test123")
        |> DockerCompose.with_compose_file("docker-compose.yml")
        |> DockerCompose.with_compose_file("docker-compose.override.yml")

      args = Cli.build_up_args(compose)

      assert args == [
               "compose",
               "-p",
               "tc-test123",
               "-f",
               "docker-compose.yml",
               "-f",
               "docker-compose.override.yml",
               "up",
               "-d",
               "--wait"
             ]
    end

    test "includes profiles" do
      compose =
        DockerCompose.new("/tmp/test")
        |> Map.put(:project_name, "tc-test123")
        |> DockerCompose.with_profile("debug")

      args = Cli.build_up_args(compose)

      assert args == [
               "compose",
               "-p",
               "tc-test123",
               "--profile",
               "debug",
               "up",
               "-d",
               "--wait"
             ]
    end
  end

  describe "build_down_args/1" do
    test "builds basic down args with -v by default" do
      compose = DockerCompose.new("/tmp/test") |> Map.put(:project_name, "tc-test123")
      args = Cli.build_down_args(compose)

      assert args == ["compose", "-p", "tc-test123", "down", "-v"]
    end

    test "omits -v when remove_volumes is false" do
      compose =
        DockerCompose.new("/tmp/test")
        |> Map.put(:project_name, "tc-test123")
        |> DockerCompose.with_remove_volumes(false)

      args = Cli.build_down_args(compose)

      assert args == ["compose", "-p", "tc-test123", "down"]
    end
  end

  describe "build_ps_args/1" do
    test "builds ps args" do
      compose = DockerCompose.new("/tmp/test") |> Map.put(:project_name, "tc-test123")
      args = Cli.build_ps_args(compose)

      assert args == ["compose", "-p", "tc-test123", "ps", "--format=json"]
    end
  end

  describe "build_pull_args/1" do
    test "builds pull args" do
      compose = DockerCompose.new("/tmp/test") |> Map.put(:project_name, "tc-test123")
      args = Cli.build_pull_args(compose)

      assert args == ["compose", "-p", "tc-test123", "pull"]
    end
  end

  describe "build_logs_args/2" do
    test "builds logs args" do
      compose = DockerCompose.new("/tmp/test") |> Map.put(:project_name, "tc-test123")
      args = Cli.build_logs_args(compose, "redis")

      assert args == ["compose", "-p", "tc-test123", "logs", "redis"]
    end
  end

  describe "parse_ps_output/1" do
    test "parses single JSON line" do
      output =
        ~s|{"ID":"abc123","Name":"tc-test-redis-1","Service":"redis","State":"running","Publishers":[{"URL":"0.0.0.0","TargetPort":6379,"PublishedPort":32768,"Protocol":"tcp"}]}|

      result = Cli.parse_ps_output(output)

      assert length(result) == 1
      [entry] = result
      assert entry["Service"] == "redis"
      assert entry["ID"] == "abc123"
      assert entry["State"] == "running"
    end

    test "parses multiple JSON lines" do
      output =
        ~s|{"ID":"abc123","Service":"redis","State":"running","Publishers":[]}\n{"ID":"def456","Service":"postgres","State":"running","Publishers":[]}|

      result = Cli.parse_ps_output(output)

      assert length(result) == 2
      assert Enum.at(result, 0)["Service"] == "redis"
      assert Enum.at(result, 1)["Service"] == "postgres"
    end

    test "parses JSON array output" do
      output =
        ~s|[{"ID":"abc123","Service":"redis","State":"running","Publishers":[]},{"ID":"def456","Service":"postgres","State":"running","Publishers":[]}]|

      result = Cli.parse_ps_output(output)

      assert length(result) == 2
    end

    test "handles empty output" do
      assert Cli.parse_ps_output("") == []
    end

    test "skips invalid JSON lines" do
      output =
        ~s|not json\n{"ID":"abc123","Service":"redis","State":"running","Publishers":[]}|

      result = Cli.parse_ps_output(output)

      assert length(result) == 1
      assert Enum.at(result, 0)["Service"] == "redis"
    end
  end

  describe "parse_publishers/1" do
    test "parses publishers into port tuples" do
      publishers = [
        %{
          "URL" => "0.0.0.0",
          "TargetPort" => 6379,
          "PublishedPort" => 32_768,
          "Protocol" => "tcp"
        }
      ]

      assert Cli.parse_publishers(publishers) == [{6379, 32_768}]
    end

    test "filters out publishers with PublishedPort of 0" do
      publishers = [
        %{
          "URL" => "0.0.0.0",
          "TargetPort" => 6379,
          "PublishedPort" => 0,
          "Protocol" => "tcp"
        }
      ]

      assert Cli.parse_publishers(publishers) == []
    end

    test "handles multiple publishers" do
      publishers = [
        %{
          "URL" => "0.0.0.0",
          "TargetPort" => 6379,
          "PublishedPort" => 32_768,
          "Protocol" => "tcp"
        },
        %{
          "URL" => "0.0.0.0",
          "TargetPort" => 5432,
          "PublishedPort" => 32_769,
          "Protocol" => "tcp"
        }
      ]

      result = Cli.parse_publishers(publishers)
      assert length(result) == 2
      assert {6379, 32_768} in result
      assert {5432, 32_769} in result
    end

    test "deduplicates port tuples" do
      publishers = [
        %{
          "URL" => "0.0.0.0",
          "TargetPort" => 6379,
          "PublishedPort" => 32_768,
          "Protocol" => "tcp"
        },
        %{
          "URL" => "::",
          "TargetPort" => 6379,
          "PublishedPort" => 32_768,
          "Protocol" => "tcp"
        }
      ]

      assert Cli.parse_publishers(publishers) == [{6379, 32_768}]
    end

    test "handles nil publishers" do
      assert Cli.parse_publishers(nil) == []
    end

    test "handles empty publishers" do
      assert Cli.parse_publishers([]) == []
    end
  end
end
