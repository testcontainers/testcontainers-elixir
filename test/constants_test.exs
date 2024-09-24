defmodule Testcontainers.ConstantsTest do
  use ExUnit.Case, async: true

  test "have correct values" do
    assert Testcontainers.Constants.container_label() == "org.testcontainers"
    assert Testcontainers.Constants.container_sessionId_label() == "org.testcontainers.session-id"
    assert Testcontainers.Constants.container_hash_label() == "org.testcontainers.reuse-hash"
    assert Testcontainers.Constants.container_version_label() == "org.testcontainers.version"
    assert is_binary(Testcontainers.Constants.library_version())
    assert is_atom(Testcontainers.Constants.library_name())
  end
end
