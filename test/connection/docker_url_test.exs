defmodule Testcontainers.DockerUrlTest do
  # async: false because we mutate DOCKER_TLS_VERIFY
  use ExUnit.Case, async: false

  alias Testcontainers.DockerUrl

  setup do
    original = System.get_env("DOCKER_TLS_VERIFY")

    on_exit(fn ->
      case original do
        nil -> System.delete_env("DOCKER_TLS_VERIFY")
        value -> System.put_env("DOCKER_TLS_VERIFY", value)
      end
    end)

    System.delete_env("DOCKER_TLS_VERIFY")
    :ok
  end

  describe "construct/1" do
    test "unix sockets are encoded as http+unix" do
      assert DockerUrl.construct("unix:///var/run/docker.sock") ==
               "http+unix://%2Fvar%2Frun%2Fdocker.sock"
    end

    test "tcp:// without DOCKER_TLS_VERIFY becomes http://" do
      assert DockerUrl.construct("tcp://127.0.0.1:2375") == "http://127.0.0.1:2375"
    end

    test "tcp:// with DOCKER_TLS_VERIFY=1 becomes https://" do
      System.put_env("DOCKER_TLS_VERIFY", "1")
      assert DockerUrl.construct("tcp://127.0.0.1:2376") == "https://127.0.0.1:2376"
    end

    test "tcp:// with DOCKER_TLS_VERIFY=true becomes https://" do
      System.put_env("DOCKER_TLS_VERIFY", "true")
      assert DockerUrl.construct("tcp://my.docker.host:2376") == "https://my.docker.host:2376"
    end

    test "tcp:// with DOCKER_TLS_VERIFY=0 remains http://" do
      System.put_env("DOCKER_TLS_VERIFY", "0")
      assert DockerUrl.construct("tcp://127.0.0.1:2375") == "http://127.0.0.1:2375"
    end

    test "https:// is passed through as string" do
      assert DockerUrl.construct("https://my.docker.host:2376") == "https://my.docker.host:2376"
    end

    test "http:// is passed through as string" do
      assert DockerUrl.construct("http://127.0.0.1:2375") == "http://127.0.0.1:2375"
    end
  end

  describe "tls_verify?/0" do
    test "returns true for \"1\"" do
      System.put_env("DOCKER_TLS_VERIFY", "1")
      assert DockerUrl.tls_verify?()
    end

    test "returns true for \"true\"" do
      System.put_env("DOCKER_TLS_VERIFY", "true")
      assert DockerUrl.tls_verify?()
    end

    test "returns false when unset" do
      System.delete_env("DOCKER_TLS_VERIFY")
      refute DockerUrl.tls_verify?()
    end

    test "returns false for \"0\"" do
      System.put_env("DOCKER_TLS_VERIFY", "0")
      refute DockerUrl.tls_verify?()
    end

    test "returns false for empty string" do
      System.put_env("DOCKER_TLS_VERIFY", "")
      refute DockerUrl.tls_verify?()
    end
  end

  describe "https?/1" do
    test "true for https URL" do
      assert DockerUrl.https?("https://host:2376")
    end

    test "false for http URL" do
      refute DockerUrl.https?("http://host:2375")
    end

    test "false for http+unix URL" do
      refute DockerUrl.https?("http+unix://%2Fvar%2Frun%2Fdocker.sock")
    end

    test "false for non-string input" do
      refute DockerUrl.https?(nil)
      refute DockerUrl.https?(:foo)
    end
  end
end
