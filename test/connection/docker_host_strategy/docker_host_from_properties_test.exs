defmodule Testcontainers.Connection.DockerHostStrategy.DockerHostFromPropertiesTest do
  use ExUnit.Case, async: true

  alias Testcontainers.DockerHostStrategyEvaluator
  alias Testcontainers.DockerHostFromPropertiesStrategy

  describe "DockerHostFromPropertiesStrategy" do
    test "should return :econnrefused response if property file exist but is not an open url" do
      properties_path = "test/fixtures/.testcontainers.properties"

      strategy = %DockerHostFromPropertiesStrategy{
        key: "tc.host",
        filename: properties_path
      }

      {:error,
       "Failed to find docker host: [testcontainer_host_from_properties: {:econnrefused, \"tc.host\"}]"} =
        DockerHostStrategyEvaluator.run_strategies([strategy], [])
    end

    test "should return property not found if property file doesn't exist" do
      properties_path = "/some/nonexistent/place/.testcontainers.properties"

      strategy = %DockerHostFromPropertiesStrategy{
        key: "tc.host",
        filename: properties_path
      }

      {:error,
       "Failed to find docker host: [testcontainer_host_from_properties: {:property_not_found, \"tc.host\"}]"} =
        DockerHostStrategyEvaluator.run_strategies([strategy], [])
    end

    test "should return property not found it property does not exist" do
      properties_path = "test/fixtures/.testcontainers.properties"

      strategy = %DockerHostFromPropertiesStrategy{
        key: "invalid.host",
        filename: properties_path
      }

      {:error,
       "Failed to find docker host: [testcontainer_host_from_properties: {:property_not_found, \"invalid.host\"}]"} =
        DockerHostStrategyEvaluator.run_strategies([strategy], [])
    end
  end
end
