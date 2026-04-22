defmodule Testcontainers.Connection.TlsTest do
  # async: false because we mutate DOCKER_CERT_PATH / DOCKER_TLS_VERIFY
  use ExUnit.Case, async: false

  alias Testcontainers.Connection

  @fixture_dir Path.expand("../fixtures/docker_certs", __DIR__)

  setup do
    original_cert_path = System.get_env("DOCKER_CERT_PATH")
    original_tls_verify = System.get_env("DOCKER_TLS_VERIFY")

    on_exit(fn ->
      restore_env("DOCKER_CERT_PATH", original_cert_path)
      restore_env("DOCKER_TLS_VERIFY", original_tls_verify)
    end)

    System.delete_env("DOCKER_CERT_PATH")
    System.delete_env("DOCKER_TLS_VERIFY")
    :ok
  end

  describe "build_ssl_options/0" do
    test "loads ca, cert and key files from DOCKER_CERT_PATH when they exist" do
      System.put_env("DOCKER_CERT_PATH", @fixture_dir)
      System.put_env("DOCKER_TLS_VERIFY", "1")

      opts = Connection.build_ssl_options()

      assert opts[:verify] == :verify_peer
      assert opts[:cacertfile] == Path.join(@fixture_dir, "ca.pem")
      assert opts[:certfile] == Path.join(@fixture_dir, "cert.pem")
      assert opts[:keyfile] == Path.join(@fixture_dir, "key.pem")
    end

    test "uses :verify_none when DOCKER_TLS_VERIFY is unset" do
      System.put_env("DOCKER_CERT_PATH", @fixture_dir)
      System.delete_env("DOCKER_TLS_VERIFY")

      opts = Connection.build_ssl_options()

      assert opts[:verify] == :verify_none
    end

    test "skips missing cert files without crashing" do
      empty_dir = Path.join(System.tmp_dir!(), "tc_empty_certs_#{:rand.uniform(1_000_000)}")
      File.mkdir_p!(empty_dir)
      System.put_env("DOCKER_CERT_PATH", empty_dir)
      System.put_env("DOCKER_TLS_VERIFY", "1")

      try do
        opts = Connection.build_ssl_options()

        assert opts[:verify] == :verify_peer
        refute Keyword.has_key?(opts, :cacertfile)
        refute Keyword.has_key?(opts, :certfile)
        refute Keyword.has_key?(opts, :keyfile)
      after
        File.rm_rf!(empty_dir)
      end
    end

    test "falls back to ~/.docker when DOCKER_CERT_PATH is unset" do
      System.delete_env("DOCKER_CERT_PATH")
      System.put_env("DOCKER_TLS_VERIFY", "1")

      # Simply verify it does not crash and still returns a keyword list with :verify.
      opts = Connection.build_ssl_options()
      assert opts[:verify] == :verify_peer
      assert is_list(opts)
    end
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
