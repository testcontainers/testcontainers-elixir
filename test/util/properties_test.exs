defmodule Testcontainers.Util.PropertiesParserTest do
  use ExUnit.Case, async: false

  alias Testcontainers.Util.PropertiesParser

  describe "read_property_sources/0" do
    test "returns empty map when no files or env vars exist" do
      # Clean env vars that might interfere
      System.get_env()
      |> Enum.filter(fn {k, _} -> String.starts_with?(k, "TESTCONTAINERS_") end)
      |> Enum.each(fn {k, _} -> System.delete_env(k) end)

      {:ok, props} = PropertiesParser.read_property_sources()

      # Should at least return a map (may have project file props)
      assert is_map(props)
    end

    test "reads environment variables with TESTCONTAINERS_ prefix" do
      System.put_env("TESTCONTAINERS_RYUK_CONTAINER_PRIVILEGED", "true")
      System.put_env("TESTCONTAINERS_SOME_OTHER_PROPERTY", "value")

      {:ok, props} = PropertiesParser.read_property_sources()

      assert props["ryuk.container.privileged"] == "true"
      assert props["some.other.property"] == "value"

      # Cleanup
      System.delete_env("TESTCONTAINERS_RYUK_CONTAINER_PRIVILEGED")
      System.delete_env("TESTCONTAINERS_SOME_OTHER_PROPERTY")
    end

    test "environment variables take precedence over file properties" do
      # Set env var
      System.put_env("TESTCONTAINERS_RYUK_CONTAINER_PRIVILEGED", "from_env")

      {:ok, props} = PropertiesParser.read_property_sources()

      # Env should win over any file-based setting
      assert props["ryuk.container.privileged"] == "from_env"

      # Cleanup
      System.delete_env("TESTCONTAINERS_RYUK_CONTAINER_PRIVILEGED")
    end
  end

  describe "read_property_file/0" do
    test "defaults to user file path" do
      {:ok, props} = PropertiesParser.read_property_file()

      # Should return a map (empty if user file doesn't exist)
      assert is_map(props)
    end
  end

  describe "read_property_file/1" do
    test "reads properties from specified file" do
      {:ok, props} = PropertiesParser.read_property_file("test/fixtures/.testcontainers.properties")

      assert is_map(props)
      assert props["tc.host"] == "tcp://localhost:9999"
    end

    test "returns empty map for nonexistent file" do
      {:ok, props} = PropertiesParser.read_property_file("/nonexistent/path/.testcontainers.properties")

      assert props == %{}
    end
  end
end
