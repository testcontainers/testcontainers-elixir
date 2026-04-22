defmodule Testcontainers.Docker.AuthTest do
  use ExUnit.Case, async: true

  alias Testcontainers.Docker.Auth

  @fixture Path.expand("../fixtures/docker_config.json", __DIR__)

  describe "registry_for_image/1" do
    test "unnamespaced images resolve to Docker Hub" do
      assert Auth.registry_for_image("redis") == "https://index.docker.io/v1/"
      assert Auth.registry_for_image("redis:7") == "https://index.docker.io/v1/"
    end

    test "library-style namespaced images resolve to Docker Hub" do
      assert Auth.registry_for_image("library/redis:7") == "https://index.docker.io/v1/"
      assert Auth.registry_for_image("myorg/myimage:tag") == "https://index.docker.io/v1/"
    end

    test "explicit docker.io / index.docker.io resolve to Docker Hub" do
      assert Auth.registry_for_image("docker.io/library/redis") == "https://index.docker.io/v1/"
      assert Auth.registry_for_image("index.docker.io/foo/bar") == "https://index.docker.io/v1/"
    end

    test "private registries return the registry host" do
      assert Auth.registry_for_image("myreg.example.com/foo/bar:tag") == "myreg.example.com"
      assert Auth.registry_for_image("registry.internal:5000/a/b") == "registry.internal:5000"
      assert Auth.registry_for_image("localhost/foo:tag") == "localhost"
    end
  end

  describe "resolve/2" do
    test "returns header for a Docker Hub image with canonical serveraddress" do
      header = Auth.resolve("library/redis:7", @fixture)

      assert is_binary(header)
      decoded = decode_header(header)

      assert decoded == %{
               "username" => "alice",
               "password" => "s3cret",
               "serveraddress" => "docker.io"
             }
    end

    test "serveraddress never contains a scheme or path" do
      # Regression: podman (and the Docker Engine API spec) reject a
      # serveraddress that is a full URL; it must be a bare host (optionally
      # with port).
      header = Auth.resolve("library/redis:7", @fixture)
      %{"serveraddress" => addr} = decode_header(header)

      refute String.contains?(addr, "://")
      refute String.contains?(addr, "/")
    end

    test "returns header for a private registry image" do
      header = Auth.resolve("myreg.example.com/foo/bar:tag", @fixture)

      assert is_binary(header)
      decoded = decode_header(header)

      assert decoded == %{
               "username" => "bob",
               "password" => "hunter2",
               "serveraddress" => "myreg.example.com"
             }
    end

    test "returns nil for an unknown registry" do
      assert Auth.resolve("unknown.example.org/foo/bar:tag", @fixture) == nil
    end

    test "returns nil when the config file is missing" do
      missing =
        Path.join(System.tmp_dir!(), "testcontainers-missing-#{System.unique_integer()}.json")

      refute File.exists?(missing)

      assert Auth.resolve("library/redis:7", missing) == nil
    end

    test "returns nil when the config file is invalid JSON" do
      path =
        Path.join(System.tmp_dir!(), "testcontainers-invalid-#{System.unique_integer()}.json")

      File.write!(path, "this is not json")

      try do
        assert Auth.resolve("library/redis:7", path) == nil
      after
        File.rm(path)
      end
    end

    test "header is URL-safe base64 without padding" do
      header = Auth.resolve("library/redis:7", @fixture)

      refute String.contains?(header, "=")
      refute String.contains?(header, "+")
      refute String.contains?(header, "/")
    end
  end

  describe "normalize_server_address/1" do
    test "strips scheme and path from full URLs" do
      assert Auth.normalize_server_address("https://index.docker.io/v1/") == "docker.io"
      assert Auth.normalize_server_address("http://myreg.example.com/") == "myreg.example.com"
    end

    test "passes through bare hosts" do
      assert Auth.normalize_server_address("myreg.example.com") == "myreg.example.com"
      assert Auth.normalize_server_address("registry.internal:5000") == "registry.internal:5000"
      assert Auth.normalize_server_address("localhost") == "localhost"
    end

    test "canonicalizes index.docker.io to docker.io" do
      assert Auth.normalize_server_address("index.docker.io") == "docker.io"
      assert Auth.normalize_server_address("https://index.docker.io/v1/") == "docker.io"
    end
  end

  defp decode_header(header) do
    header
    |> Base.url_decode64!(padding: false)
    |> Jason.decode!()
  end
end
