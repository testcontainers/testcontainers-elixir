defmodule Testcontainers.Connection.DockerHostStrategy.DockerHostFromPropertiesTest do
  use ExUnit.Case, async: true

  alias Testcontainers.Connection.DockerHostStrategyEvaluator
  alias Testcontainers.Connection.DockerHostStrategy.DockerHostFromProperties

  describe "DockerHostFromProperties" do
    test "should return ok response if property file exist" do
      properties_path = "test/fixtures/.testcontainers.properties"

      strategy = %DockerHostFromProperties{
        key: "tc.host",
        filename: properties_path
      }

      {:ok, "tcp://somehost:9876"} = DockerHostStrategyEvaluator.run_strategies([strategy], [])
    end

    test "should return file not found if property file doesnt exist" do
      properties_path = "/some/nonexistent/place/.testcontainers.properties"

      strategy = %DockerHostFromProperties{
        key: "tc.host",
        filename: properties_path
      }

      {:error, testcontainer_host_from_properties: :file_does_not_exist} =
        DockerHostStrategyEvaluator.run_strategies([strategy], [])
    end

    test "should return property not found it property does not exist" do
      properties_path = "test/fixtures/.testcontainers.properties"

      strategy = %DockerHostFromProperties{
        key: "invalid.host",
        filename: properties_path
      }

      {:error, testcontainer_host_from_properties: :property_not_found} =
        DockerHostStrategyEvaluator.run_strategies([strategy], [])
    end
  end
end
